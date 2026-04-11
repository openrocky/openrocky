//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import SwiftUI

struct OpenRockyDebugPanel: View {
    let preview: OpenRockyPreviewSession
    @ObservedObject var runtime: OpenRockyShellRuntime
    let providerStatus: ProviderStatus
    let voiceProviderStatus: ProviderStatus
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    sessionCard
                    systemCard
                    quickTasksCard
                }
                .padding(16)
            }
            .background(OpenRockyPalette.background.ignoresSafeArea())
            .navigationTitle("Debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Session Card

    private var sessionCard: some View {
        debugCard(title: "Session Seed", icon: "cpu", tint: OpenRockyPalette.accent) {
            VStack(alignment: .leading, spacing: 10) {
                debugRow(label: "Mode", value: preview.mode.title, tint: preview.mode.tint)
                debugRow(label: "Session", value: preview.sessionTag)
                debugRow(label: "ETA", value: preview.eta)

                RoundedRectangle(cornerRadius: 0.5)
                    .fill(OpenRockyPalette.separator)
                    .frame(height: 1)

                debugRow(label: "Chat Provider", value: "\(providerStatus.name) / \(providerStatus.model)",
                         tint: providerStatus.isConnected ? OpenRockyPalette.success : OpenRockyPalette.warning)
                debugRow(label: "Voice Provider", value: "\(voiceProviderStatus.name) / \(voiceProviderStatus.model)",
                         tint: voiceProviderStatus.isConnected ? OpenRockyPalette.success : OpenRockyPalette.warning)

                if !preview.liveTranscript.isEmpty {
                    RoundedRectangle(cornerRadius: 0.5)
                        .fill(OpenRockyPalette.separator)
                        .frame(height: 1)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("TRANSCRIPT")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .foregroundStyle(OpenRockyPalette.label)

                        Text(preview.liveTranscript)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(OpenRockyPalette.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    // MARK: - System Card

    private var systemCard: some View {
        debugCard(title: "ios_system", icon: "terminal.fill", tint: OpenRockyPalette.success) {
            if let probe = runtime.probe {
                VStack(alignment: .leading, spacing: 10) {
                    debugRow(label: "Mini-root", value: "\(probe.miniRootStatus)",
                             tint: probe.miniRootStatus == 0 ? OpenRockyPalette.success : OpenRockyPalette.warning)
                    debugRow(label: "Changed Dir", value: probe.changedDirectory ? "yes" : "no")
                    debugRow(label: "Workspace", value: probe.workspacePath)

                    ForEach(probe.commands) { command in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Text("$")
                                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                    .foregroundStyle(OpenRockyPalette.accent)

                                Text(command.command)
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white)

                                Spacer()

                                Text("exit \(command.exitCode)")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(command.exitCode == 0 ? OpenRockyPalette.success : OpenRockyPalette.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        (command.exitCode == 0 ? OpenRockyPalette.success : OpenRockyPalette.secondary).opacity(0.12),
                                        in: Capsule()
                                    )
                            }

                            if !command.output.isEmpty {
                                Text(command.output)
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundStyle(OpenRockyPalette.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .textSelection(.enabled)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(OpenRockyPalette.background.opacity(0.60), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(OpenRockyPalette.strokeSubtle, lineWidth: 1)
                        )
                    }
                }
            } else if let errorText = runtime.errorText {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(OpenRockyPalette.secondary)
                    Text(errorText)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(OpenRockyPalette.secondary)
                }
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(OpenRockyPalette.muted)
                    Text("Bootstrapping runtime...")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(OpenRockyPalette.muted)
                }
            }
        }
    }

    // MARK: - Quick Tasks Card

    private var quickTasksCard: some View {
        debugCard(title: "Quick Tasks", icon: "bolt.fill", tint: OpenRockyPalette.warning) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(preview.quickTasks) { task in
                    HStack(alignment: .center, spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(task.tint.opacity(0.12))
                                .frame(width: 28, height: 28)

                            Image(systemName: task.symbol)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(task.tint)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.title)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)

                            Text(task.prompt)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(OpenRockyPalette.muted)
                                .lineLimit(2)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Debug Card

    private func debugCard<Content: View>(title: String, icon: String, tint: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(tint)

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

    // MARK: - Debug Row

    private func debugRow(label: String, value: String, tint: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .foregroundStyle(OpenRockyPalette.label)

            HStack(spacing: 6) {
                if let tint {
                    Circle()
                        .fill(tint)
                        .frame(width: 6, height: 6)
                }
                Text(value)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
