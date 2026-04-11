//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import SwiftUI
import AppIntents

@main
struct OpenRockyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    OpenRockyShortcuts.updateAppShortcutParameters()
                }
        }
    }
}
