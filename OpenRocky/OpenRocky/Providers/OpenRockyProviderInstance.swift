//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation

struct OpenRockyProviderInstance: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var kind: OpenRockyProviderKind
    var modelID: String
    var azureResourceName: String?
    var azureAPIVersion: String?
    var aiProxyServiceURL: String?
    var openRouterReferer: String?
    var openRouterTitle: String?
    var customHost: String?
    var isBuiltIn: Bool

    var credentialKeychainKey: String {
        "rocky.provider-instance.\(id).credential"
    }

    func toConfiguration(credential: String?) -> OpenRockyProviderConfiguration {
        OpenRockyProviderConfiguration(
            provider: kind,
            modelID: modelID,
            credential: credential,
            azureResourceName: azureResourceName,
            azureAPIVersion: azureAPIVersion,
            aiProxyServiceURL: aiProxyServiceURL,
            openRouterReferer: openRouterReferer,
            openRouterTitle: openRouterTitle,
            customHost: customHost
        )
    }
}
