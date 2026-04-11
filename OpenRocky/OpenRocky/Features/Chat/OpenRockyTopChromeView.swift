//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import SwiftUI

struct OpenRockyTopChromeView: View {
    let providerStatus: ProviderStatus
    var isVoiceActive: Bool = false
    let openProviderSettings: () -> Void
    let openVoiceOverlay: () -> Void
    let openConversationList: () -> Void
    let onNewConversation: () -> Void

    @State private var voicePulse: CGFloat = 1.0

    var body: some View {
        chromeContent
    }

    private var chromeContent: some View {
        HStack(alignment: .center, spacing: 12) {
            // Left cluster: menu + title
            leftCluster

            Spacer(minLength: 8)

            // Right: prominent voice button
            voiceButton
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .background(OpenRockyPalette.background)
    }

    // MARK: - Left Cluster

    private var leftCluster: some View {
        HStack(alignment: .center, spacing: 10) {
            if UIDevice.current.userInterfaceIdiom == .pad {
                Button(action: openConversationList) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(OpenRockyPalette.muted)
                        .frame(width: 36, height: 36)
                        .background(OpenRockyPalette.cardElevated, in: Circle())
                        .overlay(Circle().stroke(OpenRockyPalette.stroke, lineWidth: 1))
                        .hoverEffect(.lift)
                }
                .buttonStyle(.plain)
            }

            Button(action: openProviderSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(OpenRockyPalette.muted)
                    .frame(width: 36, height: 36)
                    .background(OpenRockyPalette.cardElevated, in: Circle())
                    .overlay(Circle().stroke(OpenRockyPalette.stroke, lineWidth: 1))
                    .hoverEffect(.lift)
            }
            .buttonStyle(.plain)

            Text("Rocky")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(OpenRockyPalette.text)
        }
    }

    // MARK: - Voice Button

    private var voiceButton: some View {
        let tint = isVoiceActive ? Color.red : OpenRockyPalette.accent
        return Button(action: openVoiceOverlay) {
            ZStack {
                // Glow ring
                Circle()
                    .fill(tint.opacity(0.12))
                    .frame(width: 52, height: 52)
                    .scaleEffect(voicePulse)

                // Main circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [tint, tint.opacity(0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .shadow(color: tint.opacity(0.35), radius: 10, y: 2)

                Image(systemName: isVoiceActive ? "stop.fill" : "waveform")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                voicePulse = 1.12
            }
        }
    }
}

struct OpenRockyTopChromeHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
