//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-04-14
// Copyright (c) 2026 everettjf. All rights reserved.
//

import SwiftUI

struct OpenRockyTTSProviderInstanceListView: View {
    @ObservedObject var ttsProviderStore: OpenRockyTTSProviderStore
    var chatProviderStore: OpenRockyProviderStore? = nil
    var realtimeProviderStore: OpenRockyRealtimeProviderStore? = nil
    var sttProviderStore: OpenRockySTTProviderStore? = nil
    @State private var showProviderPicker = false
    @State private var selectedNewProvider: OpenRockyTTSProviderKind?

    var body: some View {
        List {
            if ttsProviderStore.instances.isEmpty {
                Section {
                    Text("No text-to-speech providers configured. Add one to enable voice output with the traditional pipeline.")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    ForEach(ttsProviderStore.instances) { instance in
                        instanceRow(instance)
                    }
                } header: {
                    Text("Text-to-Speech Providers")
                } footer: {
                    Text("Tap to activate. Only one TTS provider can be active at a time.")
                }
            }

            Section {
                Button {
                    showProviderPicker = true
                } label: {
                    Label("Add TTS Provider", systemImage: "plus.circle")
                }
            }
        }
        .navigationTitle("Text-to-Speech")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showProviderPicker) {
            OpenRockyTTSProviderKindPickerView { kind in
                selectedNewProvider = kind
                showProviderPicker = false
            }
        }
        .navigationDestination(item: $selectedNewProvider) { kind in
            OpenRockyTTSProviderInstanceEditorView(
                ttsProviderStore: ttsProviderStore,
                editingInstanceID: nil,
                initialProviderKind: kind,
                chatProviderStore: chatProviderStore,
                realtimeProviderStore: realtimeProviderStore,
                sttProviderStore: sttProviderStore
            )
        }
    }

    @ViewBuilder
    private func instanceRow(_ instance: OpenRockyTTSProviderInstance) -> some View {
        let isActive = instance.id == ttsProviderStore.activeInstanceID

        NavigationLink {
            OpenRockyTTSProviderInstanceEditorView(
                ttsProviderStore: ttsProviderStore,
                editingInstanceID: instance.id,
                chatProviderStore: chatProviderStore,
                realtimeProviderStore: realtimeProviderStore,
                sttProviderStore: sttProviderStore
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
                ttsProviderStore.delete(id: instance.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }

            if !isActive {
                Button {
                    ttsProviderStore.setActive(id: instance.id)
                } label: {
                    Label("Activate", systemImage: "checkmark.circle")
                }
                .tint(OpenRockyPalette.accent)
            }
        }
        .swipeActions(edge: .leading) {
            if !isActive {
                Button("Activate") {
                    ttsProviderStore.setActive(id: instance.id)
                }
                .tint(OpenRockyPalette.accent)
            }
        }
    }
}
