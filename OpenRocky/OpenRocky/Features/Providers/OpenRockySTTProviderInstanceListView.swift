//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-04-14
// Copyright (c) 2026 everettjf. All rights reserved.
//

import SwiftUI

struct OpenRockySTTProviderInstanceListView: View {
    @ObservedObject var sttProviderStore: OpenRockySTTProviderStore
    var chatProviderStore: OpenRockyProviderStore? = nil
    var realtimeProviderStore: OpenRockyRealtimeProviderStore? = nil
    var ttsProviderStore: OpenRockyTTSProviderStore? = nil
    @State private var showProviderPicker = false
    @State private var selectedNewProvider: OpenRockySTTProviderKind?

    var body: some View {
        List {
            if sttProviderStore.instances.isEmpty {
                Section {
                    Text("No speech recognition providers configured. Add one to enable voice input with the traditional pipeline.")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    ForEach(sttProviderStore.instances) { instance in
                        instanceRow(instance)
                    }
                } header: {
                    Text("Speech-to-Text Providers")
                } footer: {
                    Text("Tap to activate. Only one STT provider can be active at a time.")
                }
            }

            Section {
                Button {
                    showProviderPicker = true
                } label: {
                    Label("Add STT Provider", systemImage: "plus.circle")
                }
            }
        }
        .navigationTitle("Speech-to-Text")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showProviderPicker) {
            OpenRockySTTProviderKindPickerView { kind in
                selectedNewProvider = kind
                showProviderPicker = false
            }
        }
        .navigationDestination(item: $selectedNewProvider) { kind in
            OpenRockySTTProviderInstanceEditorView(
                sttProviderStore: sttProviderStore,
                editingInstanceID: nil,
                initialProviderKind: kind,
                chatProviderStore: chatProviderStore,
                realtimeProviderStore: realtimeProviderStore,
                ttsProviderStore: ttsProviderStore
            )
        }
    }

    @ViewBuilder
    private func instanceRow(_ instance: OpenRockySTTProviderInstance) -> some View {
        let isActive = instance.id == sttProviderStore.activeInstanceID

        NavigationLink {
            OpenRockySTTProviderInstanceEditorView(
                sttProviderStore: sttProviderStore,
                editingInstanceID: instance.id,
                chatProviderStore: chatProviderStore,
                realtimeProviderStore: realtimeProviderStore,
                ttsProviderStore: ttsProviderStore
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
                sttProviderStore.delete(id: instance.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }

            if !isActive {
                Button {
                    sttProviderStore.setActive(id: instance.id)
                } label: {
                    Label("Activate", systemImage: "checkmark.circle")
                }
                .tint(OpenRockyPalette.accent)
            }
        }
        .swipeActions(edge: .leading) {
            if !isActive {
                Button("Activate") {
                    sttProviderStore.setActive(id: instance.id)
                }
                .tint(OpenRockyPalette.accent)
            }
        }
    }
}
