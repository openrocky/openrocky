//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import SwiftUI

enum SessionMode: CaseIterable, Equatable {
    case listening
    case planning
    case executing
    case ready

    var title: String {
        switch self {
        case .listening: String(localized: "Listening")
        case .planning: String(localized: "Planning")
        case .executing: String(localized: "Executing")
        case .ready: String(localized: "Ready")
        }
    }

    var subtitle: String {
        switch self {
        case .listening: String(localized: "Real-time transcript is active. OpenRocky is waiting for the next intent.")
        case .planning: String(localized: "The runtime is turning speech into an explicit task graph.")
        case .executing: String(localized: "Tools are running and the visible timeline is updating.")
        case .ready: String(localized: "The session is quiet, but context is still attached.")
        }
    }

    var buttonTitle: String {
        switch self {
        case .listening: String(localized: "Tap To Pause Listening")
        case .planning: String(localized: "Tap To Start Execution")
        case .executing: String(localized: "Tap To Mark Complete")
        case .ready: String(localized: "Tap To Listen Again")
        }
    }

    var buttonSymbol: String {
        switch self {
        case .listening: "waveform.circle.fill"
        case .planning: "point.3.filled.connected.trianglepath.dotted"
        case .executing: "bolt.fill"
        case .ready: "mic.fill"
        }
    }

    var symbol: String {
        switch self {
        case .listening: "mic.fill"
        case .planning: "list.bullet.rectangle.portrait"
        case .executing: "bolt.fill"
        case .ready: "checkmark.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .listening: OpenRockyPalette.accent
        case .planning: OpenRockyPalette.warning
        case .executing: OpenRockyPalette.secondary
        case .ready: OpenRockyPalette.accent
        }
    }

    var next: SessionMode {
        switch self {
        case .listening: .planning
        case .planning: .executing
        case .executing: .ready
        case .ready: .listening
        }
    }
}
