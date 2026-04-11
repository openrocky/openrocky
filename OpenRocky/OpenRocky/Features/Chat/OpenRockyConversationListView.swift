//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import SwiftUI

/// Reusable conversation list content used both in the sheet (iPhone) and sidebar (iPad).
struct OpenRockyConversationListContent: View {
    let conversations: [OpenRockyConversationMeta]
    let currentID: String?
    let onSelect: (String) -> Void
    let onNew: () -> Void
    let onDelete: (String) -> Void

    var body: some View {
        List {
            ForEach(conversations) { meta in
                Button {
                    onSelect(meta.id)
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(meta.id == currentID ? OpenRockyPalette.accent : OpenRockyPalette.muted.opacity(0.3))
                            .frame(width: 8, height: 8)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(meta.displayTitle)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(OpenRockyPalette.text)
                                .lineLimit(1)

                            Text(meta.displayDate)
                                .font(.system(size: 12))
                                .foregroundStyle(OpenRockyPalette.muted)
                        }

                        Spacer()

                        if meta.id == currentID {
                            Text("Active")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(OpenRockyPalette.accent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(OpenRockyPalette.accent.opacity(0.15), in: Capsule())
                        }
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .hoverEffect(.highlight)
                }
                .listRowBackground(OpenRockyPalette.card)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if meta.id != currentID {
                        Button(role: .destructive) {
                            onDelete(meta.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(OpenRockyPalette.background)
    }
}

struct OpenRockyConversationListView: View {
    let conversations: [OpenRockyConversationMeta]
    let currentID: String?
    let onSelect: (String) -> Void
    let onNew: () -> Void
    let onDelete: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            OpenRockyConversationListContent(
                conversations: conversations,
                currentID: currentID,
                onSelect: { id in
                    onSelect(id)
                    dismiss()
                },
                onNew: onNew,
                onDelete: onDelete
            )
            .navigationTitle("Conversations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(OpenRockyPalette.muted)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onNew()
                        dismiss()
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .foregroundStyle(OpenRockyPalette.accent)
                    }
                }
            }
            .toolbarBackground(OpenRockyPalette.background, for: .navigationBar)
        }
    }
}
