//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation

enum OpenRockyRealtimeEvent: Sendable {
    case status(String)
    case sessionReady(model: String, features: OpenRockyRealtimeVoiceFeatures)
    case microphoneActive(Bool)
    case inputSpeechStarted
    case userTranscriptDelta(String)
    case userTranscriptFinal(String)
    case assistantTranscriptDelta(String)
    case assistantTranscriptFinal(String)
    case assistantAudioChunk(String)
    case toolCallRequested(name: String, arguments: String, callID: String)
    case error(String)
}
