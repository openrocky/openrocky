//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-04-14
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation

/// Protocol for text-to-speech providers.
/// Implementations must support streaming synthesis for low-latency playback.
protocol OpenRockyTTSClient: Sendable {
    /// Synthesize text into audio data (complete, non-streaming).
    /// Returns raw audio data (format depends on provider — typically MP3 or PCM).
    func synthesize(text: String) async throws -> Data

    /// The audio format returned by this provider.
    var outputFormat: OpenRockyTTSAudioFormat { get }
}

enum OpenRockyTTSAudioFormat: Sendable {
    case mp3
    case pcm16(sampleRate: Int)
    case opus
    case aac
}

enum OpenRockyTTSClientError: LocalizedError {
    case notConfigured
    case emptyText
    case synthesisFailed(String)
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "TTS provider is not configured."
        case .emptyText:
            "No text to synthesize."
        case .synthesisFailed(let detail):
            "Speech synthesis failed: \(detail)"
        case .networkError(let detail):
            "Network error: \(detail)"
        }
    }
}
