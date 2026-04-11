//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import SwiftUI

struct OpenRockyHomeScreen: View {
    let preview: OpenRockyPreviewSession
    let topInset: CGFloat
    @Binding var draftText: String
    let isRuntimeReady: Bool
    let runtimeErrorText: String?
    let isVoiceSessionActive: Bool
    let openConversationDetails: () -> Void
    let submitText: () -> Void
    let toggleVoiceSession: () -> Void
    let selectQuickTask: (QuickTask) -> Void

    private let quickTaskColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    heroCard
                    transcriptCard
                    planCard
                    timelineCard
                    quickTasksCard
                }
                .padding(.horizontal, 16)
                .padding(.top, topInset + 20)
                .padding(.bottom, 140)
            }

            composerBar
        }
        .background(OpenRockyPalette.background.ignoresSafeArea())
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    statusPill

                    Text(preview.mode.title)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text(preview.mode.subtitle)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(OpenRockyPalette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 16)

                Button(action: openConversationDetails) {
                    Label("Details", systemImage: "text.bubble")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(OpenRockyPalette.background.opacity(0.44), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 16) {
                voiceButton

                VStack(alignment: .leading, spacing: 8) {
                    metricRow(label: "Session", value: preview.sessionTag)
                    metricRow(label: "ETA", value: preview.eta)
                    metricRow(label: "Input", value: isVoiceSessionActive ? "Voice live" : "Text fallback")
                    metricRow(label: "Plan", value: "\(preview.completedCount)/\(preview.plan.count) steps")
                    runtimeRow
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [OpenRockyPalette.cardElevated, OpenRockyPalette.card],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(OpenRockyPalette.stroke, lineWidth: 1)
        )
        .shadow(color: OpenRockyPalette.shadow.opacity(0.20), radius: 24, y: 8)
    }

    private var voiceButton: some View {
        Button(action: toggleVoiceSession) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                preview.mode.tint.opacity(0.95),
                                preview.mode.tint.opacity(0.45),
                                OpenRockyPalette.cardElevated
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 64
                        )
                    )
                    .frame(width: 104, height: 104)
                    .shadow(color: preview.mode.tint.opacity(0.35), radius: 16, y: 4)

                Circle()
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    .frame(width: 104, height: 104)

                Image(systemName: isVoiceSessionActive ? "stop.fill" : preview.mode.symbol)
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .heavy), trigger: isVoiceSessionActive)
    }

    // MARK: - Transcript Card

    private var transcriptCard: some View {
        contentCard(
            title: "Live Transcript",
            icon: "waveform.badge.mic"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                transcriptRow(label: "YOU", text: preview.liveTranscript, tint: OpenRockyPalette.accent)

                RoundedRectangle(cornerRadius: 0.5)
                    .fill(OpenRockyPalette.separator)
                    .frame(height: 1)

                transcriptRow(label: "ROCKY", text: preview.assistantReply, tint: OpenRockyPalette.accent)
            }
        }
    }

    private func transcriptRow(label: String, text: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .foregroundStyle(tint)

            Text(text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(OpenRockyPalette.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Plan Card

    private var planCard: some View {
        contentCard(
            title: "Current Plan",
            icon: "list.bullet.rectangle.portrait"
        ) {
            VStack(spacing: 0) {
                ForEach(Array(preview.plan.prefix(4).enumerated()), id: \.element.id) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 0) {
                            ZStack {
                                Circle()
                                    .fill(step.state.tint.opacity(0.18))
                                    .frame(width: 24, height: 24)

                                Image(systemName: step.state.symbol)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(step.state.tint)
                            }

                            if index < min(preview.plan.count, 4) - 1 {
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(OpenRockyPalette.strokeSubtle)
                                    .frame(width: 2)
                                    .frame(maxHeight: .infinity)
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(step.title)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)

                                Spacer(minLength: 8)

                                Text(step.state.label)
                                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                    .foregroundStyle(step.state.tint)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(step.state.tint.opacity(0.12), in: Capsule())
                            }

                            Text(step.detail)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(OpenRockyPalette.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.bottom, index < min(preview.plan.count, 4) - 1 ? 14 : 0)
                    }
                }
            }
        }
    }

    // MARK: - Timeline Card

    private var timelineCard: some View {
        contentCard(
            title: "Recent Timeline",
            icon: "clock.arrow.trianglehead.counterclockwise.rotate.90"
        ) {
            VStack(spacing: 10) {
                ForEach(Array(preview.timeline.suffix(4))) { entry in
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(entry.kind.tint.opacity(0.12))
                                .frame(width: 28, height: 28)

                            Image(systemName: entry.kind.symbol)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(entry.kind.tint)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(entry.kind.title)
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)

                                Spacer(minLength: 8)

                                Text(entry.time)
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundStyle(OpenRockyPalette.label)
                            }

                            Text(entry.text)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(OpenRockyPalette.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Quick Tasks Card

    private var quickTasksCard: some View {
        contentCard(
            title: "Quick Starts",
            icon: "bolt.fill"
        ) {
            LazyVGrid(columns: quickTaskColumns, spacing: 12) {
                ForEach(preview.quickTasks) { task in
                    Button(action: { selectQuickTask(task) }) {
                        VStack(alignment: .leading, spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(task.tint.opacity(0.14))
                                    .frame(width: 34, height: 34)

                                Image(systemName: task.symbol)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(task.tint)
                            }

                            Text(task.title)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text(task.prompt)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(OpenRockyPalette.muted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineLimit(3)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
                        .background(
                            LinearGradient(
                                colors: [task.tint.opacity(0.08), task.tint.opacity(0.04)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(task.tint.opacity(0.18), lineWidth: 1)
                        )
                    }
                    .buttonStyle(QuickTaskButtonStyle())
                }
            }
        }
    }

    // MARK: - Composer Bar

    private var composerBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(OpenRockyPalette.separator)
                .frame(height: 0.5)

            HStack(spacing: 12) {
                TextField("Type a request...", text: $draftText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1...4)
                    .tint(OpenRockyPalette.accent)

                Button(action: submitText) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? OpenRockyPalette.muted : OpenRockyPalette.accent)
                }
                .buttonStyle(.plain)
                .disabled(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(
            .ultraThinMaterial,
            in: Rectangle()
        )
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Supporting Views

    private var statusPill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isVoiceSessionActive ? OpenRockyPalette.accent : preview.mode.tint)
                .frame(width: 7, height: 7)

            Text(isVoiceSessionActive ? "VOICE LIVE" : "VOICE FIRST")
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white.opacity(0.80))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(OpenRockyPalette.background.opacity(0.48), in: Capsule())
    }

    private var runtimeRow: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(runtimeTint)
                .frame(width: 6, height: 6)

            Text(runtimeSummary)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(OpenRockyPalette.muted)
                .lineLimit(2)
        }
    }

    private var runtimeSummary: String {
        if let runtimeErrorText, !runtimeErrorText.isEmpty {
            return runtimeErrorText
        }
        return isRuntimeReady ? "Local runtime ready" : "Bootstrapping..."
    }

    private var runtimeTint: Color {
        if runtimeErrorText != nil {
            return OpenRockyPalette.secondary
        }
        return isRuntimeReady ? OpenRockyPalette.accent : OpenRockyPalette.warning
    }

    private func metricRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .foregroundStyle(OpenRockyPalette.label)

            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Reusable Card

    private func contentCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(OpenRockyPalette.accent)

                Text(title)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }

            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [OpenRockyPalette.card, OpenRockyPalette.cardElevated],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(OpenRockyPalette.stroke, lineWidth: 1)
        )
    }
}

// MARK: - Quick Task Button Style

private struct QuickTaskButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}
