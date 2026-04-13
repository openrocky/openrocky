//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation
@preconcurrency import SwiftOpenAI

@RealtimeActor
protocol OpenRockyRealtimeVoiceClient: AnyObject, Sendable {
    var modelID: String { get }
    var features: OpenRockyRealtimeVoiceFeatures { get }

    func connect(eventSink: @escaping @Sendable (OpenRockyRealtimeEvent) -> Void) async throws
    func disconnect() async
    func sendText(_ text: String) async throws
    func sendAudioChunk(base64Audio: String) async throws
    func finishAudioInput() async throws
    func sendToolOutput(callID: String, output: String) async throws
    /// Speak text via TTS without going through the dialog model. Default: no-op.
    func speakText(_ text: String) async throws
    /// Cancel any in-progress response (used for interruption). Default: no-op.
    func cancelResponse() async throws
}

extension OpenRockyRealtimeVoiceClient {
    func speakText(_ text: String) async throws {
        // Default: no-op. Overridden by providers that support external TTS injection.
    }
    func cancelResponse() async throws {
        // Default: no-op.
    }
}
