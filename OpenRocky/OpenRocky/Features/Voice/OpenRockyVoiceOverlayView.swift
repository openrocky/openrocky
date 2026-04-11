//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import SwiftUI

struct OpenRockyVoiceOverlayView: View {
    @ObservedObject var sessionRuntime: OpenRockySessionRuntime
    let voiceConfiguration: OpenRockyRealtimeProviderConfiguration
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            OpenRockyPalette.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // End button - always accessible at top
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            sessionRuntime.stopVoiceSession()
                        }
                    } label: {
                        Text("End")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.red.opacity(0.85), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                Spacer()

                // Central voice area
                voiceCenter

                Spacer()

            }
        }
        .onAppear {
            if !sessionRuntime.isMicrophoneActive {
                sessionRuntime.startVoiceSession(configuration: voiceConfiguration)
            }
        }
    }

    // MARK: - Central Voice Area

    private var voiceCenter: some View {
        VStack(spacing: 20) {
            // Animated voice orb
            ZStack {
                // Outer pulse ring (when listening)
                if sessionRuntime.session.mode == .listening {
                    Circle()
                        .stroke(sessionRuntime.session.mode.tint.opacity(0.25), lineWidth: 2)
                        .frame(width: 140, height: 140)
                        .scaleEffect(1.1)
                        .opacity(0.6)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: sessionRuntime.session.mode)
                }

                // Main orb
                Button {
                    sessionRuntime.toggleVoiceSession(voiceConfiguration: voiceConfiguration)
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        sessionRuntime.session.mode.tint.opacity(0.9),
                                        sessionRuntime.session.mode.tint.opacity(0.35),
                                        OpenRockyPalette.card
                                    ],
                                    center: .center,
                                    startRadius: 15,
                                    endRadius: 60
                                )
                            )
                            .frame(width: 120, height: 120)
                            .shadow(color: sessionRuntime.session.mode.tint.opacity(0.4), radius: 30, y: 6)

                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            .frame(width: 120, height: 120)

                        Image(systemName: sessionRuntime.isMicrophoneActive ? "stop.fill" : "mic.fill")
                            .font(.system(size: 36, weight: .black))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.impact(weight: .heavy), trigger: sessionRuntime.isMicrophoneActive)
            }

            // Mode & status
            VStack(spacing: 6) {
                Text(sessionRuntime.session.mode.title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .animation(.easeInOut(duration: 0.3), value: sessionRuntime.session.mode)

                Text(sessionRuntime.statusText)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(OpenRockyPalette.muted)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 40)
            }
        }
    }

}
