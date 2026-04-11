//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import SwiftUI

struct OpenRockyCharacterSettingsView: View {
    @ObservedObject var characterStore: OpenRockyCharacterStore

    var body: some View {
        List {
            Section {
                ForEach(characterStore.characters) { character in
                    characterRow(character)
                }
                .onDelete { indexSet in
                    let ids = indexSet.compactMap { idx -> String? in
                        let character = characterStore.characters[idx]
                        return character.isBuiltIn ? nil : character.id
                    }
                    for id in ids { characterStore.delete(id: id) }
                }
            } header: {
                Text("Characters")
            } footer: {
                Text("\(characterStore.characters.count) characters total. Tap to activate, swipe to delete custom characters.")
            }

            Section {
                NavigationLink {
                    OpenRockyCharacterEditorView(characterStore: characterStore, editingCharacterID: nil)
                } label: {
                    Label("Add Custom Character", systemImage: "plus.circle")
                }
            }
        }
        .navigationTitle("Character")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func characterRow(_ character: OpenRockyCharacterDefinition) -> some View {
        NavigationLink {
            OpenRockyCharacterEditorView(characterStore: characterStore, editingCharacterID: character.id)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(character.name)
                            .fontWeight(.medium)
                        if character.isBuiltIn {
                            Text("Built-in")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(
                                    Capsule().fill(Color.secondary.opacity(0.15))
                                )
                        }
                    }
                    if !character.description.isEmpty {
                        Text(character.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if character.id == characterStore.activeCharacterID {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(OpenRockyPalette.accent)
                }
            }
        }
        .swipeActions(edge: .leading) {
            if character.id != characterStore.activeCharacterID {
                Button("Activate") {
                    characterStore.setActive(id: character.id)
                }
                .tint(OpenRockyPalette.accent)
            }
        }
        .deleteDisabled(character.isBuiltIn)
    }
}
