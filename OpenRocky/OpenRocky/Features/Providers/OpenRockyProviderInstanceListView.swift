//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import SwiftUI

struct OpenRockyProviderInstanceListView: View {
    @ObservedObject var providerStore: OpenRockyProviderStore

    var body: some View {
        List {
            if providerStore.instances.isEmpty {
                Section {
                    Text("No providers configured. Add one to get started.")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    ForEach(providerStore.instances) { instance in
                        instanceRow(instance)
                    }
                } header: {
                    Text("Providers")
                } footer: {
                    Text("Tap to activate. Only one provider can be active at a time.")
                }
            }

            Section {
                NavigationLink {
                    OpenRockyProviderInstanceEditorView(
                        providerStore: providerStore,
                        editingInstanceID: nil
                    )
                } label: {
                    Label("Add Provider", systemImage: "plus.circle")
                }
            }
        }
        .navigationTitle("Chat Providers")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func instanceRow(_ instance: OpenRockyProviderInstance) -> some View {
        let isActive = instance.id == providerStore.activeInstanceID

        NavigationLink {
            OpenRockyProviderInstanceEditorView(
                providerStore: providerStore,
                editingInstanceID: instance.id
            )
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(instance.name)
                        .fontWeight(.medium)
                    Text("\(instance.kind.displayName) · \(instance.modelID)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(OpenRockyPalette.accent)
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(OpenRockyPalette.label)
                }
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                providerStore.delete(id: instance.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }

            if !isActive {
                Button {
                    providerStore.setActive(id: instance.id)
                } label: {
                    Label("Activate", systemImage: "checkmark.circle")
                }
                .tint(OpenRockyPalette.accent)
            }
        }
        .swipeActions(edge: .leading) {
            if !isActive {
                Button("Activate") {
                    providerStore.setActive(id: instance.id)
                }
                .tint(OpenRockyPalette.accent)
            }
        }
    }
}
