//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation

enum OpenRockyOpenAIVoice: String, CaseIterable, Identifiable {
    case alloy
    case ash
    case ballad
    case coral
    case echo
    case sage
    case shimmer
    case verse

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }

    var subtitle: String {
        switch self {
        case .alloy: String(localized: "Neutral and balanced")
        case .ash: String(localized: "Soft and thoughtful")
        case .ballad: String(localized: "Warm and engaging")
        case .coral: String(localized: "Clear and approachable")
        case .echo: String(localized: "Confident and direct")
        case .sage: String(localized: "Calm and wise")
        case .shimmer: String(localized: "Bright and optimistic")
        case .verse: String(localized: "Versatile and dynamic")
        }
    }
}
