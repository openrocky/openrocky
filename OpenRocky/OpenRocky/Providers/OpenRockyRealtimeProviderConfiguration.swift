//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation

struct OpenRockyRealtimeProviderConfiguration: Equatable {
    var provider: OpenRockyRealtimeProviderKind
    var modelID: String
    var credential: String? = nil
    var doubaoResourceID: String? = nil
    var doubaoAppId: String? = nil
    var doubaoAppKey: String? = nil
    var doubaoSpeaker: String? = nil
    var openaiVoice: String? = nil
    var geminiVoice: String? = nil
    var glmVoice: String? = nil
    var customHost: String? = nil

    // Character persona (injected from active character)
    var characterName: String? = nil
    var characterSpeakingStyle: String? = nil
    var characterGreeting: String? = nil

    nonisolated var identity: String {
        var parts = [provider.rawValue, modelID]
        parts.append(credential?.isEmpty == false ? "connected" : "disconnected")
        parts.append(doubaoAppId ?? "-")
        parts.append(doubaoSpeaker ?? "-")
        parts.append(openaiVoice ?? "-")
        parts.append(geminiVoice ?? "-")
        parts.append(glmVoice ?? "-")
        parts.append(customHost ?? "-")
        parts.append(characterName ?? "-")
        parts.append(characterSpeakingStyle ?? "-")
        parts.append(characterGreeting ?? "-")
        return parts.joined(separator: "|")
    }

    nonisolated var isConfigured: Bool {
        return credential?.isEmpty == false && modelID.isEmpty == false
    }

    nonisolated var maskedCredential: String {
        guard let credential, credential.count >= 8 else { return "Not connected" }
        return "\(credential.prefix(4))••••\(credential.suffix(4))"
    }

    nonisolated func normalized() -> OpenRockyRealtimeProviderConfiguration {
        OpenRockyRealtimeProviderConfiguration(
            provider: provider,
            modelID: modelID.trimmingCharacters(in: .whitespacesAndNewlines).ifEmpty(provider.defaultModel),
            credential: credential?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            doubaoResourceID: doubaoResourceID?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            doubaoAppId: doubaoAppId?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            doubaoAppKey: doubaoAppKey?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            doubaoSpeaker: doubaoSpeaker?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            openaiVoice: openaiVoice?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            geminiVoice: geminiVoice?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            glmVoice: glmVoice?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            customHost: customHost?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            characterName: characterName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            characterSpeakingStyle: characterSpeakingStyle?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            characterGreeting: characterGreeting?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        )
    }
}

private extension String {
    nonisolated func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }

    nonisolated var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
