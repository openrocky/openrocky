//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-04-14
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation

/// Google Cloud Speech-to-Text client using the REST API.
/// Endpoint: /v1/speech:recognize
final class OpenRockyGoogleSTTClient: OpenRockySTTClient, @unchecked Sendable {
    private let configuration: OpenRockySTTProviderConfiguration

    nonisolated init(configuration: OpenRockySTTProviderConfiguration) {
        self.configuration = configuration.normalized()
    }

    func transcribe(audioData: Data) async throws -> String {
        guard !audioData.isEmpty else {
            throw OpenRockySTTClientError.emptyAudio
        }
        guard let credential = configuration.credential, !credential.isEmpty else {
            throw OpenRockySTTClientError.notConfigured
        }

        let baseURL = configuration.customHost ?? configuration.provider.defaultBaseURL
        let encodedKey = credential.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? credential
        guard let url = URL(string: "\(baseURL)/v1/speech:recognize?key=\(encodedKey)") else {
            throw OpenRockySTTClientError.transcriptionFailed("Invalid Google STT endpoint URL")
        }

        let language = configuration.language ?? "en-US"
        let body: [String: Any] = [
            "config": [
                "encoding": "LINEAR16",
                "sampleRateHertz": 24000,
                "languageCode": language,
                "enableAutomaticPunctuation": true,
                "model": "latest_long",
            ] as [String: Any],
            "audio": [
                "content": audioData.base64EncodedString(),
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
            rlog.error("Google STT failed: HTTP \(statusCode) \(errorBody.prefix(300))", category: "STT")
            throw OpenRockySTTClientError.transcriptionFailed("HTTP \(statusCode): \(errorBody.prefix(200))")
        }

        // Parse: { "results": [{ "alternatives": [{ "transcript": "..." }] }] }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]] else {
            let raw = String(data: data, encoding: .utf8) ?? ""
            rlog.error("Google STT parse error: \(raw.prefix(200))", category: "STT")
            throw OpenRockySTTClientError.transcriptionFailed("Invalid response format")
        }

        let transcript = results.compactMap { result -> String? in
            guard let alternatives = result["alternatives"] as? [[String: Any]],
                  let first = alternatives.first,
                  let text = first["transcript"] as? String else { return nil }
            return text
        }.joined()

        guard !transcript.isEmpty else {
            throw OpenRockySTTClientError.transcriptionFailed("No transcript in response")
        }

        rlog.info("Google STT transcribed: \(transcript.prefix(100))", category: "STT")
        return transcript
    }
}
