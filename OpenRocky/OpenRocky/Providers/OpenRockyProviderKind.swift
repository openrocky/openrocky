//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation

enum OpenRockyProviderKind: String, Codable, CaseIterable, Identifiable {
    case appleFoundationModels
    case openAI
    case azureOpenAI
    case anthropic
    case gemini
    case groq
    case xAI
    case openRouter
    case deepSeek
    case volcengine
    case aiProxy

    nonisolated var id: String { rawValue }

    nonisolated var displayName: String {
        switch self {
        case .appleFoundationModels: String(localized: "Apple Intelligence")
        case .openAI: String(localized: "OpenAI")
        case .azureOpenAI: String(localized: "Azure OpenAI")
        case .anthropic: String(localized: "Anthropic")
        case .gemini: String(localized: "Gemini")
        case .groq: String(localized: "Groq")
        case .xAI: String(localized: "xAI")
        case .openRouter: String(localized: "OpenRouter")
        case .deepSeek: String(localized: "DeepSeek")
        case .volcengine: String(localized: "Doubao (Volcengine)")
        case .aiProxy: String(localized: "AIProxy")
        }
    }

    nonisolated var defaultModel: String {
        switch self {
        case .appleFoundationModels: "apple-foundation-model"
        case .openAI: "gpt-5"
        case .azureOpenAI: "gpt-4o"
        case .anthropic: "claude-3-7-sonnet-20250219"
        case .gemini: "gemini-2.5-pro"
        case .groq: "llama-3.3-70b-versatile"
        case .xAI: "grok-3-beta"
        case .openRouter: "anthropic/claude-sonnet-4.5"
        case .deepSeek: "deepseek-chat"
        case .volcengine: "doubao-seed-1-8-251228"
        case .aiProxy: "gpt-5"
        }
    }

    nonisolated var suggestedModels: [String] {
        switch self {
        case .appleFoundationModels:
            ["apple-foundation-model"]
        case .openAI:
            ["gpt-5", "gpt-5-mini", "gpt-4o"]
        case .azureOpenAI:
            ["gpt-4o", "gpt-4.1", "gpt-5"]
        case .anthropic:
            ["claude-3-7-sonnet-20250219", "claude-3-5-sonnet-latest"]
        case .gemini:
            ["gemini-2.5-pro", "gemini-2.5-flash"]
        case .groq:
            ["llama-3.3-70b-versatile", "deepseek-r1-distill-llama-70b"]
        case .xAI:
            ["grok-3-beta", "grok-3-mini-beta"]
        case .openRouter:
            ["anthropic/claude-sonnet-4.5", "deepseek/deepseek-r1"]
        case .deepSeek:
            ["deepseek-chat", "deepseek-reasoner"]
        case .volcengine:
            ["doubao-seed-1-8-251228", "doubao-1.5-pro-256k-250115", "doubao-1.5-thinking-pro-250415"]
        case .aiProxy:
            ["gpt-5", "gpt-5-mini", "gpt-4o"]
        }
    }

    nonisolated var summary: String {
        switch self {
        case .appleFoundationModels:
            "On-device Apple Intelligence model. No API key required. Requires a supported device with iOS 26+."
        case .openAI:
            "Direct OpenAI API key access."
        case .azureOpenAI:
            "Azure-hosted OpenAI deployment. Requires resource name and API version."
        case .anthropic:
            "Anthropic OpenAI-compatible endpoint through SwiftOpenAI."
        case .gemini:
            "Google Gemini OpenAI-compatible endpoint."
        case .groq:
            "Groq OpenAI-compatible endpoint for fast inference."
        case .xAI:
            "xAI Grok OpenAI-compatible endpoint."
        case .openRouter:
            "OpenRouter OpenAI-compatible endpoint with optional ranking headers."
        case .deepSeek:
            "DeepSeek OpenAI-compatible endpoint."
        case .volcengine:
            "Volcengine Doubao OpenAI-compatible endpoint."
        case .aiProxy:
            "AIProxy-backed OpenAI traffic using partial key plus service URL."
        }
    }

    nonisolated var apiKeyPlaceholder: String {
        switch self {
        case .appleFoundationModels:
            ""
        case .openAI, .azureOpenAI, .gemini, .groq, .xAI, .openRouter, .deepSeek:
            "sk-..."
        case .anthropic:
            "sk-ant-..."
        case .volcengine:
            "API Key"
        case .aiProxy:
            "pk_live_..."
        }
    }

    nonisolated var apiKeyGuideURL: String? {
        switch self {
        case .appleFoundationModels: nil
        case .openAI: "https://platform.openai.com/api-keys"
        case .azureOpenAI: "https://portal.azure.com"
        case .anthropic: "https://console.anthropic.com/settings/keys"
        case .gemini: "https://aistudio.google.com/apikey"
        case .groq: "https://console.groq.com/keys"
        case .xAI: "https://console.x.ai"
        case .openRouter: "https://openrouter.ai/keys"
        case .deepSeek: "https://platform.deepseek.com/api_keys"
        case .volcengine: "https://console.volcengine.com/ark/region:ark+cn-beijing/apiKey"
        case .aiProxy: nil
        }
    }

    /// Whether this provider requires an API key / credential.
    nonisolated var requiresCredential: Bool {
        self != .appleFoundationModels
    }

    nonisolated var defaultAzureAPIVersion: String? {
        self == .azureOpenAI ? "2024-10-21" : nil
    }
}
