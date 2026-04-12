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

/// Plays a short TTS preview for an OpenAI voice using the Realtime WebSocket API.
@MainActor
final class OpenRockyOpenAIVoicePreview: ObservableObject {
    @Published var playingVoice: String?
    @Published var isLoading = false
    @Published var error: String?

    private var socket: URLSessionWebSocketTask?
    private var audioPlayer: AVAudioPlayer?
    private var audioData = Data()
    private var receiveTask: Task<Void, Never>?

    func play(voice: String, credential: String, customHost: String? = nil) {
        stop()
        guard !credential.isEmpty else {
            error = "Please fill in the API Key first."
            return
        }

        playingVoice = voice
        isLoading = true
        error = nil
        audioData = Data()

        Task {
            do {
                try await connectAndSpeak(voice: voice, credential: credential, customHost: customHost)
            } catch {
                self.error = error.localizedDescription
                self.isLoading = false
                self.playingVoice = nil
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
        isLoading = false
        playingVoice = nil
    }

    // MARK: - Protocol

    private func connectAndSpeak(voice: String, credential: String, customHost: String?) async throws {
        let host = customHost ?? "wss://api.openai.com"
        let model = "gpt-realtime-mini"
        guard let url = URL(string: "\(host)/v1/realtime?model=\(model)") else {
            throw PreviewError.failed("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(credential)", forHTTPHeaderField: "Authorization")
        request.setValue("realtime=v1", forHTTPHeaderField: "openai-beta")

        let socket = URLSession.shared.webSocketTask(with: request)
        self.socket = socket
        socket.resume()

        // Wait for session.created
        let created = try await receiveJSON()
        guard created["type"] as? String == "session.created" else {
            throw PreviewError.failed("Unexpected response: \(created["type"] ?? "unknown")")
        }

        // Send session.update with voice and minimal config
        let sessionUpdate: [String: Any] = [
            "type": "session.update",
            "session": [
                "voice": voice,
                "modalities": ["audio", "text"],
                "instructions": "You are a helpful voice assistant. Say a brief greeting.",
                "input_audio_format": "pcm16",
                "output_audio_format": "pcm16",
                "turn_detection": NSNull()
            ] as [String: Any]
        ]
        try await sendJSON(sessionUpdate)

        // Wait for session.updated
        let updated = try await receiveJSON()
        guard updated["type"] as? String == "session.updated" else {
            if updated["type"] as? String == "error" {
                let msg = (updated["error"] as? [String: Any])?["message"] as? String ?? "Session update failed"
                throw PreviewError.failed(msg)
            }
            throw PreviewError.failed("Unexpected response: \(updated["type"] ?? "unknown")")
        }

        // Send a text message for TTS
        let itemCreate: [String: Any] = [
            "type": "conversation.item.create",
            "item": [
                "type": "message",
                "role": "user",
                "content": [
                    ["type": "input_text", "text": "Say hello in one short sentence."]
                ]
            ] as [String: Any]
        ]
        try await sendJSON(itemCreate)

        // Trigger response
        let responseCreate: [String: Any] = [
            "type": "response.create",
            "response": [
                "modalities": ["audio", "text"],
                "max_output_tokens": 150
            ] as [String: Any]
        ]
        try await sendJSON(responseCreate)

        // Collect audio deltas
        receiveTask = Task { [weak self] in
            guard let self, let socket = self.socket else { return }
            do {
                while !Task.isCancelled {
                    let msg = try await socket.receive()
                    guard case .string(let text) = msg,
                          let data = text.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let type = json["type"] as? String else { continue }

                    if type == "response.audio.delta" {
                        if let delta = json["delta"] as? String,
                           let audioChunk = Data(base64Encoded: delta) {
                            self.audioData.append(audioChunk)
                        }
                    } else if type == "response.done" {
                        break
                    } else if type == "error" {
                        let msg = (json["error"] as? [String: Any])?["message"] as? String ?? "Unknown error"
                        self.error = msg
                        self.playingVoice = nil
                        break
                    }
                }
            } catch {
                if !Task.isCancelled {
                    self.error = error.localizedDescription
                }
            }

            self.playCollectedAudio()

            self.socket?.cancel(with: .goingAway, reason: nil)
            self.socket = nil
        }
    }

    private func playCollectedAudio() {
        isLoading = false
        guard !audioData.isEmpty else {
            playingVoice = nil
            return
        }

        let wav = buildWAV(pcm16: audioData, sampleRate: 24000, channels: 1)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            audioPlayer = try AVAudioPlayer(data: wav)
            audioPlayer?.play()
            let duration = audioPlayer?.duration ?? 2.0
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(duration + 0.3))
                self?.playingVoice = nil
            }
        } catch {
            self.error = "Playback failed: \(error.localizedDescription)"
            playingVoice = nil
        }
    }

    // MARK: - WebSocket Helpers

    private func sendJSON(_ json: [String: Any]) async throws {
        guard let socket else { return }
        let data = try JSONSerialization.data(withJSONObject: json)
        let text = String(data: data, encoding: .utf8)!
        try await socket.send(.string(text))
    }

    private func receiveJSON() async throws -> [String: Any] {
        guard let socket else { throw PreviewError.failed("Not connected") }
        let msg = try await socket.receive()
        guard case .string(let text) = msg,
              let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return json
    }

    // MARK: - WAV Builder

    private func buildWAV(pcm16: Data, sampleRate: Int, channels: Int) -> Data {
        var wav = Data()
        let dataSize = UInt32(pcm16.count)
        let fileSize = dataSize + 36

        wav.append(contentsOf: "RIFF".utf8)
        wav.append(contentsOf: withUnsafeBytes(of: fileSize.littleEndian) { Array($0) })
        wav.append(contentsOf: "WAVE".utf8)

        wav.append(contentsOf: "fmt ".utf8)
        wav.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) })
        wav.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })
        wav.append(contentsOf: withUnsafeBytes(of: UInt16(channels).littleEndian) { Array($0) })
        wav.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Array($0) })
        let byteRate = UInt32(sampleRate * channels * 2)
        wav.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Array($0) })
        wav.append(contentsOf: withUnsafeBytes(of: UInt16(channels * 2).littleEndian) { Array($0) })
        wav.append(contentsOf: withUnsafeBytes(of: UInt16(16).littleEndian) { Array($0) })

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
