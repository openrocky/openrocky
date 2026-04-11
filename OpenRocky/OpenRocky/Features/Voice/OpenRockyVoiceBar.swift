//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import SwiftUI

/// Inline voice panel that covers the bottom third of the screen.
/// All voice session logic lives in OpenRockySessionRuntime — this is purely UI.
struct OpenRockyVoiceBar: View {
    @ObservedObject var sessionRuntime: OpenRockySessionRuntime
    let voiceConfiguration: OpenRockyRealtimeProviderConfiguration
    let onEnd: () -> Void

    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 0) {
            // Top edge separator
            Rectangle()
                .fill(OpenRockyPalette.stroke)
                .frame(height: 0.5)

            VStack(spacing: 16) {
                Spacer()

                // Voice orb
                ZStack {
                    // Pulse ring
                    Circle()
                        .fill(sessionRuntime.session.mode.tint.opacity(0.12))
                        .frame(width: 100, height: 100)
                        .scaleEffect(pulseScale)

                    // Main circle
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    sessionRuntime.session.mode.tint.opacity(0.9),
                                    sessionRuntime.session.mode.tint.opacity(0.35),
                                    OpenRockyPalette.card
                                ],
                                center: .center,
                                startRadius: 12,
                                endRadius: 48
                            )
                        )
                        .frame(width: 80, height: 80)
                        .shadow(color: sessionRuntime.session.mode.tint.opacity(0.4), radius: 20, y: 4)

                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        .frame(width: 80, height: 80)

                    Image(systemName: sessionRuntime.isMicrophoneActive ? "waveform" : "mic.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                }
                .sensoryFeedback(.impact(weight: .medium), trigger: sessionRuntime.session.mode)

                // Status
                VStack(spacing: 4) {
                    Text(sessionRuntime.session.mode.title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(sessionRuntime.statusText)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(OpenRockyPalette.muted)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 20)
                }

                Spacer()

                // End button
                Button(action: onEnd) {
                    Text("End Session")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 40)
                .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity)
            .containerRelativeFrame(.vertical) { height, _ in height / 3 }
            .background(
                OpenRockyPalette.background
                    .overlay(OpenRockyPalette.card.opacity(0.4))
            )
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                pulseScale = 1.12
            }
        }
    }
}
