//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-04-14
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation

/// OpenAI Whisper / gpt-4o-transcribe speech-to-text client.
/// Uses the /v1/audio/transcriptions endpoint (multipart form upload).
final class OpenRockyOpenAISTTClient: OpenRockySTTClient, @unchecked Sendable {
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
        guard let url = URL(string: "\(baseURL)/v1/audio/transcriptions") else {
            throw OpenRockySTTClientError.transcriptionFailed("Invalid STT endpoint URL")
        }

        let boundary = "OpenRocky-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(credential)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        // Build multipart form data
        var body = Data()

        // File field: audio data as WAV
        let wavData = Self.makeWAV(pcmData: audioData, sampleRate: 24000, channels: 1, bitsPerSample: 16)
        body.appendMultipart(boundary: boundary, name: "file", filename: "audio.wav", contentType: "audio/wav", data: wavData)

        // Model field
        body.appendMultipart(boundary: boundary, name: "model", value: configuration.modelID)

        // Response format
        body.appendMultipart(boundary: boundary, name: "response_format", value: "json")

        // Language hint (optional)
        if let language = configuration.language {
            body.appendMultipart(boundary: boundary, name: "language", value: language)
        }

        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

        guard (200...299).contains(statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            rlog.error("STT request failed: HTTP \(statusCode) \(errorBody.prefix(300))", category: "STT")
            throw OpenRockySTTClientError.transcriptionFailed("HTTP \(statusCode): \(errorBody.prefix(200))")
        }

        // Parse JSON response: { "text": "..." }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = json["text"] as? String else {
            let raw = String(data: data, encoding: .utf8) ?? ""
            rlog.error("STT parse error: \(raw.prefix(200))", category: "STT")
            throw OpenRockySTTClientError.transcriptionFailed("Invalid response format")
        }

        rlog.info("STT transcribed: \(text.prefix(100))", category: "STT")
        return text
    }

    /// Wraps raw PCM16 data in a minimal WAV header. Shared by other STT clients.
    static func makeWAV(pcmData: Data, sampleRate: Int, channels: Int, bitsPerSample: Int) -> Data {
        let byteRate = sampleRate * channels * bitsPerSample / 8
        let blockAlign = channels * bitsPerSample / 8
        let dataSize = pcmData.count
        let fileSize = 36 + dataSize

        var header = Data()
        header.append(contentsOf: "RIFF".utf8)
        header.appendLittleEndian(UInt32(fileSize))
        header.append(contentsOf: "WAVE".utf8)
        header.append(contentsOf: "fmt ".utf8)
        header.appendLittleEndian(UInt32(16)) // chunk size
        header.appendLittleEndian(UInt16(1))  // PCM format
        header.appendLittleEndian(UInt16(channels))
        header.appendLittleEndian(UInt32(sampleRate))
        header.appendLittleEndian(UInt32(byteRate))
        header.appendLittleEndian(UInt16(blockAlign))
        header.appendLittleEndian(UInt16(bitsPerSample))
        header.append(contentsOf: "data".utf8)
        header.appendLittleEndian(UInt32(dataSize))
        header.append(pcmData)
        return header
    }
}

// MARK: - Data Helpers

private extension Data {
    mutating func appendMultipart(boundary: String, name: String, filename: String, contentType: String, data: Data) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        append("Content-Type: \(contentType)\r\n\r\n".data(using: .utf8)!)
        append(data)
        append("\r\n".data(using: .utf8)!)
    }

    mutating func appendMultipart(boundary: String, name: String, value: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append(value.data(using: .utf8)!)
        append("\r\n".data(using: .utf8)!)
    }

    mutating func appendLittleEndian(_ value: UInt32) {
        var v = value.littleEndian
        append(Data(bytes: &v, count: 4))
    }

    mutating func appendLittleEndian(_ value: UInt16) {
        var v = value.littleEndian
        append(Data(bytes: &v, count: 2))
    }
}
