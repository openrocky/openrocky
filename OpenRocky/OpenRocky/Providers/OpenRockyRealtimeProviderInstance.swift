//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation

struct OpenRockyRealtimeProviderInstance: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var kind: OpenRockyRealtimeProviderKind
    var modelID: String
    var doubaoResourceID: String?
    var doubaoAppId: String?
    var doubaoAppKey: String?
    var doubaoSpeaker: String?
    var openaiVoice: String?
    var geminiVoice: String?
    var customHost: String?
    var isBuiltIn: Bool

    var credentialKeychainKey: String {
        "rocky.realtime-instance.\(id).credential"
    }

    func toConfiguration(credential: String?) -> OpenRockyRealtimeProviderConfiguration {
        OpenRockyRealtimeProviderConfiguration(
            provider: kind,
            modelID: kind.defaultModel,
            credential: credential,
            doubaoResourceID: doubaoResourceID,
            doubaoAppId: doubaoAppId,
            doubaoAppKey: doubaoAppKey,
            doubaoSpeaker: doubaoSpeaker,
            openaiVoice: openaiVoice,
            geminiVoice: geminiVoice,
            customHost: customHost
        )
    }
}
