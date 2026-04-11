//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-04-06
// Copyright (c) 2026 everettjf. All rights reserved.
//

import SwiftUI

/// Unified entry for optional features that require special configuration.
struct OpenRockyFeaturesSettingsView: View {
    @ObservedObject var toolStore: OpenRockyBuiltInToolStore

    private var isEmailConfigured: Bool {
        guard let config = OpenRockyEmailConfig.load() else { return false }
        return config.isConfigured && config.hasPassword
    }

    var body: some View {
        List {
            Section {
                Text("Features are optional capabilities that require extra setup before they can be used.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Voice & Siri") {
                NavigationLink {
                    OpenRockySiriSettingsView()
                } label: {
                    featureRow(
                        icon: "mic.circle.fill",
                        tint: .indigo,
                        title: "Siri Shortcuts",
                        subtitle: "Launch OpenRocky with Siri voice command",
                        isConfigured: true  // Always available once app is installed
                    )
                }
            }

            Section("Communication") {
                NavigationLink {
                    OpenRockyEmailSettingsView(toolStore: toolStore)
                } label: {
                    featureRow(
                        icon: "envelope.fill",
                        tint: .blue,
                        title: "Send Email",
                        subtitle: isEmailConfigured ? emailConfiguredSubtitle : "SMTP setup required (Gmail, Outlook, QQ, etc.)",
                        isConfigured: isEmailConfigured
                    )
                }
            }
        }
        .navigationTitle("Features")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var emailConfiguredSubtitle: String {
        if let config = OpenRockyEmailConfig.load() {
            return "Ready — \(config.username)"
        }
        return "Configured"
    }

    private func featureRow(icon: String, tint: Color, title: String, subtitle: String, isConfigured: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tint.opacity(0.14))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Text(isConfigured ? "ON" : "OFF")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isConfigured ? OpenRockyPalette.success : Color.gray, in: Capsule())
                }
                Text(subtitle)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}
