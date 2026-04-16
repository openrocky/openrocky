//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-04-14
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation

enum OpenRockySTTProviderKind: String, Codable, CaseIterable, Identifiable {
    case openAI
    case groq
    case deepgram
    case azureSpeech
    case googleCloud
    case aliCloud

    nonisolated var id: String { rawValue }

    nonisolated var displayName: String {
        switch self {
        case .openAI: String(localized: "OpenAI Whisper")
        case .groq: String(localized: "Groq Whisper")
        case .deepgram: String(localized: "Deepgram")
        case .azureSpeech: String(localized: "Azure Speech")
        case .googleCloud: String(localized: "Google Cloud Speech")
        case .aliCloud: String(localized: "Alibaba Cloud Paraformer")
        }
    }

    nonisolated var defaultModel: String {
        switch self {
        case .openAI: "whisper-1"
        case .groq: "whisper-large-v3-turbo"
        case .deepgram: "nova-2"
        case .azureSpeech: "default"
        case .googleCloud: "default"
        case .aliCloud: "paraformer-v2"
        }
    }

    nonisolated var suggestedModels: [String] {
        switch self {
        case .openAI:
            ["whisper-1", "gpt-4o-transcribe", "gpt-4o-mini-transcribe"]
        case .groq:
            ["whisper-large-v3-turbo", "whisper-large-v3", "distil-whisper-large-v3-en"]
        case .deepgram:
            ["nova-2", "nova-3", "enhanced"]
        case .azureSpeech:
            ["default"]
        case .googleCloud:
            ["default"]
        case .aliCloud:
            ["paraformer-v2", "paraformer-realtime-v2"]
        }
    }

    /// Human-readable description for each suggested model.
    nonisolated func modelDescription(_ modelID: String) -> String? {
        switch (self, modelID) {
        case (.openAI, "whisper-1"):
            "Classic Whisper, reliable multilingual recognition"
        case (.openAI, "gpt-4o-transcribe"):
            "GPT-4o powered, best accuracy, higher cost"
        case (.openAI, "gpt-4o-mini-transcribe"):
            "GPT-4o mini, good accuracy at lower cost"
        case (.groq, "whisper-large-v3-turbo"):
            "Fastest, recommended for real-time use"
        case (.groq, "whisper-large-v3"):
            "Highest accuracy, slightly slower"
        case (.groq, "distil-whisper-large-v3-en"):
            "English only, ultra-fast"
        case (.deepgram, "nova-2"):
            "Best accuracy, production recommended"
        case (.deepgram, "nova-3"):
            "Latest generation, improved accuracy"
        case (.deepgram, "enhanced"):
            "Enhanced model, balanced speed/accuracy"
        case (.aliCloud, "paraformer-v2"):
            "Best Chinese recognition accuracy"
        case (.aliCloud, "paraformer-realtime-v2"):
            "Optimized for real-time streaming"
        default:
            nil
        }
    }

    nonisolated var summary: String {
        switch self {
        case .openAI:
            "Industry-leading multilingual speech recognition. Best accuracy for mixed Chinese-English audio."
        case .groq:
            "Groq-powered Whisper. Extremely fast inference with free tier. OpenAI-compatible API."
        case .deepgram:
            "Ultra-low latency (~300ms). Nova-2 model with best real-time accuracy."
        case .azureSpeech:
            "Microsoft Azure Speech Services. Enterprise-grade, 100+ languages, streaming support."
        case .googleCloud:
            "Google Cloud Speech-to-Text. Excellent multilingual support and accuracy."
        case .aliCloud:
            "Alibaba's SenseVoice/Paraformer model. Top-tier Chinese recognition, no VPN needed in China."
        }
    }

    nonisolated var credentialTitle: String {
        switch self {
        case .openAI, .groq, .deepgram, .aliCloud: String(localized: "API Key")
        case .azureSpeech: String(localized: "Subscription Key")
        case .googleCloud: String(localized: "API Key")
        }
    }

    nonisolated var credentialPlaceholder: String {
        switch self {
        case .openAI: "sk-..."
        case .groq: "gsk_..."
        case .deepgram: "your-api-key..."
        case .azureSpeech: "your-subscription-key..."
        case .googleCloud: "your-api-key..."
        case .aliCloud: "sk-..."
        }
    }

    nonisolated var apiKeyGuideURL: String? {
        switch self {
        case .openAI: "https://platform.openai.com/api-keys"
        case .groq: "https://console.groq.com/keys"
        case .deepgram: "https://console.deepgram.com/project/api-keys"
        case .azureSpeech: "https://portal.azure.com/#view/Microsoft_Azure_ProjectOxford/CognitiveServicesHub/~/SpeechServices"
        case .googleCloud: "https://console.cloud.google.com/apis/credentials"
        case .aliCloud: "https://dashscope.console.aliyun.com/apiKey"
        }
    }

    nonisolated var requiresCredential: Bool {
        true
    }

    /// The default API base URL for this provider.
    nonisolated var defaultBaseURL: String {
        switch self {
        case .openAI: "https://api.openai.com"
        case .groq: "https://api.groq.com/openai"
        case .deepgram: "https://api.deepgram.com"
        case .azureSpeech: "https://eastus.stt.speech.microsoft.com"
        case .googleCloud: "https://speech.googleapis.com"
        case .aliCloud: "https://dashscope.aliyuncs.com/compatible-mode"
        }
    }

    /// Estimated transcription latency for typical short audio clips.
    nonisolated var estimatedLatency: String {
        switch self {
        case .openAI: "~1-2s"
        case .groq: "~0.3-0.5s"
        case .deepgram: "~0.3s"
        case .azureSpeech: "~0.5-1s"
        case .googleCloud: "~0.5-1s"
        case .aliCloud: "~0.5-1s"
        }
    }

    /// Estimated price range per minute of audio.
    nonisolated var priceRange: String {
        switch self {
        case .openAI: "$0.006/min"
        case .groq: "Free tier"
        case .deepgram: "$0.0043/min"
        case .azureSpeech: "$0.016/hr"
        case .googleCloud: "$0.006/min"
        case .aliCloud: "~$0.002/min"
        }
    }

    /// Whether this provider uses the OpenAI-compatible /v1/audio/transcriptions endpoint.
    nonisolated var isOpenAICompatible: Bool {
        switch self {
        case .openAI, .groq, .aliCloud: true
        case .deepgram, .azureSpeech, .googleCloud: false
        }
    }
}
