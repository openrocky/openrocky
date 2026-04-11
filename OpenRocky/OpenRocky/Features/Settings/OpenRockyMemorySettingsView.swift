//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import SwiftUI

struct OpenRockyMemorySettingsView: View {
    @State private var entries: [OpenRockyMemoryEntry] = []
    private let memoryService = OpenRockyMemoryService.shared

    var body: some View {
        List {
            if entries.isEmpty {
                Section {
                    Text("No memories stored yet.")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 14, design: .rounded))
                }
            } else {
                Section {
                    Text("\(entries.count) memories stored")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                ForEach(entries) { entry in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(entry.key)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        Text(entry.value)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                        Text(entry.updatedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        memoryService.delete(key: entries[index].key)
                    }
                    reload()
                }
            }
        }
        .navigationTitle("Memory")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { reload() }
    }

    private func reload() {
        entries = memoryService.allEntries()
    }
}
