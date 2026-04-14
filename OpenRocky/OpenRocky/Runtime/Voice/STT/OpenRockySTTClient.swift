//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-04-14
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation

/// Result from speech-to-text recognition.
enum OpenRockySTTResult: Sendable {
    /// Partial/intermediate recognition result (may change).
    case partial(String)
    /// Final, committed recognition result.
    case final(String)
}

/// Protocol for speech-to-text providers.
/// Implementations must be sendable and safe for concurrent use.
protocol OpenRockySTTClient: Sendable {
    /// One-shot transcription: send complete audio data, receive final text.
    func transcribe(audioData: Data) async throws -> String
}

enum OpenRockySTTClientError: LocalizedError {
    case notConfigured
    case emptyAudio
    case transcriptionFailed(String)
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "STT provider is not configured."
        case .emptyAudio:
            "No audio data to transcribe."
        case .transcriptionFailed(let detail):
            "Transcription failed: \(detail)"
        case .networkError(let detail):
            "Network error: \(detail)"
        }
    }
}
