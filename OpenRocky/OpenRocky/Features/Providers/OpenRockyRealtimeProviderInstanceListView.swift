//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import SwiftUI

struct OpenRockyRealtimeProviderInstanceListView: View {
    @ObservedObject var realtimeProviderStore: OpenRockyRealtimeProviderStore

    var body: some View {
        List {
            if realtimeProviderStore.instances.isEmpty {
                Section {
                    Text("No voice providers configured. Add one to get started.")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    ForEach(realtimeProviderStore.instances) { instance in
                        instanceRow(instance)
                    }
                } header: {
                    Text("Voice Providers")
                } footer: {
                    Text("Tap to activate. Only one voice provider can be active at a time.")
                }
            }

            Section {
                NavigationLink {
                    OpenRockyRealtimeProviderInstanceEditorView(
                        realtimeProviderStore: realtimeProviderStore,
                        editingInstanceID: nil
                    )
                } label: {
                    Label("Add Voice Provider", systemImage: "plus.circle")
                }
            }
        }
        .navigationTitle("Voice Providers")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func instanceRow(_ instance: OpenRockyRealtimeProviderInstance) -> some View {
        let isActive = instance.id == realtimeProviderStore.activeInstanceID

        NavigationLink {
            OpenRockyRealtimeProviderInstanceEditorView(
                realtimeProviderStore: realtimeProviderStore,
                editingInstanceID: instance.id
            )
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(instance.name)
                        .fontWeight(.medium)
                    Text(instance.kind.displayName)
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
                realtimeProviderStore.delete(id: instance.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }

            if !isActive {
                Button {
                    realtimeProviderStore.setActive(id: instance.id)
                } label: {
                    Label("Activate", systemImage: "checkmark.circle")
                }
                .tint(OpenRockyPalette.accent)
            }
        }
        .swipeActions(edge: .leading) {
            if !isActive {
                Button("Activate") {
                    realtimeProviderStore.setActive(id: instance.id)
                }
                .tint(OpenRockyPalette.accent)
            }
        }
    }
}
