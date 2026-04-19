//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-04-19
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation

/// Zhipu GLM-TTS client using the OpenAI-shaped /api/paas/v4/audio/speech endpoint.
/// Returns raw audio bytes (WAV/MP3 depending on response_format).
final class OpenRockyZhipuGLMTTSClient: OpenRockyTTSClient, @unchecked Sendable {
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
        guard let url = URL(string: "\(baseURL)/api/paas/v4/audio/speech") else {
            throw OpenRockyTTSClientError.synthesisFailed("Invalid Zhipu GLM TTS endpoint URL")
        }

        let body: [String: Any] = [
            "model": configuration.modelID,
            "input": trimmed,
            "voice": configuration.resolvedVoice,
            "response_format": "mp3",
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
            rlog.error("Zhipu GLM TTS failed: HTTP \(statusCode) \(errorBody.prefix(300))", category: "TTS")
            throw OpenRockyTTSClientError.synthesisFailed("HTTP \(statusCode): \(errorBody.prefix(200))")
        }

        guard !data.isEmpty else { throw OpenRockyTTSClientError.synthesisFailed("Empty audio response") }
        rlog.info("Zhipu GLM TTS synthesized: \(data.count) bytes", category: "TTS")
        return data
    }
}
