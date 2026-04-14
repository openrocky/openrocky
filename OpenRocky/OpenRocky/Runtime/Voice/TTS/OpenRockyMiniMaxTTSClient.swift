//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-04-14
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation

/// MiniMax TTS client using the /v1/t2a_v2 endpoint.
/// Returns MP3 audio data.
final class OpenRockyMiniMaxTTSClient: OpenRockyTTSClient, @unchecked Sendable {
    private let configuration: OpenRockyTTSProviderConfiguration

    let outputFormat: OpenRockyTTSAudioFormat = .mp3

    nonisolated init(configuration: OpenRockyTTSProviderConfiguration) {
        self.configuration = configuration.normalized()
    }

    func synthesize(text: String) async throws -> Data {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw OpenRockyTTSClientError.emptyText
        }
        guard let credential = configuration.credential, !credential.isEmpty else {
            throw OpenRockyTTSClientError.notConfigured
        }

        let baseURL = configuration.customHost ?? configuration.provider.defaultBaseURL
        let url = URL(string: "\(baseURL)/api/v1/t2a_v2")!

        let body: [String: Any] = [
            "model": configuration.modelID,
            "text": trimmed,
            "voice_setting": [
                "voice_id": configuration.resolvedVoice,
            ] as [String: Any],
            "audio_setting": [
                "format": "mp3",
                "sample_rate": 24000,
            ] as [String: Any],
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(credential)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

        guard (200...299).contains(statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            rlog.error("MiniMax TTS failed: HTTP \(statusCode) \(errorBody.prefix(300))", category: "TTS")
            throw OpenRockyTTSClientError.synthesisFailed("HTTP \(statusCode): \(errorBody.prefix(200))")
        }

        // MiniMax returns JSON with base64-encoded audio in "data.audio"
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any],
              let audioBase64 = dataObj["audio"] as? String,
              let audioData = Data(base64Encoded: audioBase64) else {
            // Try treating response as direct audio data (some endpoints return raw audio)
            if data.count > 100 {
                rlog.info("MiniMax TTS: treating response as raw audio (\(data.count) bytes)", category: "TTS")
                return data
            }
            let raw = String(data: data, encoding: .utf8) ?? ""
            rlog.error("MiniMax TTS parse error: \(raw.prefix(200))", category: "TTS")
            throw OpenRockyTTSClientError.synthesisFailed("Invalid response format")
        }

        rlog.info("MiniMax TTS synthesized: \(audioData.count) bytes for \(trimmed.count) chars", category: "TTS")
        return audioData
    }
}
