//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-04-14
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation

struct OpenRockySTTProviderConfiguration: Equatable {
    var provider: OpenRockySTTProviderKind
    var modelID: String
    var credential: String? = nil
    var customHost: String? = nil
    var language: String? = nil

    nonisolated var identity: String {
        var parts = [provider.rawValue, modelID]
        parts.append(credential?.isEmpty == false ? "connected" : "disconnected")
        parts.append(customHost ?? "-")
        parts.append(language ?? "-")
        return parts.joined(separator: "|")
    }

    nonisolated var isConfigured: Bool {
        credential?.isEmpty == false && modelID.isEmpty == false
    }

    nonisolated var maskedCredential: String {
        guard let credential, credential.count >= 8 else { return "Not connected" }
        return "\(credential.prefix(4))••••\(credential.suffix(4))"
    }

    nonisolated func normalized() -> OpenRockySTTProviderConfiguration {
        OpenRockySTTProviderConfiguration(
            provider: provider,
            modelID: modelID.trimmingCharacters(in: .whitespacesAndNewlines).sttIfEmpty(provider.defaultModel),
            credential: credential?.trimmingCharacters(in: .whitespacesAndNewlines).sttNilIfEmpty,
            customHost: customHost?.trimmingCharacters(in: .whitespacesAndNewlines).sttNilIfEmpty,
            language: language?.trimmingCharacters(in: .whitespacesAndNewlines).sttNilIfEmpty
        )
    }
}

private extension String {
    nonisolated func sttIfEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }

    nonisolated var sttNilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
