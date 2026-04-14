//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-04-14
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation

struct OpenRockyTTSProviderInstance: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var kind: OpenRockyTTSProviderKind
    var modelID: String
    var voice: String?
    var customHost: String?
    var isBuiltIn: Bool

    var credentialKeychainKey: String {
        "rocky.tts-instance.\(id).credential"
    }

    func toConfiguration(credential: String?) -> OpenRockyTTSProviderConfiguration {
        OpenRockyTTSProviderConfiguration(
            provider: kind,
            modelID: modelID,
            credential: credential,
            voice: voice,
            customHost: customHost
        )
    }
}
