//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-04-14
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation

struct OpenRockyTTSProviderConfiguration: Equatable {
    var provider: OpenRockyTTSProviderKind
    var modelID: String
    var credential: String? = nil
    var voice: String? = nil
    var customHost: String? = nil

    nonisolated var identity: String {
        var parts = [provider.rawValue, modelID]
        parts.append(credential?.isEmpty == false ? "connected" : "disconnected")
        parts.append(voice ?? "-")
        parts.append(customHost ?? "-")
        return parts.joined(separator: "|")
    }

    nonisolated var isConfigured: Bool {
        credential?.isEmpty == false && modelID.isEmpty == false
    }

    nonisolated var maskedCredential: String {
        guard let credential, credential.count >= 8 else { return "Not connected" }
        return "\(credential.prefix(4))••••\(credential.suffix(4))"
    }

    nonisolated var resolvedVoice: String {
        voice?.isEmpty == false ? voice! : provider.defaultVoice
    }

    nonisolated func normalized() -> OpenRockyTTSProviderConfiguration {
        OpenRockyTTSProviderConfiguration(
            provider: provider,
            modelID: modelID.trimmingCharacters(in: .whitespacesAndNewlines).ttsIfEmpty(provider.defaultModel),
            credential: credential?.trimmingCharacters(in: .whitespacesAndNewlines).ttsNilIfEmpty,
            voice: voice?.trimmingCharacters(in: .whitespacesAndNewlines).ttsNilIfEmpty,
            customHost: customHost?.trimmingCharacters(in: .whitespacesAndNewlines).ttsNilIfEmpty
        )
    }
}

private extension String {
    nonisolated func ttsIfEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }

    nonisolated var ttsNilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
