//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation

struct OpenRockyCharacterDefinition: Codable, Identifiable, Equatable, Sendable {
    let id: String
    var name: String
    var description: String
    var personality: String
    var greeting: String
    var speakingStyle: String
    var openaiVoice: String?
    var doubaoSpeaker: String?
    var isBuiltIn: Bool
}
