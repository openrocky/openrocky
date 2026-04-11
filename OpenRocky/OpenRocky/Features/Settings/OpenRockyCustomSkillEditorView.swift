//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import SwiftUI

struct OpenRockyCustomSkillEditorView: View {
    @ObservedObject var skillStore: OpenRockyCustomSkillStore
    @Environment(\.dismiss) private var dismiss

    let editingSkillID: String?

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var triggerConditions: String = ""
    @State private var promptContent: String = ""
    @State private var isEnabled: Bool = true

    private var isNew: Bool { editingSkillID == nil }

    var body: some View {
        List {
            Section {
                TextField("Skill Name", text: $name)
                TextField("Description (optional)", text: $description)
                TextField("Trigger conditions (optional)", text: $triggerConditions)
            } header: {
                Text("Info")
            } footer: {
                Text("Trigger describes when this skill should activate, e.g. \"when user asks to review code\".")
            }

            Section {
                Toggle("Enabled", isOn: $isEnabled)
            }

            Section {
                TextEditor(text: $promptContent)
                    .font(.system(size: 13, design: .monospaced))
                    .frame(minHeight: 250)
                    .scrollContentBackground(.hidden)
            } header: {
                Text("Prompt Content")
            } footer: {
                Text("The instructions that will be appended to the system prompt when this skill is active.")
            }
        }
        .navigationTitle(isNew ? "New Skill" : "Edit Skill")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadExisting() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    saveSkill()
                    dismiss()
                }
                .fontWeight(.bold)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func loadExisting() {
        guard let id = editingSkillID,
              let skill = skillStore.skills.first(where: { $0.id == id }) else { return }
        name = skill.name
        description = skill.description
        triggerConditions = skill.triggerConditions
        promptContent = skill.promptContent
        isEnabled = skill.isEnabled
    }

    private func saveSkill() {
        if let id = editingSkillID {
            var skill = skillStore.skills.first(where: { $0.id == id })!
            skill.name = name.trimmingCharacters(in: .whitespaces)
            skill.description = description.trimmingCharacters(in: .whitespaces)
            skill.triggerConditions = triggerConditions.trimmingCharacters(in: .whitespaces)
            skill.promptContent = promptContent
            skill.isEnabled = isEnabled
            skillStore.update(skill)
        } else {
            let skill = OpenRockyCustomSkill(
                id: UUID().uuidString,
                name: name.trimmingCharacters(in: .whitespaces),
                description: description.trimmingCharacters(in: .whitespaces),
                triggerConditions: triggerConditions.trimmingCharacters(in: .whitespaces),
                promptContent: promptContent,
                isEnabled: isEnabled,
                sourceURL: nil
            )
            skillStore.add(skill)
        }
    }
}
