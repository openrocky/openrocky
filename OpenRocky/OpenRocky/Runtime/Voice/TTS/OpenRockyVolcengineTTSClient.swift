//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-04-14
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation

/// Volcengine (ByteDance/Doubao) TTS client using the /api/v1/tts endpoint.
/// Returns MP3 audio data.
final class OpenRockyVolcengineTTSClient: OpenRockyTTSClient, @unchecked Sendable {
    private let configuration: OpenRockyTTSProviderConfiguration

    let outputFormat: OpenRockyTTSAudioFormat = .mp3

    nonisolated init(configuration: OpenRockyTTSProviderConfiguration) {
        self.configuration = configuration.normalized()
    }

    func synthesize(text: String) async throws -> Data {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw OpenRockyTTSClientError.emptyText }
        guard let credential = configuration.credential, !credential.isEmpty else {
            throw OpenRockyTTSClientError.notConfigured
        }

        let baseURL = configuration.customHost ?? configuration.provider.defaultBaseURL
        guard let url = URL(string: "\(baseURL)/api/v1/tts") else {
            throw OpenRockyTTSClientError.synthesisFailed("Invalid Volcengine TTS endpoint URL")
        }

        let body: [String: Any] = [
            "app": ["appid": "default", "cluster": "volcano_tts"] as [String: Any],
            "user": ["uid": "openrocky"] as [String: Any],
            "audio": [
                "voice_type": configuration.resolvedVoice,
                "encoding": "mp3",
                "speed_ratio": 1.0,
            ] as [String: Any],
            "request": [
                "reqid": UUID().uuidString,
                "text": trimmed,
                "operation": "query",
            ] as [String: Any],
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer; \(credential)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

        guard (200...299).contains(statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            rlog.error("Volcengine TTS failed: HTTP \(statusCode) \(errorBody.prefix(300))", category: "TTS")
            throw OpenRockyTTSClientError.synthesisFailed("HTTP \(statusCode): \(errorBody.prefix(200))")
        }

        // Parse: { "data": "base64_audio_data" } or direct audio
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let audioBase64 = json["data"] as? String,
           let audioData = Data(base64Encoded: audioBase64) {
            rlog.info("Volcengine TTS synthesized: \(audioData.count) bytes", category: "TTS")
            return audioData
        }

        // Try as direct audio response
        if data.count > 100 {
            rlog.info("Volcengine TTS: raw audio (\(data.count) bytes)", category: "TTS")
            return data
        }

        let raw = String(data: data, encoding: .utf8) ?? ""
        rlog.error("Volcengine TTS parse error: \(raw.prefix(200))", category: "TTS")
        throw OpenRockyTTSClientError.synthesisFailed("Invalid response format")
    }
}
