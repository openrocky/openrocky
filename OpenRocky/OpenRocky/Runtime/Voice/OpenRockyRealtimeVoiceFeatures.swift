//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation

struct OpenRockyRealtimeVoiceFeatures: Sendable, Equatable {
    let supportsTextInput: Bool
    let supportsAssistantStreaming: Bool
    let supportsToolCalls: Bool
    let supportsAudioOutput: Bool
    /// When true, the bridge suspends mic during TTS playback (OpenAI needs this).
    /// When false, mic streams continuously — the server handles VAD/echo (Doubao).
    let needsMicSuspension: Bool

    static let openAI = OpenRockyRealtimeVoiceFeatures(
        supportsTextInput: true,
        supportsAssistantStreaming: true,
        supportsToolCalls: true,
        supportsAudioOutput: true,
        needsMicSuspension: true
    )

    static let glm = OpenRockyRealtimeVoiceFeatures(
        supportsTextInput: true,
        supportsAssistantStreaming: true,
        supportsToolCalls: true,
        supportsAudioOutput: true,
        needsMicSuspension: true
    )

}
