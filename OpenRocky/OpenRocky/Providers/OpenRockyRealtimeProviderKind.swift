//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation

enum OpenRockyRealtimeProviderKind: String, Codable, CaseIterable, Identifiable {
    case apple
    case openAI
    case doubao
    case gemini

    nonisolated var id: String { rawValue }

    nonisolated var displayName: String {
        switch self {
        case .apple: String(localized: "Apple Voice (Beta)")
        case .openAI: String(localized: "OpenAI Realtime")
        case .doubao: String(localized: "Doubao Realtime (Beta)")
        case .gemini: String(localized: "Gemini Live (Beta)")
        }
    }

    nonisolated var defaultModel: String {
        switch self {
        case .apple: "apple-native-voice"
        case .openAI: OpenRockyOpenAIServiceFactory.defaultRealtimeModel
        case .doubao: "doubao-e2e-voice"
        case .gemini: "gemini-2.5-flash-native-audio-latest"
        }
    }

    nonisolated var suggestedModels: [String] {
        switch self {
        case .apple:
            ["apple-native-voice"]
        case .openAI:
            ["gpt-realtime-mini", "gpt-realtime"]
        case .doubao:
            ["doubao-e2e-voice"]
        case .gemini:
            ["gemini-2.5-flash-native-audio-latest", "gemini-3.1-flash-live-preview"]
        }
    }

    nonisolated var summary: String {
        switch self {
        case .apple:
            "On-device voice using Apple Speech Recognition + Apple Intelligence + system TTS. No API key required."
        case .openAI:
            "End-to-end realtime voice agent with transcript, tool calling, and audio output."
        case .doubao:
            "End-to-end realtime voice with natural speech, emotion, tool calling, and audio output. Optimized for Chinese."
        case .gemini:
            "Gemini native multimodal live voice with tool calling. Fast and cost-effective."
        }
    }

    nonisolated var credentialTitle: String {
        switch self {
        case .apple: String(localized: "")
        case .openAI: String(localized: "API Key")
        case .doubao: String(localized: "Access Token")
        case .gemini: String(localized: "API Key")
        }
    }

    nonisolated var credentialPlaceholder: String {
        switch self {
        case .apple: ""
        case .openAI: "sk-..."
        case .doubao: String(localized: "Access Token from console")
        case .gemini: "AIza..."
        }
    }

    nonisolated var apiKeyGuideURL: String? {
        switch self {
        case .apple: nil
        case .openAI: "https://platform.openai.com/api-keys"
        case .doubao: "https://console.volcengine.com/speech/service/10017"
        case .gemini: "https://aistudio.google.com/apikey"
        }
    }

    /// Whether this voice provider requires a credential.
    nonisolated var requiresCredential: Bool {
        self != .apple
    }
}
