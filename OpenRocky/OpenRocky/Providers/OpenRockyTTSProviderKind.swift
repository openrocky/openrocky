//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-04-14
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation

enum OpenRockyTTSProviderKind: String, Codable, CaseIterable, Identifiable {
    case openAI
    case miniMax
    case elevenLabs
    case volcengine
    case azureSpeech
    case googleCloud
    case aliCloud

    nonisolated var id: String { rawValue }

    nonisolated var displayName: String {
        switch self {
        case .openAI: String(localized: "OpenAI TTS")
        case .miniMax: String(localized: "MiniMax TTS")
        case .elevenLabs: String(localized: "ElevenLabs")
        case .volcengine: String(localized: "Volcengine (Doubao)")
        case .azureSpeech: String(localized: "Azure Speech")
        case .googleCloud: String(localized: "Google Cloud TTS")
        case .aliCloud: String(localized: "Alibaba Cloud CosyVoice")
        }
    }

    nonisolated var defaultModel: String {
        switch self {
        case .openAI: "tts-1"
        case .miniMax: "speech-02-hd"
        case .elevenLabs: "eleven_multilingual_v2"
        case .volcengine: "default"
        case .azureSpeech: "default"
        case .googleCloud: "default"
        case .aliCloud: "cosyvoice-v1"
        }
    }

    nonisolated var suggestedModels: [String] {
        switch self {
        case .openAI:
            ["tts-1", "tts-1-hd"]
        case .miniMax:
            ["speech-02-hd", "speech-02"]
        case .elevenLabs:
            ["eleven_multilingual_v2", "eleven_turbo_v2_5", "eleven_flash_v2_5"]
        case .volcengine:
            ["default"]
        case .azureSpeech:
            ["default"]
        case .googleCloud:
            ["default"]
        case .aliCloud:
            ["cosyvoice-v1"]
        }
    }

    nonisolated var summary: String {
        switch self {
        case .openAI:
            "High quality text-to-speech. Multiple voices, fast latency, great for English."
        case .miniMax:
            "Natural Chinese TTS with emotional expression. No VPN needed in China."
        case .elevenLabs:
            "World's most natural TTS. Voice cloning, 29+ languages, ultra-realistic."
        case .volcengine:
            "ByteDance Volcengine (Doubao) TTS. Excellent Chinese voices, no VPN needed in China."
        case .azureSpeech:
            "Microsoft Azure Speech. 400+ voices, SSML control, enterprise-grade."
        case .googleCloud:
            "Google Cloud Text-to-Speech. WaveNet and Neural2 voices, 40+ languages."
        case .aliCloud:
            "Alibaba CosyVoice TTS. Great Chinese voices, OpenAI-compatible API."
        }
    }

    nonisolated var credentialTitle: String {
        switch self {
        case .openAI, .miniMax, .elevenLabs, .aliCloud: String(localized: "API Key")
        case .volcengine: String(localized: "Access Token")
        case .azureSpeech: String(localized: "Subscription Key")
        case .googleCloud: String(localized: "API Key")
        }
    }

    nonisolated var credentialPlaceholder: String {
        switch self {
        case .openAI: "sk-..."
        case .miniMax: "eyJ..."
        case .elevenLabs: "sk_..."
        case .volcengine: "your-access-token..."
        case .azureSpeech: "your-subscription-key..."
        case .googleCloud: "your-api-key..."
        case .aliCloud: "sk-..."
        }
    }

    nonisolated var apiKeyGuideURL: String? {
        switch self {
        case .openAI: "https://platform.openai.com/api-keys"
        case .miniMax: "https://platform.minimaxi.com/user-center/basic-information/interface-key"
        case .elevenLabs: "https://elevenlabs.io/app/settings/api-keys"
        case .volcengine: "https://console.volcengine.com/speech/service/8"
        case .azureSpeech: "https://portal.azure.com/#view/Microsoft_Azure_ProjectOxford/CognitiveServicesHub/~/SpeechServices"
        case .googleCloud: "https://console.cloud.google.com/apis/credentials"
        case .aliCloud: "https://dashscope.console.aliyun.com/apiKey"
        }
    }

    nonisolated var requiresCredential: Bool {
        true
    }

    nonisolated var defaultBaseURL: String {
        switch self {
        case .openAI: "https://api.openai.com"
        case .miniMax: "https://api.minimax.chat"
        case .elevenLabs: "https://api.elevenlabs.io"
        case .volcengine: "https://openspeech.bytedance.com"
        case .azureSpeech: "https://eastus.tts.speech.microsoft.com"
        case .googleCloud: "https://texttospeech.googleapis.com"
        case .aliCloud: "https://dashscope.aliyuncs.com/compatible-mode"
        }
    }

    nonisolated var defaultVoice: String {
        switch self {
        case .openAI: "alloy"
        case .miniMax: "female-tianmei"
        case .elevenLabs: "Rachel"
        case .volcengine: "zh_female_tianmei"
        case .azureSpeech: "en-US-JennyNeural"
        case .googleCloud: "en-US-Neural2-C"
        case .aliCloud: "longxiaochun"
        }
    }

    /// Whether this provider uses the OpenAI-compatible /v1/audio/speech endpoint.
    nonisolated var isOpenAICompatible: Bool {
        switch self {
        case .openAI, .aliCloud: true
        case .miniMax, .elevenLabs, .volcengine, .azureSpeech, .googleCloud: false
        }
    }

    nonisolated var availableVoices: [OpenRockyTTSVoice] {
        switch self {
        case .openAI:
            [
                OpenRockyTTSVoice(id: "alloy", name: "Alloy", subtitle: "Neutral and balanced"),
                OpenRockyTTSVoice(id: "ash", name: "Ash", subtitle: "Soft and warm"),
                OpenRockyTTSVoice(id: "coral", name: "Coral", subtitle: "Clear and bright"),
                OpenRockyTTSVoice(id: "echo", name: "Echo", subtitle: "Confident and deep"),
                OpenRockyTTSVoice(id: "nova", name: "Nova", subtitle: "Friendly and energetic"),
                OpenRockyTTSVoice(id: "sage", name: "Sage", subtitle: "Calm and authoritative"),
                OpenRockyTTSVoice(id: "shimmer", name: "Shimmer", subtitle: "Gentle and versatile"),
            ]
        case .miniMax:
            [
                OpenRockyTTSVoice(id: "female-tianmei", name: "Tianmei", subtitle: "Sweet female voice"),
                OpenRockyTTSVoice(id: "female-shaonv", name: "Shaonv", subtitle: "Young female voice"),
                OpenRockyTTSVoice(id: "male-qn-qingse", name: "Qingse", subtitle: "Gentle male voice"),
                OpenRockyTTSVoice(id: "male-qn-jingying", name: "Jingying", subtitle: "Professional male voice"),
                OpenRockyTTSVoice(id: "female-yujie", name: "Yujie", subtitle: "Mature female voice"),
                OpenRockyTTSVoice(id: "presenter_male", name: "Presenter", subtitle: "Broadcast male voice"),
                OpenRockyTTSVoice(id: "audiobook_female_1", name: "Audiobook", subtitle: "Audiobook female voice"),
            ]
        case .elevenLabs:
            [
                OpenRockyTTSVoice(id: "Rachel", name: "Rachel", subtitle: "Calm, young female"),
                OpenRockyTTSVoice(id: "Drew", name: "Drew", subtitle: "Well-rounded, middle-aged male"),
                OpenRockyTTSVoice(id: "Clyde", name: "Clyde", subtitle: "War veteran, middle-aged male"),
                OpenRockyTTSVoice(id: "Paul", name: "Paul", subtitle: "Authoritative, ground news"),
                OpenRockyTTSVoice(id: "Domi", name: "Domi", subtitle: "Strong, young female"),
                OpenRockyTTSVoice(id: "Dave", name: "Dave", subtitle: "Conversational, young male"),
                OpenRockyTTSVoice(id: "Fin", name: "Fin", subtitle: "Elderly, Irish male"),
                OpenRockyTTSVoice(id: "Sarah", name: "Sarah", subtitle: "Soft, young female"),
            ]
        case .volcengine:
            [
                OpenRockyTTSVoice(id: "zh_female_tianmei", name: "Tianmei", subtitle: "Sweet Chinese female"),
                OpenRockyTTSVoice(id: "zh_male_chunhou", name: "Chunhou", subtitle: "Mature Chinese male"),
                OpenRockyTTSVoice(id: "zh_female_shuangkuai", name: "Shuangkuai", subtitle: "Energetic Chinese female"),
                OpenRockyTTSVoice(id: "zh_male_yangguang", name: "Yangguang", subtitle: "Sunny Chinese male"),
                OpenRockyTTSVoice(id: "en_female_sarah", name: "Sarah", subtitle: "English female"),
                OpenRockyTTSVoice(id: "en_male_caleb", name: "Caleb", subtitle: "English male"),
            ]
        case .azureSpeech:
            [
                OpenRockyTTSVoice(id: "en-US-JennyNeural", name: "Jenny", subtitle: "English (US) female"),
                OpenRockyTTSVoice(id: "en-US-GuyNeural", name: "Guy", subtitle: "English (US) male"),
                OpenRockyTTSVoice(id: "zh-CN-XiaoxiaoNeural", name: "Xiaoxiao", subtitle: "Chinese (Mandarin) female"),
                OpenRockyTTSVoice(id: "zh-CN-YunxiNeural", name: "Yunxi", subtitle: "Chinese (Mandarin) male"),
                OpenRockyTTSVoice(id: "zh-CN-XiaoyiNeural", name: "Xiaoyi", subtitle: "Chinese (Mandarin) female"),
                OpenRockyTTSVoice(id: "ja-JP-NanamiNeural", name: "Nanami", subtitle: "Japanese female"),
            ]
        case .googleCloud:
            [
                OpenRockyTTSVoice(id: "en-US-Neural2-C", name: "Neural2-C", subtitle: "English (US) female"),
                OpenRockyTTSVoice(id: "en-US-Neural2-D", name: "Neural2-D", subtitle: "English (US) male"),
                OpenRockyTTSVoice(id: "cmn-CN-Wavenet-A", name: "Wavenet-A", subtitle: "Chinese female"),
                OpenRockyTTSVoice(id: "cmn-CN-Wavenet-B", name: "Wavenet-B", subtitle: "Chinese male"),
                OpenRockyTTSVoice(id: "ja-JP-Neural2-B", name: "Neural2-B", subtitle: "Japanese female"),
            ]
        case .aliCloud:
            [
                OpenRockyTTSVoice(id: "longxiaochun", name: "Xiaochun", subtitle: "Chinese female, warm"),
                OpenRockyTTSVoice(id: "longxiaoxia", name: "Xiaoxia", subtitle: "Chinese female, sweet"),
                OpenRockyTTSVoice(id: "longyue", name: "Yue", subtitle: "Chinese male, calm"),
                OpenRockyTTSVoice(id: "longlaotie", name: "Laotie", subtitle: "Chinese male, deep"),
            ]
        }
    }
}

struct OpenRockyTTSVoice: Identifiable, Equatable {
    let id: String
    let name: String
    let subtitle: String
}
