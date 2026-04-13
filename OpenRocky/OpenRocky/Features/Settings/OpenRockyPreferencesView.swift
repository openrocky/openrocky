//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-04-13
// Copyright (c) 2026 everettjf. All rights reserved.
//

import SwiftUI

struct OpenRockyPreferencesView: View {
    @Bindable private var preferences = OpenRockyPreferences.shared

    var body: some View {
        List {
            Section {
                Toggle("Voice Interruption", isOn: $preferences.voiceInterruptionEnabled)
                if preferences.voiceInterruptionEnabled {
                    Text("When enabled, speaking while the assistant is talking will interrupt playback.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Voice")
            } footer: {
                Text("Configure voice session behavior.")
            }

            Section {
                Toggle("Auto Greeting", isOn: $preferences.voiceAutoGreeting)
                Toggle("Show Transcript", isOn: $preferences.voiceTranscriptVisible)
            } header: {
                Text("Voice Session")
            }

            Section {
                Toggle("Auto-save Conversations", isOn: $preferences.chatAutoSaveConversation)
            } header: {
                Text("Chat")
            }

            Section {
                Toggle("Haptic Feedback", isOn: $preferences.hapticFeedbackEnabled)
            } header: {
                Text("General")
            }
        }
        .navigationTitle("Preferences")
        .navigationBarTitleDisplayMode(.inline)
    }
}
