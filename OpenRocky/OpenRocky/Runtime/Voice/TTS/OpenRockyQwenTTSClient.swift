//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-04-19
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation

/// Alibaba Qwen-TTS client via DashScope multimodal-generation endpoint.
/// Synthesis returns a JSON envelope containing a temporary audio URL,
/// which we then fetch to obtain the raw WAV bytes.
final class OpenRockyQwenTTSClient: OpenRockyTTSClient, @unchecked Sendable {
    private let configuration: OpenRockyTTSProviderConfiguration

    let outputFormat: OpenRockyTTSAudioFormat = .pcm16(sampleRate: 24000)

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
        guard let url = URL(string: "\(baseURL)/api/v1/services/aigc/multimodal-generation/generation") else {
            throw OpenRockyTTSClientError.synthesisFailed("Invalid Qwen-TTS endpoint URL")
        }

        let body: [String: Any] = [
            "model": configuration.modelID,
            "input": [
                "text": trimmed,
                "voice": configuration.resolvedVoice,
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
            rlog.error("Qwen-TTS failed: HTTP \(statusCode) \(errorBody.prefix(300))", category: "TTS")
            throw OpenRockyTTSClientError.synthesisFailed("HTTP \(statusCode): \(errorBody.prefix(200))")
        }

        // Parse: { "output": { "audio": { "url": "..." } } }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let output = json["output"] as? [String: Any],
              let audio = output["audio"] as? [String: Any],
              let audioURLString = audio["url"] as? String,
              let audioURL = URL(string: audioURLString) else {
            let raw = String(data: data, encoding: .utf8) ?? ""
            rlog.error("Qwen-TTS parse error: \(raw.prefix(300))", category: "TTS")
            throw OpenRockyTTSClientError.synthesisFailed("Invalid Qwen-TTS response")
        }

        // Fetch the actual audio bytes from the temporary URL
        var fetchRequest = URLRequest(url: audioURL)
        fetchRequest.timeoutInterval = 30
        let (audioData, audioResponse) = try await URLSession.shared.data(for: fetchRequest)
        let audioStatus = (audioResponse as? HTTPURLResponse)?.statusCode ?? 0
        guard (200...299).contains(audioStatus), !audioData.isEmpty else {
            rlog.error("Qwen-TTS audio fetch failed: HTTP \(audioStatus)", category: "TTS")
            throw OpenRockyTTSClientError.synthesisFailed("Failed to download Qwen-TTS audio (HTTP \(audioStatus))")
        }

        rlog.info("Qwen-TTS synthesized: \(audioData.count) bytes for \(trimmed.count) chars", category: "TTS")
        return audioData
    }
}
