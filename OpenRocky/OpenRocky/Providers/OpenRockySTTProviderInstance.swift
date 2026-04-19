//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-04-14
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation

struct OpenRockySTTProviderInstance: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var kind: OpenRockySTTProviderKind
    var modelID: String
    var customHost: String?
    var language: String?
    var isBuiltIn: Bool

    var credentialKeychainKey: String {
        "rocky.stt-instance.\(id).credential"
    }

    func toConfiguration(credential: String?) -> OpenRockySTTProviderConfiguration {
        OpenRockySTTProviderConfiguration(
            provider: kind,
            modelID: modelID,
            credential: credential,
            customHost: customHost,
            language: language
        )
    }
}
