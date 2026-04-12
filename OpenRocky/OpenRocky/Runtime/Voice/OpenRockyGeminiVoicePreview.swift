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

/// Plays a short TTS preview for a Gemini voice using the Live WebSocket API.
@MainActor
final class OpenRockyGeminiVoicePreview: ObservableObject {
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
        let host = customHost ?? "wss://generativelanguage.googleapis.com"
        let model = "gemini-2.5-flash-native-audio-latest"
        let urlString = "\(host)/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?key=\(credential)"
        guard let url = URL(string: urlString) else {
            throw PreviewError.failed("Invalid URL")
        }

        let socket = URLSession.shared.webSocketTask(with: url)
        self.socket = socket
        socket.resume()

        // Send setup with voice config
        let setup: [String: Any] = [
            "setup": [
                "model": "models/\(model)",
                "generationConfig": [
                    "responseModalities": ["AUDIO"],
                    "speechConfig": [
                        "voiceConfig": [
                            "prebuiltVoiceConfig": [
                                "voiceName": voice
                            ]
                        ]
                    ]
                ] as [String: Any],
                "systemInstruction": [
                    "parts": [["text": "You are a helpful voice assistant. Say a brief greeting."]]
                ]
            ] as [String: Any]
        ]
        try await sendJSON(setup)

        // Wait for setupComplete
        let firstResponse = try await receiveJSON()
        guard firstResponse["setupComplete"] != nil else {
            if let error = firstResponse["error"] as? [String: Any],
               let msg = error["message"] as? String {
                throw PreviewError.failed(msg)
            }
            throw PreviewError.failed("Setup failed")
        }

        // Send text to generate speech
        let clientContent: [String: Any] = [
            "clientContent": [
                "turns": [
                    [
                        "role": "user",
                        "parts": [["text": "Say hello in one short sentence."]]
                    ]
                ],
                "turnComplete": true
            ] as [String: Any]
        ]
        try await sendJSON(clientContent)

        // Collect audio from serverContent
        receiveTask = Task { [weak self] in
            guard let self, let socket = self.socket else { return }
            do {
                while !Task.isCancelled {
                    let msg = try await socket.receive()
                    let json: [String: Any]
                    switch msg {
                    case .string(let text):
                        guard let data = text.data(using: .utf8),
                              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
                        json = parsed
                    case .data(let data):
                        guard let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
                        json = parsed
                    @unknown default:
                        continue
                    }

                    if let serverContent = json["serverContent"] as? [String: Any] {
                        // Extract audio from modelTurn parts
                        if let modelTurn = serverContent["modelTurn"] as? [String: Any],
                           let parts = modelTurn["parts"] as? [[String: Any]] {
                            for part in parts {
                                if let inlineData = part["inlineData"] as? [String: Any],
                                   let audioB64 = inlineData["data"] as? String,
                                   let audioChunk = Data(base64Encoded: audioB64) {
                                    self.audioData.append(audioChunk)
                                }
                            }
                        }

                        // Turn complete
                        if serverContent["turnComplete"] as? Bool == true {
                            break
                        }
                    } else if json["error"] != nil {
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
        switch msg {
        case .string(let text):
            guard let data = text.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
            return json
        case .data(let data):
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
            return json
        @unknown default:
            return [:]
        }
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
