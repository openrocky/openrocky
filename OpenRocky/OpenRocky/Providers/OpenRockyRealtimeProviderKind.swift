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
    case openAI
    case glm

    nonisolated var id: String { rawValue }

    nonisolated var displayName: String {
        switch self {
        case .openAI: String(localized: "OpenAI Realtime")
        case .glm: String(localized: "GLM Realtime")
        }
    }

    nonisolated var defaultModel: String {
        switch self {
        case .openAI: OpenRockyOpenAIServiceFactory.defaultRealtimeModel
        case .glm: "glm-realtime"
        }
    }

    nonisolated var suggestedModels: [String] {
        switch self {
        case .openAI:
            ["gpt-realtime-mini", "gpt-realtime"]
        case .glm:
            ["glm-realtime", "glm-realtime-flash"]
        }
    }

    nonisolated var summary: String {
        switch self {
        case .openAI:
            "End-to-end realtime voice agent with transcript, tool calling, and audio output."
        case .glm:
            "Zhipu AI end-to-end realtime voice with tool calling. Optimized for Chinese. No VPN needed in China."
        }
    }

    nonisolated var credentialTitle: String {
        switch self {
        case .openAI: String(localized: "API Key")
        case .glm: String(localized: "API Key")
        }
    }

    nonisolated var credentialPlaceholder: String {
        switch self {
        case .openAI: "sk-..."
        case .glm: "your-api-key..."
        }
    }

    nonisolated var apiKeyGuideURL: String? {
        switch self {
        case .openAI: "https://platform.openai.com/api-keys"
        case .glm: "https://open.bigmodel.cn/usercenter/apikeys"
        }
    }

    /// Whether this voice provider requires a credential.
    nonisolated var requiresCredential: Bool {
        true
    }
}
