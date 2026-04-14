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
                if voiceMode == OpenRockyVoiceMode.traditional.rawValue {
                    Text("Requires Speech-to-Text, Chat, and Text-to-Speech providers to be configured in Settings > Providers.")
                } else {
                    Text("Requires a Realtime voice provider (OpenAI or GLM) to be configured.")
                }
            }

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
