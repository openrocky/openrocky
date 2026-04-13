//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-04-13
// Copyright (c) 2026 everettjf. All rights reserved.
//

import SwiftUI

struct OpenRockyFeedbackView: View {
    var body: some View {
        List {
            Section {
                Link(destination: URL(string: "https://github.com/openrocky/openrocky/issues/new")!) {
                    feedbackRow(
                        icon: "exclamationmark.bubble.fill",
                        tint: .red,
                        title: "Submit Issue",
                        subtitle: "Report bugs or feature requests on GitHub"
                    )
                }

                Link(destination: URL(string: "https://t.me/openrocky")!) {
                    feedbackRow(
                        icon: "paperplane.fill",
                        tint: .blue,
                        title: "Telegram",
                        subtitle: "@openrocky"
                    )
                }

                Link(destination: URL(string: "https://discord.gg/SvvsaDA4nE")!) {
                    feedbackRow(
                        icon: "bubble.left.and.bubble.right.fill",
                        tint: .purple,
                        title: "Discord",
                        subtitle: "Join the community"
                    )
                }
            }
        }
        .navigationTitle("Feedback")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func feedbackRow(icon: String, tint: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tint.opacity(0.14))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}
