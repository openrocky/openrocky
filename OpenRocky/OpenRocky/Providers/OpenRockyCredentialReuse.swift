//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-04-14
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation

/// Finds reusable API credentials across all provider stores for a given provider family.
/// For example, if the user has an OpenAI Chat key configured, adding OpenAI STT should
/// offer to reuse that same key instead of requiring manual re-entry.
@MainActor
struct OpenRockyCredentialReuse {
    struct ReusableCredential {
        let credential: String
        let sourceName: String   // e.g. "OpenAI (Chat)"
        let maskedCredential: String
    }

    /// Find reusable credentials for an STT provider kind by scanning chat, realtime, and TTS stores.
    static func findCredentials(
        forSTTProvider sttKind: OpenRockySTTProviderKind,
        chatStore: OpenRockyProviderStore,
        realtimeStore: OpenRockyRealtimeProviderStore,
        ttsStore: OpenRockyTTSProviderStore
    ) -> [ReusableCredential] {
        var results: [ReusableCredential] = []
        let family = sttKind.credentialFamily

        // Search chat provider instances
        for instance in chatStore.instances {
            if instance.kind.credentialFamily == family,
               let cred = chatStore.credential(for: instance), !cred.isEmpty {
                results.append(ReusableCredential(
                    credential: cred,
                    sourceName: "\(instance.name) (Chat)",
                    maskedCredential: mask(cred)
                ))
            }
        }

        // Search realtime voice provider instances
        for instance in realtimeStore.instances {
            if instance.kind.credentialFamily == family,
               let cred = realtimeStore.credential(for: instance), !cred.isEmpty {
                results.append(ReusableCredential(
                    credential: cred,
                    sourceName: "\(instance.name) (Voice)",
                    maskedCredential: mask(cred)
                ))
            }
        }

        // Search TTS provider instances
        for instance in ttsStore.instances {
            if instance.kind.credentialFamily == family,
               let cred = ttsStore.credential(for: instance), !cred.isEmpty {
                results.append(ReusableCredential(
                    credential: cred,
                    sourceName: "\(instance.name) (TTS)",
                    maskedCredential: mask(cred)
                ))
            }
        }

        // Deduplicate by credential value
        var seen = Set<String>()
        return results.filter { seen.insert($0.credential).inserted }
    }

    /// Find reusable credentials for a TTS provider kind by scanning chat, realtime, and STT stores.
    static func findCredentials(
        forTTSProvider ttsKind: OpenRockyTTSProviderKind,
        chatStore: OpenRockyProviderStore,
        realtimeStore: OpenRockyRealtimeProviderStore,
        sttStore: OpenRockySTTProviderStore
    ) -> [ReusableCredential] {
        var results: [ReusableCredential] = []
        let family = ttsKind.credentialFamily

        // Search chat provider instances
        for instance in chatStore.instances {
            if instance.kind.credentialFamily == family,
               let cred = chatStore.credential(for: instance), !cred.isEmpty {
                results.append(ReusableCredential(
                    credential: cred,
                    sourceName: "\(instance.name) (Chat)",
                    maskedCredential: mask(cred)
                ))
            }
        }

        // Search realtime voice provider instances
        for instance in realtimeStore.instances {
            if instance.kind.credentialFamily == family,
               let cred = realtimeStore.credential(for: instance), !cred.isEmpty {
                results.append(ReusableCredential(
                    credential: cred,
                    sourceName: "\(instance.name) (Voice)",
                    maskedCredential: mask(cred)
                ))
            }
        }

        // Search STT provider instances
        for instance in sttStore.instances {
            if instance.kind.credentialFamily == family,
               let cred = sttStore.credential(for: instance), !cred.isEmpty {
                results.append(ReusableCredential(
                    credential: cred,
                    sourceName: "\(instance.name) (STT)",
                    maskedCredential: mask(cred)
                ))
            }
        }

        // Deduplicate by credential value
        var seen = Set<String>()
        return results.filter { seen.insert($0.credential).inserted }
    }

    private static func mask(_ credential: String) -> String {
        guard credential.count > 8 else { return "****" }
        let prefix = credential.prefix(4)
        let suffix = credential.suffix(4)
        return "\(prefix)****\(suffix)"
    }
}

// MARK: - Credential Family Mapping

/// Providers that share the same API platform and can reuse each other's credentials.
enum OpenRockyCredentialFamily: String {
    case openAI
    case groq
    case azureSpeech
    case googleCloud
    case aliCloud
    case deepgram
    case elevenLabs
    case miniMax
    case volcengine
    case zhipuAI
    case other
}

extension OpenRockyProviderKind {
    var credentialFamily: OpenRockyCredentialFamily {
        switch self {
        case .openAI, .aiProxy: .openAI
        case .groq: .groq
        case .azureOpenAI: .azureSpeech
        case .gemini: .googleCloud
        case .volcengine: .volcengine
        case .zhipuAI: .zhipuAI
        case .deepSeek, .anthropic, .xAI, .openRouter, .bailian, .appleFoundationModels: .other
        }
    }
}

extension OpenRockyRealtimeProviderKind {
    var credentialFamily: OpenRockyCredentialFamily {
        switch self {
        case .openAI: .openAI
        case .glm: .zhipuAI
        }
    }
}

extension OpenRockySTTProviderKind {
    var credentialFamily: OpenRockyCredentialFamily {
        switch self {
        case .openAI: .openAI
        case .groq: .groq
        case .deepgram: .deepgram
        case .azureSpeech: .azureSpeech
        case .googleCloud: .googleCloud
        case .aliCloud: .aliCloud
        }
    }
}

extension OpenRockyTTSProviderKind {
    var credentialFamily: OpenRockyCredentialFamily {
        switch self {
        case .openAI: .openAI
        case .miniMax: .miniMax
        case .elevenLabs: .elevenLabs
        case .volcengine: .volcengine
        case .azureSpeech: .azureSpeech
        case .googleCloud: .googleCloud
        case .aliCloud, .qwenTTS: .aliCloud
        case .zhipuGLM: .zhipuAI
        }
    }
}
