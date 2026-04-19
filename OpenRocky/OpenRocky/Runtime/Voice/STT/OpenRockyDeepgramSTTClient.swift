//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-04-14
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation

/// Deepgram Nova STT client using the /v1/listen endpoint.
final class OpenRockyDeepgramSTTClient: OpenRockySTTClient, @unchecked Sendable {
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
        let model = configuration.modelID
        var urlString = "\(baseURL)/v1/listen?model=\(model)&smart_format=true"
        if let language = configuration.language {
            urlString += "&language=\(language)"
        }
        guard let url = URL(string: urlString) else {
            throw OpenRockySTTClientError.transcriptionFailed("Invalid Deepgram STT endpoint URL")
        }

        let wavData = OpenRockyOpenAISTTClient.makeWAV(pcmData: audioData, sampleRate: 24000, channels: 1, bitsPerSample: 16)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Token \(credential)", forHTTPHeaderField: "Authorization")
        request.setValue("audio/wav", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = wavData

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

        guard (200...299).contains(statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            rlog.error("Deepgram STT failed: HTTP \(statusCode) \(errorBody.prefix(300))", category: "STT")
            throw OpenRockySTTClientError.transcriptionFailed("HTTP \(statusCode): \(errorBody.prefix(200))")
        }

        // Parse: { "results": { "channels": [{ "alternatives": [{ "transcript": "..." }] }] } }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [String: Any],
              let channels = results["channels"] as? [[String: Any]],
              let firstChannel = channels.first,
              let alternatives = firstChannel["alternatives"] as? [[String: Any]],
              let firstAlt = alternatives.first,
              let transcript = firstAlt["transcript"] as? String else {
            let raw = String(data: data, encoding: .utf8) ?? ""
            rlog.error("Deepgram STT parse error: \(raw.prefix(200))", category: "STT")
            throw OpenRockySTTClientError.transcriptionFailed("Invalid response format")
        }

        rlog.info("Deepgram STT transcribed: \(transcript.prefix(100))", category: "STT")
        return transcript
    }
}
