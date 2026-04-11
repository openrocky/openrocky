//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation

enum OpenRockyGeminiVoice: String, CaseIterable, Identifiable {
    case puck = "Puck"
    case charon = "Charon"
    case kore = "Kore"
    case fenrir = "Fenrir"
    case aoede = "Aoede"
    case orus = "Orus"
    case zephyr = "Zephyr"
    case leda = "Leda"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var subtitle: String {
        switch self {
        case .puck: String(localized: "Upbeat, conversational")
        case .charon: String(localized: "Deep, authoritative")
        case .kore: String(localized: "Firm, professional")
        case .fenrir: String(localized: "Warm, approachable")
        case .aoede: String(localized: "Bright")
        case .orus: String(localized: "Firm")
        case .zephyr: String(localized: "Bright")
        case .leda: String(localized: "Gentle")
        }
    }
}
