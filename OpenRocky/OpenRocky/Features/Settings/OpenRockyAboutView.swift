//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import SwiftUI

struct OpenRockyAboutView: View {
    @ObservedObject var providerStore: OpenRockyProviderStore
    @ObservedObject var realtimeProviderStore: OpenRockyRealtimeProviderStore
    @State private var showsOnboarding = false

    var body: some View {
        List {
            // App intro
            Section {
                VStack(spacing: 12) {
                    Text("OpenRocky")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("An open-source AI assistant for iOS/iPadOS.\nVoice conversation, tool calling, and more.")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                       let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                        Text("v\(version) (\(build))")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }

            // Links
            Section("Links") {
                linkRow(icon: "globe", tint: .cyan, title: "Official Website", url: "https://openrocky.org")
                linkRow(icon: "star.fill", tint: .yellow, title: "GitHub", subtitle: "Star us on GitHub!", url: "https://github.com/openrocky/openrocky")
                linkRow(icon: "person.fill", tint: .orange, title: "Author (@everettjf)", url: "https://x.com/everettjf")
            }

            // Community
            Section("Community") {
                linkRow(icon: "paperplane.fill", tint: .blue, title: "Telegram", subtitle: "@openrocky", url: "https://t.me/openrocky")
                linkRow(icon: "bubble.left.and.bubble.right.fill", tint: .purple, title: "Discord", url: "https://discord.gg/SvvsaDA4nE")
            }

            // Feedback
            Section("Feedback") {
                linkRow(icon: "exclamationmark.bubble.fill", tint: .red, title: "Feedback", subtitle: "Report issues or suggestions", url: "https://github.com/openrocky/openrocky/issues/new")

                Button {
                    showsOnboarding = true
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.purple.opacity(0.14))
                                .frame(width: 32, height: 32)
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.purple)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Setup Wizard")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary)
                            Text("Configure unified chat + voice provider")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
            }

            // Open source libraries
            Section("Open Source Libraries") {
                libraryRow(name: "LanguageModelChatUI", author: "Lakr233", url: "https://github.com/Lakr233/LanguageModelChatUI")
                libraryRow(name: "MarkdownView", author: "Lakr233", url: "https://github.com/Lakr233/MarkdownView")
libraryRow(name: "SwiftOpenAI", author: "jamesrochabrun", url: "https://github.com/jamesrochabrun/SwiftOpenAI")
                libraryRow(name: "ios_system", author: "holzschu", url: "https://github.com/holzschu/ios_system")
                libraryRow(name: "Python-Apple-support", author: "beeware", url: "https://github.com/beeware/Python-Apple-support")
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showsOnboarding) {
            OpenRockyOnboardingView(
                providerStore: providerStore,
                realtimeProviderStore: realtimeProviderStore
            )
        }
    }

    private func linkRow(icon: String, tint: Color = .cyan, title: String, subtitle: String? = nil, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(tint.opacity(0.14))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(tint)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 2)
        }
    }

    private func libraryRow(name: String, author: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(author)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 2)
        }
    }
}
