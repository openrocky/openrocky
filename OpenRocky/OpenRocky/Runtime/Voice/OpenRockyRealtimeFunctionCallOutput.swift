//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation
@preconcurrency import SwiftOpenAI

@RealtimeActor
struct OpenRockyRealtimeFunctionCallOutput: Encodable {
    let type = "conversation.item.create"
    let item: Item

    init(callID: String, output: String) {
        item = Item(callID: callID, output: output)
    }

    struct Item: Encodable {
        let type = "function_call_output"
        let callID: String
        let output: String

        enum CodingKeys: String, CodingKey {
            case type
            case callID = "call_id"
            case output
        }
    }
}
