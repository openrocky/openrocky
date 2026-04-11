//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import SwiftUI

struct PlanStep: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let state: StepState
}

enum StepState: Equatable {
    case done
    case active
    case queued

    var label: String {
        switch self {
        case .done: "DONE"
        case .active: "LIVE"
        case .queued: "QUEUED"
        }
    }

    var symbol: String {
        switch self {
        case .done: "checkmark"
        case .active: "bolt.fill"
        case .queued: "circle"
        }
    }

    var tint: Color {
        switch self {
        case .done: OpenRockyPalette.success
        case .active: OpenRockyPalette.secondary
        case .queued: OpenRockyPalette.muted
        }
    }
}
