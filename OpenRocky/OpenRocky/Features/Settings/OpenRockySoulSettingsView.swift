//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import SwiftUI

struct OpenRockySoulSettingsView: View {
    @ObservedObject var soulStore: OpenRockySoul

    var body: some View {
        List {
            Section {
                ForEach(soulStore.souls) { soul in
                    soulRow(soul)
                }
                .onDelete { indexSet in
                    let ids = indexSet.compactMap { idx -> String? in
                        let soul = soulStore.souls[idx]
                        return soul.isBuiltIn ? nil : soul.id
                    }
                    for id in ids { soulStore.delete(id: id) }
                }
            } header: {
                Text("Souls")
            } footer: {
                Text("\(soulStore.souls.count) souls total. Tap to activate, swipe to delete custom souls.")
            }

            Section {
                NavigationLink {
                    OpenRockySoulEditorView(soulStore: soulStore, editingSoulID: nil)
                } label: {
                    Label("Add Custom Soul", systemImage: "plus.circle")
                }
            }
        }
        .navigationTitle("Soul")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func soulRow(_ soul: OpenRockySoulDefinition) -> some View {
        NavigationLink {
            OpenRockySoulEditorView(soulStore: soulStore, editingSoulID: soul.id)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(soul.name)
                            .fontWeight(.medium)
                        if soul.isBuiltIn {
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
                    if !soul.description.isEmpty {
                        Text(soul.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if soul.id == soulStore.activeSoulID {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(OpenRockyPalette.accent)
                }
            }
        }
        .swipeActions(edge: .leading) {
            if soul.id != soulStore.activeSoulID {
                Button("Activate") {
                    soulStore.setActive(id: soul.id)
                }
                .tint(OpenRockyPalette.accent)
            }
        }
        .deleteDisabled(soul.isBuiltIn)
    }
}
