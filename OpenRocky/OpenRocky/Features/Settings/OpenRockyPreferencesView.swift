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
    @AppStorage("rocky.pref.voiceMode") private var voiceMode: String = OpenRockyVoiceMode.realtime.rawValue

    var body: some View {
        List {
            // Voice Pipeline mode selector
            Section {
                ForEach(OpenRockyVoiceMode.allCases) { mode in
                    Button {
                        voiceMode = mode.rawValue
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: voiceMode == mode.rawValue ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(voiceMode == mode.rawValue ? Color.accentColor : .secondary)
                                .font(.system(size: 20))
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Image(systemName: mode == .realtime ? "bolt.fill" : "arrow.triangle.branch")
                                        .font(.system(size: 12))
                                        .foregroundStyle(voiceMode == mode.rawValue ? Color.accentColor : .secondary)
                                    Text(mode.displayName)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                }
                                Text(mode.summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Voice Pipeline")
            } footer: {
                if voiceMode == OpenRockyVoiceMode.classic.rawValue {
                    Text("Requires Speech-to-Text, Chat, and Text-to-Speech providers to be configured.")
                } else {
                    Text("Requires a Realtime voice provider (OpenAI or GLM) to be configured.")
                }
            }

            // Voice session settings — merged into one section
            Section {
                Toggle("Voice Interruption", isOn: $preferences.voiceInterruptionEnabled)
                Toggle("Auto Greeting", isOn: $preferences.voiceAutoGreeting)
                Toggle("Show Transcript", isOn: $preferences.voiceTranscriptVisible)
                Stepper(
                    "Context Messages: \(preferences.voiceContextMessageCount)",
                    value: $preferences.voiceContextMessageCount,
                    in: 2...100,
                    step: 2
                )
            } header: {
                Text("Voice Session")
            } footer: {
                if voiceMode == OpenRockyVoiceMode.classic.rawValue {
                    Text("In Classic mode, all messages are used as context. Older messages are auto-compressed when history exceeds this threshold.")
                } else {
                    Text("Number of recent messages included as context for Realtime voice mode. More context = better memory but higher latency.")
                }
            }

            // General settings
            Section {
                Toggle("Auto-save Conversations", isOn: $preferences.chatAutoSaveConversation)
                Toggle("Haptic Feedback", isOn: $preferences.hapticFeedbackEnabled)
            } header: {
                Text("General")
            }
        }
        .navigationTitle("Preferences")
        .navigationBarTitleDisplayMode(.inline)
    }
}
