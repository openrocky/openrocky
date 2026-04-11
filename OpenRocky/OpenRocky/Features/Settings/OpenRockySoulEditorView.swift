//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import SwiftUI

struct OpenRockySoulEditorView: View {
    @ObservedObject var soulStore: OpenRockySoul
    @Environment(\.dismiss) private var dismiss

    let editingSoulID: String?

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var personality: String = ""

    private var isNew: Bool { editingSoulID == nil }
    private var isBuiltIn: Bool {
        guard let id = editingSoulID else { return false }
        return soulStore.souls.first(where: { $0.id == id })?.isBuiltIn ?? false
    }

    var body: some View {
        List {
            Section {
                TextField("Name", text: $name)
                TextField("Description", text: $description)
            } header: {
                Text("Info")
            }

            Section {
                TextEditor(text: $personality)
                    .font(.system(size: 13, design: .monospaced))
                    .frame(minHeight: 300)
                    .scrollContentBackground(.hidden)
            } header: {
                Text("Personality Prompt")
            } footer: {
                Text("The system prompt sent to the model. Defines behavior, tone, and tool routing.")
            }

            if isBuiltIn {
                Section {
                    Button("Reset to Default") {
                        if let builtIn = OpenRockySoul.builtInSouls.first(where: { $0.id == editingSoulID }) {
                            name = builtIn.name
                            description = builtIn.description
                            personality = builtIn.personality
                        }
                    }
                    .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(isNew ? "New Soul" : "Edit Soul")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let id = editingSoulID,
               let soul = soulStore.souls.first(where: { $0.id == id }) {
                name = soul.name
                description = soul.description
                personality = soul.personality
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    saveSoul()
                    dismiss()
                }
                .fontWeight(.bold)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || personality.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func saveSoul() {
        if let id = editingSoulID {
            var soul = soulStore.souls.first(where: { $0.id == id })!
            soul.name = name.trimmingCharacters(in: .whitespaces)
            soul.description = description.trimmingCharacters(in: .whitespaces)
            soul.personality = personality
            soulStore.update(soul)
        } else {
            let soul = OpenRockySoulDefinition(
                id: UUID().uuidString,
                name: name.trimmingCharacters(in: .whitespaces),
                description: description.trimmingCharacters(in: .whitespaces),
                personality: personality,
                isBuiltIn: false
            )
            soulStore.add(soul)
            soulStore.setActive(id: soul.id)
        }
    }
}
