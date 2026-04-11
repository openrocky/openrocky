//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import SwiftUI

struct OpenRockyCustomSkillsListView: View {
    @ObservedObject var skillStore: OpenRockyCustomSkillStore
    @State private var showCustomImport = false

    var body: some View {
        List {
            // Create custom
            Section {
                NavigationLink {
                    OpenRockyCustomSkillEditorView(skillStore: skillStore, editingSkillID: nil)
                } label: {
                    Label("Create Custom Skill", systemImage: "plus.circle")
                }
            }

            // Import section
            Section {
                Button {
                    showCustomImport = true
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(OpenRockyPalette.success.opacity(0.14))
                                .frame(width: 34, height: 34)
                            Image(systemName: "link")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(OpenRockyPalette.success)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Import from GitHub")
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                            Text("Import skills from a GitHub repo")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Text("Import Skills")
            }

            // Installed skills
            if !skillStore.skills.isEmpty {
                Section {
                    ForEach(skillStore.skills) { skill in
                        skillRow(skill)
                    }
                    .onDelete { indexSet in
                        let ids = indexSet.map { skillStore.skills[$0].id }
                        for id in ids { skillStore.delete(id: id) }
                    }
                } header: {
                    Text("Installed (\(skillStore.skills.count))")
                } footer: {
                    Text("\(skillStore.skills.filter(\.isEnabled).count) of \(skillStore.skills.count) enabled")
                }
            } else {
                Section {
                    Text("No custom skills installed. Create one or import from GitHub.")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            }
        }
        .navigationTitle("Skills")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCustomImport) {
            NavigationStack {
                OpenRockySkillImportView(skillStore: skillStore)
            }
        }
    }

    @ViewBuilder
    private func skillRow(_ skill: OpenRockyCustomSkill) -> some View {
        NavigationLink {
            OpenRockyCustomSkillEditorView(skillStore: skillStore, editingSkillID: skill.id)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(skill.name)
                            .fontWeight(.medium)
                        if let source = skill.sourceURL, !source.isEmpty {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if !skill.description.isEmpty {
                        Text(skill.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { skill.isEnabled },
                    set: { _ in skillStore.toggle(skill.id) }
                ))
                .labelsHidden()
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                skillStore.delete(id: skill.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }

            ShareLink(item: skillStore.exportSkill(skill)) {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .tint(.blue)
        }
    }
}
