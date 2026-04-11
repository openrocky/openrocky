//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import SwiftUI

struct OpenRockySkillsSettingsView: View {
    @ObservedObject var builtInToolStore: OpenRockyBuiltInToolStore
    @StateObject private var customSkillStore = OpenRockyCustomSkillStore.shared

    var body: some View {
        List {
            Section {
                NavigationLink {
                    OpenRockyBuiltInToolsSettingsView(toolStore: builtInToolStore)
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.accentColor.opacity(0.14))
                                .frame(width: 34, height: 34)
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.accentColor)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Built-in Tools")
                                .fontWeight(.medium)
                            Text("\(builtInToolStore.enabledToolNames.count) of \(builtInToolStore.tools.count) enabled")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }

                NavigationLink {
                    OpenRockyCustomSkillsListView(skillStore: customSkillStore)
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(OpenRockyPalette.success.opacity(0.14))
                                .frame(width: 34, height: 34)
                            Image(systemName: "sparkles")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(OpenRockyPalette.success)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Custom Skills")
                                .fontWeight(.medium)
                            Text(customSkillsSummary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("Skills & Tools")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var customSkillsSummary: String {
        let count = customSkillStore.skills.count
        if count == 0 { return "Add or import custom skills" }
        let enabled = customSkillStore.skills.filter(\.isEnabled).count
        return "\(enabled) of \(count) enabled"
    }
}

// MARK: - Built-in Tools Settings

struct OpenRockyBuiltInToolsSettingsView: View {
    @ObservedObject var toolStore: OpenRockyBuiltInToolStore

    var body: some View {
        List {
            ForEach(toolStore.toolsByGroup(), id: \.group) { group in
                Section(LocalizedStringKey(group.group.rawValue)) {
                    ForEach(group.tools) { tool in
                        OpenRockyToolRowView(tool: tool, toolStore: toolStore)
                    }
                }
            }

            Section {
                HStack {
                    Text("Enabled")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(toolStore.enabledToolNames.count) of \(toolStore.tools.count) tools")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                }
            }
        }
        .navigationTitle("Built-in Tools")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Tool Row View

private struct OpenRockyToolRowView: View {
    let tool: OpenRockyBuiltInTool
    @ObservedObject var toolStore: OpenRockyBuiltInToolStore

    var body: some View {
        HStack {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(toolStore.isEnabled(tool.id) ? Color.accentColor.opacity(0.14) : Color.gray.opacity(0.1))
                        .frame(width: 34, height: 34)
                    Image(systemName: tool.icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(toolStore.isEnabled(tool.id) ? Color.accentColor : .gray)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(tool.displayName)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Text(tool.description)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 2)

            Spacer()

            Toggle("", isOn: Binding(
                get: { toolStore.isEnabled(tool.id) },
                set: { toolStore.setEnabled(tool.id, enabled: $0) }
            ))
            .labelsHidden()
        }
    }
}

// MARK: - Tool Detail View

struct OpenRockyToolDetailView: View {
    let tool: OpenRockyBuiltInTool

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.accentColor.opacity(0.14))
                            .frame(width: 48, height: 48)
                        Image(systemName: tool.icon)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Color.accentColor)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tool.displayName)
                            .font(.title3.weight(.bold))
                        Text(tool.id)
                            .font(.caption.monospaced())
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                Text(tool.description)
                    .font(.body)
            } header: {
                Text("Description")
            }

            Section {
                LabeledContent("Tool ID", value: tool.id)
                LabeledContent("Group", value: tool.group.rawValue)
            } header: {
                Text("Details")
            }
        }
        .navigationTitle(tool.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
