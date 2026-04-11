//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import SwiftUI

struct TimelineEntry: Identifiable {
    let id = UUID()
    let kind: TimelineKind
    let time: String
    let text: String
}

enum TimelineKind {
    case speech
    case system
    case tool
    case result

    var title: String {
        switch self {
        case .speech: "Speech Input"
        case .system: "Runtime Update"
        case .tool: "Tool Call"
        case .result: "Agent Reply"
        }
    }

    var symbol: String {
        switch self {
        case .speech: "waveform"
        case .system: "cpu"
        case .tool: "wrench.and.screwdriver.fill"
        case .result: "sparkles"
        }
    }

    var tint: Color {
        switch self {
        case .speech: OpenRockyPalette.accent
        case .system: OpenRockyPalette.warning
        case .tool: OpenRockyPalette.secondary
        case .result: OpenRockyPalette.success
        }
    }
}
