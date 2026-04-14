//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-04-14
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation

/// Azure Speech Services STT client using the REST API.
/// Endpoint: /speech/recognition/conversation/cognitiveservices/v1
final class OpenRockyAzureSTTClient: OpenRockySTTClient, @unchecked Sendable {
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
        let language = configuration.language ?? "en-US"
        let url = URL(string: "\(baseURL)/speech/recognition/conversation/cognitiveservices/v1?language=\(language)&format=detailed")!

        let wavData = OpenRockyOpenAISTTClient.makeWAV(pcmData: audioData, sampleRate: 24000, channels: 1, bitsPerSample: 16)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(credential, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        request.setValue("audio/wav; codecs=audio/pcm; samplerate=24000", forHTTPHeaderField: "Content-Type")
        request.setValue("Accept", forHTTPHeaderField: "application/json")
        request.timeoutInterval = 30
        request.httpBody = wavData

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

        guard (200...299).contains(statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            rlog.error("Azure STT failed: HTTP \(statusCode) \(errorBody.prefix(300))", category: "STT")
            throw OpenRockySTTClientError.transcriptionFailed("HTTP \(statusCode): \(errorBody.prefix(200))")
        }

        // Parse: { "RecognitionStatus": "Success", "DisplayText": "..." }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            let raw = String(data: data, encoding: .utf8) ?? ""
            rlog.error("Azure STT parse error: \(raw.prefix(200))", category: "STT")
            throw OpenRockySTTClientError.transcriptionFailed("Invalid response format")
        }

        if let displayText = json["DisplayText"] as? String {
            rlog.info("Azure STT transcribed: \(displayText.prefix(100))", category: "STT")
            return displayText
        }

        // Try NBest format (detailed response)
        if let nbest = json["NBest"] as? [[String: Any]],
           let best = nbest.first,
           let display = best["Display"] as? String {
            rlog.info("Azure STT transcribed (NBest): \(display.prefix(100))", category: "STT")
            return display
        }

        let raw = String(data: data, encoding: .utf8) ?? ""
        rlog.error("Azure STT: no transcript in response: \(raw.prefix(200))", category: "STT")
        throw OpenRockySTTClientError.transcriptionFailed("No transcript in response")
    }
}
