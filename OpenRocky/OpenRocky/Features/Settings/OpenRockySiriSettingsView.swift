//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-04-06
// Copyright (c) 2026 everettjf. All rights reserved.
//

import SwiftUI
import AppIntents

struct OpenRockySiriSettingsView: View {
    @State private var shortcutsRegistered = false

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.indigo.opacity(0.14))
                            .frame(width: 48, height: 48)
                        Image(systemName: "mic.circle.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.indigo)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Siri Integration")
                            .font(.title3.weight(.bold))
                        Text(shortcutsRegistered ? "Shortcuts registered with Siri" : "Launch OpenRocky hands-free with Siri")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            // Prerequisites
            Section {
                Button {
                    openSiriSettings()
                } label: {
                    HStack {
                        Image(systemName: "exclamationmark.circle")
                            .foregroundStyle(.orange)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ensure Siri is Enabled")
                                .font(.subheadline.weight(.medium))
                            Text("Siri must be turned on in system Settings for voice shortcuts to work.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.forward.app")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(.primary)
            } header: {
                Text("Prerequisites")
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Label {
                        Text("\"Hey Siri, Open OpenRocky\"")
                            .fontWeight(.medium)
                    } icon: {
                        Image(systemName: "1.circle.fill")
                            .foregroundStyle(.indigo)
                    }
                    Label {
                        Text("OpenRocky launches and starts voice mode automatically")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "2.circle.fill")
                            .foregroundStyle(.indigo)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("How It Works")
            }

            Section {
                ForEach(phrases, id: \.self) { phrase in
                    HStack {
                        Image(systemName: "text.quote")
                            .foregroundStyle(.indigo)
                            .frame(width: 24)
                        Text(phrase)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                    }
                }
            } header: {
                Text("Supported Phrases")
            } footer: {
                Text("Say any of these phrases to Siri to launch OpenRocky with voice mode.")
            }

            Section {
                Button {
                    registerShortcuts()
                } label: {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Register Shortcuts with Siri")
                    }
                }

                Button {
                    openShortcutsApp()
                } label: {
                    HStack {
                        Image(systemName: "square.grid.2x2.fill")
                        Text("Open Shortcuts App")
                        Spacer()
                        Image(systemName: "arrow.up.forward.app")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    openSiriSettings()
                } label: {
                    HStack {
                        Image(systemName: "gear")
                        Text("Siri & Search Settings")
                        Spacer()
                        Image(systemName: "arrow.up.forward.app")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Manage")
            } footer: {
                Text("Tap \"Register\" to sync shortcuts with the system. You can also find and customize them in the Shortcuts app.")
            }
        }
        .navigationTitle("Siri Shortcuts")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            registerShortcuts()
        }
    }

    private func registerShortcuts() {
        OpenRockyShortcuts.updateAppShortcutParameters()
        shortcutsRegistered = true
    }

    private var phrases: [String] {
        [
            "\"Hey Siri, Open OpenRocky\"",
            "\"Hey Siri, Launch OpenRocky\"",
            "\"Hey Siri, Start OpenRocky\""
        ]
    }

    private func openShortcutsApp() {
        if let url = URL(string: "shortcuts://") {
            UIApplication.shared.open(url)
        }
    }

    private func openSiriSettings() {
        if let url = URL(string: "App-prefs:SIRI") {
            UIApplication.shared.open(url)
        }
    }
}
