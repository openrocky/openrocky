//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation

struct OpenRockyProviderConfiguration: Equatable {
    var provider: OpenRockyProviderKind
    var modelID: String
    var credential: String? = nil
    var azureResourceName: String? = nil
    var azureAPIVersion: String? = nil
    var aiProxyServiceURL: String? = nil
    var openRouterReferer: String? = nil
    var openRouterTitle: String? = nil
    var customHost: String? = nil

    nonisolated var identity: String {
        [
            provider.rawValue,
            modelID,
            credential?.isEmpty == false ? "connected" : "disconnected",
            azureResourceName ?? "-",
            azureAPIVersion ?? "-",
            aiProxyServiceURL ?? "-",
            openRouterReferer ?? "-",
            openRouterTitle ?? "-",
            customHost ?? "-"
        ].joined(separator: "|")
    }

    nonisolated var providerLabel: String {
        provider.displayName
    }

    nonisolated var isConfigured: Bool {
        switch provider {
        case .appleFoundationModels:
            modelID.isEmpty == false
        case .azureOpenAI:
            credential?.isEmpty == false &&
                azureResourceName?.isEmpty == false &&
                azureAPIVersion?.isEmpty == false &&
                modelID.isEmpty == false
        case .aiProxy:
            credential?.isEmpty == false &&
                aiProxyServiceURL?.isEmpty == false &&
                modelID.isEmpty == false
        default:
            credential?.isEmpty == false && modelID.isEmpty == false
        }
    }

    nonisolated var credentialTitle: String {
        provider == .aiProxy ? "Partial Key" : "API Key"
    }

    nonisolated var credentialPlaceholder: String {
        provider == .aiProxy ? "pk_live_..." : provider.apiKeyPlaceholder
    }

    nonisolated var maskedCredential: String {
        guard let credential, credential.count >= 8 else { return "Not connected" }
        return "\(credential.prefix(4))••••\(credential.suffix(4))"
    }

    nonisolated func normalized() -> OpenRockyProviderConfiguration {
        OpenRockyProviderConfiguration(
            provider: provider,
            modelID: modelID.trimmingCharacters(in: .whitespacesAndNewlines).ifEmpty(provider.defaultModel),
            credential: credential?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            azureResourceName: azureResourceName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            azureAPIVersion: azureAPIVersion?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nilIfEmpty ?? provider.defaultAzureAPIVersion,
            aiProxyServiceURL: aiProxyServiceURL?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            openRouterReferer: openRouterReferer?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            openRouterTitle: openRouterTitle?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            customHost: customHost?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
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
