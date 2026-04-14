//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-04-14
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation

/// Google Cloud Text-to-Speech client using /v1/text:synthesize endpoint.
/// Returns MP3 audio data.
final class OpenRockyGoogleTTSClient: OpenRockyTTSClient, @unchecked Sendable {
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
        let url = URL(string: "\(baseURL)/v1/text:synthesize?key=\(credential)")!

        let voiceName = configuration.resolvedVoice
        // Derive language from voice name (e.g. "en-US-Neural2-C" → "en-US")
        let lang = String(voiceName.prefix(5))

        let body: [String: Any] = [
            "input": ["text": trimmed] as [String: Any],
            "voice": [
                "languageCode": lang,
                "name": voiceName,
            ] as [String: Any],
            "audioConfig": [
                "audioEncoding": "MP3",
                "speakingRate": 1.0,
            ] as [String: Any],
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

        guard (200...299).contains(statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            rlog.error("Google TTS failed: HTTP \(statusCode) \(errorBody.prefix(300))", category: "TTS")
            throw OpenRockyTTSClientError.synthesisFailed("HTTP \(statusCode): \(errorBody.prefix(200))")
        }

        // Parse: { "audioContent": "base64..." }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let audioBase64 = json["audioContent"] as? String,
              let audioData = Data(base64Encoded: audioBase64) else {
            let raw = String(data: data, encoding: .utf8) ?? ""
            rlog.error("Google TTS parse error: \(raw.prefix(200))", category: "TTS")
            throw OpenRockyTTSClientError.synthesisFailed("Invalid response format")
        }

        rlog.info("Google TTS synthesized: \(audioData.count) bytes", category: "TTS")
        return audioData
    }
}
