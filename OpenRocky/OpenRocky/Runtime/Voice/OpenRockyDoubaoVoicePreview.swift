//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import AVFoundation
import Combine
import Foundation

/// Plays a short TTS preview for a Doubao speaker using the binary WebSocket protocol.
@MainActor
final class OpenRockyDoubaoVoicePreview: ObservableObject {
    @Published var playingSpeaker: String?
    @Published var error: String?

    private var socket: URLSessionWebSocketTask?
    private var sessionID = UUID().uuidString
    private var audioPlayer: AVAudioPlayer?
    private var audioData = Data()
    private var receiveTask: Task<Void, Never>?

    func play(speaker: String, appId: String, credential: String) {
        stop()
        guard !appId.isEmpty, !credential.isEmpty else {
            error = "Please fill in APP ID and Access Token first."
            return
        }

        playingSpeaker = speaker
        error = nil
        audioData = Data()
        sessionID = UUID().uuidString

        Task {
            do {
                try await connectAndSpeak(speaker: speaker, appId: appId, credential: credential)
            } catch {
                self.error = error.localizedDescription
                self.playingSpeaker = nil
            }
        }
    }

    func stop() {
        receiveTask?.cancel()
        receiveTask = nil
        audioPlayer?.stop()
        audioPlayer = nil
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        playingSpeaker = nil
    }

    // MARK: - Protocol

    private func connectAndSpeak(speaker: String, appId: String, credential: String) async throws {
        let url = URL(string: "wss://openspeech.bytedance.com/api/v3/realtime/dialogue")!
        var request = URLRequest(url: url)
        request.setValue(appId, forHTTPHeaderField: "X-Api-App-ID")
        request.setValue(credential, forHTTPHeaderField: "X-Api-Access-Key")
        request.setValue("volc.speech.dialog", forHTTPHeaderField: "X-Api-Resource-Id")
        request.setValue("PlgvMymc7f3tQnJ6", forHTTPHeaderField: "X-Api-App-Key")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Api-Connect-Id")

        let socket = URLSession.shared.webSocketTask(with: request)
        self.socket = socket
        socket.resume()

        // StartConnection
        try await send(event: 1, payload: "{}".data(using: .utf8)!, includeSession: false)
        let startResp = try await receive()
        guard !startResp.isError else { throw PreviewError.failed(startResp.errorText) }

        // StartSession
        let config: [String: Any] = [
            "tts": [
                "speaker": speaker,
                "audio_config": ["channel": 1, "format": "pcm", "sample_rate": 24000]
            ],
            "dialog": [
                "bot_name": "OpenRocky",
                "system_role": "You are a helpful assistant.",
                "extra": ["strict_audit": false, "input_mod": "audio", "model": "1.2.1.1"] as [String: Any]
            ] as [String: Any]
        ]
        let configData = try JSONSerialization.data(withJSONObject: config)
        try await send(event: 100, payload: configData, includeSession: true)
        let sessionResp = try await receive()
        guard !sessionResp.isError else { throw PreviewError.failed(sessionResp.errorText) }

        // SayHello
        let hello: [String: Any] = ["content": "你好，我是你的语音助手。"]
        let helloData = try JSONSerialization.data(withJSONObject: hello)
        try await send(event: 300, payload: helloData, includeSession: true)

        // Collect audio
        receiveTask = Task { [weak self] in
            guard let self, let socket = self.socket else { return }
            do {
                while !Task.isCancelled {
                    let msg = try await socket.receive()
                    guard case .data(let data) = msg, data.count >= 4 else { continue }
                    let parsed = self.parse(data)
                    if parsed.isAudio {
                        let pcm16 = self.convertFloat32ToPCM16(parsed.payload)
                        self.audioData.append(pcm16)
                    } else if parsed.event == 351 || parsed.event == 359 || parsed.event == 154 {
                        // TTS done
                        break
                    }
                }
            } catch {
                if !Task.isCancelled {
                    self.error = error.localizedDescription
                }
            }

            // Play collected audio
            self.playCollectedAudio()

            // Cleanup
            try? await self.send(event: 102, payload: "{}".data(using: .utf8)!, includeSession: true)
            try? await self.send(event: 2, payload: "{}".data(using: .utf8)!, includeSession: false)
            self.socket?.cancel(with: .goingAway, reason: nil)
            self.socket = nil
        }
    }

    private func playCollectedAudio() {
        guard !audioData.isEmpty else {
            playingSpeaker = nil
            return
        }

        // Build WAV from PCM16 data
        let wav = buildWAV(pcm16: audioData, sampleRate: 24000, channels: 1)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            audioPlayer = try AVAudioPlayer(data: wav)
            audioPlayer?.delegate = nil
            audioPlayer?.play()
            // Auto-reset after playback duration
            let duration = audioPlayer?.duration ?? 2.0
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(duration + 0.3))
                self?.playingSpeaker = nil
            }
        } catch {
            self.error = "Playback failed: \(error.localizedDescription)"
            playingSpeaker = nil
        }
    }

    // MARK: - Binary Protocol Helpers

    private func send(event: UInt32, payload: Data, includeSession: Bool) async throws {
        guard let socket else { return }
        var msg = Data([0x11, 0x14, 0x10, 0x00]) // version=1, headerSize=1, fullRequest, event, json, noCompression
        msg.append(contentsOf: withUnsafeBytes(of: event.bigEndian) { Array($0) })
        if includeSession {
            let sid = sessionID.data(using: .utf8)!
            msg.append(contentsOf: withUnsafeBytes(of: UInt32(sid.count).bigEndian) { Array($0) })
            msg.append(sid)
        }
        msg.append(contentsOf: withUnsafeBytes(of: UInt32(payload.count).bigEndian) { Array($0) })
        msg.append(payload)
        try await socket.send(.data(msg))
    }

    private struct ParsedMsg {
        var event: UInt32 = 0
        var isAudio = false
        var isError = false
        var errorText = ""
        var payload = Data()
    }

    private func receive() async throws -> ParsedMsg {
        guard let socket else { throw PreviewError.failed("Not connected") }
        let msg = try await socket.receive()
        guard case .data(let data) = msg else { return ParsedMsg() }
        return parse(data)
    }

    private func parse(_ data: Data) -> ParsedMsg {
        guard data.count >= 4 else { return ParsedMsg() }
        var r = ParsedMsg()
        let hs = Int(data[0] & 0x0F) * 4
        let msgType = data[1] >> 4
        let flags = data[1] & 0x0F
        guard data.count > hs else { return r }
        let pa = data.subdata(in: hs..<data.count)
        var o = 0

        if msgType == 0x0F { // error
            r.isError = true
            if pa.count >= 8 {
                let pLen = Int(readU32(pa, o: 4))
                if pa.count >= 8 + pLen {
                    r.errorText = String(data: pa.subdata(in: 8..<8+pLen), encoding: .utf8) ?? "unknown"
                }
            }
            return r
        }

        r.isAudio = msgType == 0x0B

        if flags & 0x04 > 0, pa.count >= o + 4 {
            r.event = readU32(pa, o: o); o += 4
        }
        // Skip session ID
        if pa.count >= o + 4 {
            let sLen = Int(readU32(pa, o: o)); o += 4 + sLen
        }
        // Payload
        if pa.count >= o + 4 {
            let pLen = Int(readU32(pa, o: o)); o += 4
            if pa.count >= o + pLen {
                r.payload = pa.subdata(in: o..<o+pLen)
            }
        }
        return r
    }

    private func readU32(_ d: Data, o: Int) -> UInt32 {
        guard d.count >= o + 4 else { return 0 }
        return UInt32(d[o])<<24 | UInt32(d[o+1])<<16 | UInt32(d[o+2])<<8 | UInt32(d[o+3])
    }

    // MARK: - Audio

    private func convertFloat32ToPCM16(_ data: Data) -> Data {
        let count = data.count / 4
        var out = Data(count: count * 2)
        data.withUnsafeBytes { src in
            out.withUnsafeMutableBytes { dst in
                let f = src.bindMemory(to: Float32.self)
                let i = dst.bindMemory(to: Int16.self)
                for n in 0..<count {
                    i[n] = Int16(min(max(f[n], -1.0), 1.0) * 32767)
                }
            }
        }
        return out
    }

    private func buildWAV(pcm16: Data, sampleRate: Int, channels: Int) -> Data {
        var wav = Data()
        let dataSize = UInt32(pcm16.count)
        let fileSize = dataSize + 36

        // RIFF header
        wav.append(contentsOf: "RIFF".utf8)
        wav.append(contentsOf: withUnsafeBytes(of: fileSize.littleEndian) { Array($0) })
        wav.append(contentsOf: "WAVE".utf8)

        // fmt chunk
        wav.append(contentsOf: "fmt ".utf8)
        wav.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) }) // chunk size
        wav.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })  // PCM
        wav.append(contentsOf: withUnsafeBytes(of: UInt16(channels).littleEndian) { Array($0) })
        wav.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Array($0) })
        let byteRate = UInt32(sampleRate * channels * 2)
        wav.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Array($0) })
        wav.append(contentsOf: withUnsafeBytes(of: UInt16(channels * 2).littleEndian) { Array($0) }) // block align
        wav.append(contentsOf: withUnsafeBytes(of: UInt16(16).littleEndian) { Array($0) }) // bits per sample

        // data chunk
        wav.append(contentsOf: "data".utf8)
        wav.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian) { Array($0) })
        wav.append(pcm16)

        return wav
    }

    enum PreviewError: LocalizedError {
        case failed(String)
        var errorDescription: String? {
            switch self { case .failed(let msg): return msg }
        }
    }
}
