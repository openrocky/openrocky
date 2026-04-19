//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-04-14
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation

/// ElevenLabs TTS client using /v1/text-to-speech/{voice_id} endpoint.
/// Returns MP3 audio data directly.
final class OpenRockyElevenLabsTTSClient: OpenRockyTTSClient, @unchecked Sendable {
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
        let voiceID = configuration.resolvedVoice
        let encodedVoiceID = voiceID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? voiceID
        guard let url = URL(string: "\(baseURL)/v1/text-to-speech/\(encodedVoiceID)") else {
            throw OpenRockyTTSClientError.synthesisFailed("Invalid ElevenLabs TTS endpoint URL")
        }

        let body: [String: Any] = [
            "text": trimmed,
            "model_id": configuration.modelID,
            "voice_settings": [
                "stability": 0.5,
                "similarity_boost": 0.75,
            ] as [String: Any],
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(credential, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

        guard (200...299).contains(statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            rlog.error("ElevenLabs TTS failed: HTTP \(statusCode) \(errorBody.prefix(300))", category: "TTS")
            throw OpenRockyTTSClientError.synthesisFailed("HTTP \(statusCode): \(errorBody.prefix(200))")
        }

        guard !data.isEmpty else { throw OpenRockyTTSClientError.synthesisFailed("Empty audio response") }
        rlog.info("ElevenLabs TTS synthesized: \(data.count) bytes", category: "TTS")
        return data
    }
}
