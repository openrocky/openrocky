//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-04-06
// Copyright (c) 2026 everettjf. All rights reserved.
//

import AppIntents

struct OpenRockyIntent: AppIntent {
    nonisolated static let title: LocalizedStringResource = "Open OpenRocky"
    nonisolated static let description: IntentDescription = "Launch the OpenRocky AI assistant and start a voice session."
    nonisolated static let openAppWhenRun: Bool = true
    nonisolated static let isDiscoverable: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        UserDefaults.standard.set(true, forKey: "rocky.launch.startVoice")
        return .result(dialog: "Opening OpenRocky...")
    }
}

struct OpenRockyShortcuts: AppShortcutsProvider {
    nonisolated static var appShortcuts: [AppShortcut] {
        return [
            AppShortcut(
                intent: OpenRockyIntent(),
                phrases: [
                    "Open \(.applicationName)",
                    "Launch \(.applicationName)",
                    "Start \(.applicationName)"
                ],
                shortTitle: "Open OpenRocky",
                systemImageName: "mic.fill"
            ),
        ]
    }
}
