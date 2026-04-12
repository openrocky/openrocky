//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-04-11
// Copyright (c) 2026 everettjf. All rights reserved.
//

import AVFoundation
import Combine
import Foundation

@MainActor
final class OpenRockyGLMVoicePreview: ObservableObject {
    @Published var playingVoice: String?
    @Published var isLoading = false
    @Published var error: String?

    private var socket: URLSessionWebSocketTask?
    private var player: AVAudioPlayer?
    private var audioChunks: [Data] = []
    private var task: Task<Void, Never>?

    func play(voice: String, credential: String, customHost: String? = nil) {
        stop()
        playingVoice = voice
        isLoading = true
        error = nil

        task = Task { [weak self] in
            await self?.runPreview(voice: voice, credential: credential, customHost: customHost)
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        player?.stop()
        player = nil
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        isLoading = false
        playingVoice = nil
        audioChunks = []
    }

    private func runPreview(voice: String, credential: String, customHost: String?) async {
        let baseHost = customHost ?? "wss://open.bigmodel.cn"
        guard let url = URL(string: "\(baseHost)/api/paas/v4/realtime") else {
            error = "Invalid URL"
            playingVoice = nil
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(credential)", forHTTPHeaderField: "Authorization")
        let ws = URLSession.shared.webSocketTask(with: request)
        self.socket = ws
        ws.resume()

        do {
            // Send session.update
            let sessionUpdate: [String: Any] = [
                "type": "session.update",
                "session": [
                    "model": "glm-realtime",
                    "voice": voice,
                    "modalities": ["audio", "text"],
                    "output_audio_format": "pcm",
                    "turn_detection": ["type": "server_vad"] as [String: Any]
                ] as [String: Any]
            ]
            try await sendJSON(ws, sessionUpdate)

            // Wait for session.created or session.updated
            _ = try await ws.receive()

            // Create conversation item with a hello prompt
            let createItem: [String: Any] = [
                "type": "conversation.item.create",
                "item": [
                    "type": "message",
                    "role": "user",
                    "content": [
                        ["type": "input_text", "text": "Say hello in one short sentence, in Chinese."]
                    ]
                ] as [String: Any]
            ]
            try await sendJSON(ws, createItem)

            // Trigger response
            let createResponse: [String: Any] = [
                "type": "response.create"
            ]
            try await sendJSON(ws, createResponse)

            // Collect audio chunks until response.done
            audioChunks = []
            while !Task.isCancelled {
                let msg = try await ws.receive()
                guard case .string(let text) = msg,
                      let data = text.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let type = json["type"] as? String else { continue }

                if type == "response.audio.delta", let delta = json["delta"] as? String,
                   let audioData = Data(base64Encoded: delta) {
                    audioChunks.append(audioData)
                } else if type == "response.done" {
                    break
                } else if type == "error" {
                    let errMsg = (json["error"] as? [String: Any])?["message"] as? String ?? "Unknown error"
                    throw GLMProtocolError.setupFailed(errMsg)
                }
            }

            ws.cancel(with: .goingAway, reason: nil)
            self.socket = nil

            isLoading = false
            guard !audioChunks.isEmpty, !Task.isCancelled else {
                playingVoice = nil
                return
            }

            // Combine chunks and wrap as WAV (PCM16 24kHz mono)
            let combined = audioChunks.reduce(Data()) { $0 + $1 }
            let wav = wrapPCM16AsWAV(combined, sampleRate: 24000)

            player = try AVAudioPlayer(data: wav)
            player?.play()

            // Wait for playback to finish
            while player?.isPlaying == true, !Task.isCancelled {
                try await Task.sleep(nanoseconds: 100_000_000)
            }
            playingVoice = nil
        } catch {
            if !Task.isCancelled {
                self.error = error.localizedDescription
            }
            isLoading = false
            playingVoice = nil
            ws.cancel(with: .goingAway, reason: nil)
            self.socket = nil
        }
    }

    private func sendJSON(_ ws: URLSessionWebSocketTask, _ object: [String: Any]) async throws {
        let data = try JSONSerialization.data(withJSONObject: object)
        guard let text = String(data: data, encoding: .utf8) else { return }
        try await ws.send(.string(text))
    }

    private func wrapPCM16AsWAV(_ pcmData: Data, sampleRate: Int32) -> Data {
        let channels: Int16 = 1
        let bitsPerSample: Int16 = 16
        let byteRate = sampleRate * Int32(channels) * Int32(bitsPerSample / 8)
        let blockAlign = channels * (bitsPerSample / 8)
        let dataSize = Int32(pcmData.count)
        let chunkSize = 36 + dataSize

        var header = Data()
        header.append(contentsOf: "RIFF".utf8)
        header.append(contentsOf: withUnsafeBytes(of: chunkSize.littleEndian) { Array($0) })
        header.append(contentsOf: "WAVE".utf8)
        header.append(contentsOf: "fmt ".utf8)
        header.append(contentsOf: withUnsafeBytes(of: Int32(16).littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: Int16(1).littleEndian) { Array($0) }) // PCM
        header.append(contentsOf: withUnsafeBytes(of: channels.littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: sampleRate.littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: bitsPerSample.littleEndian) { Array($0) })
        header.append(contentsOf: "data".utf8)
        header.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian) { Array($0) })
        header.append(pcmData)
        return header
    }
}
