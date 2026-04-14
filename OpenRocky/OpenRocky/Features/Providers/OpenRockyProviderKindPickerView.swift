//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-04-13
// Copyright (c) 2026 everettjf. All rights reserved.
//

import SwiftUI

struct OpenRockyProviderKindPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (OpenRockyProviderKind) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(OpenRockyProviderKind.allCases) { kind in
                    Button {
                        onSelect(kind)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(kind.displayName)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)
                            Text(kind.summary)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Choose Provider")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct OpenRockyRealtimeProviderKindPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (OpenRockyRealtimeProviderKind) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(OpenRockyRealtimeProviderKind.allCases) { kind in
                    Button {
                        onSelect(kind)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(kind.displayName)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)
                            Text(kind.summary)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Choose Voice Provider")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct OpenRockySTTProviderKindPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (OpenRockySTTProviderKind) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(OpenRockySTTProviderKind.allCases) { kind in
                    Button {
                        onSelect(kind)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(kind.displayName)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)
                            Text(kind.summary)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Choose STT Provider")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct OpenRockyTTSProviderKindPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (OpenRockyTTSProviderKind) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(OpenRockyTTSProviderKind.allCases) { kind in
                    Button {
                        onSelect(kind)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(kind.displayName)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)
                            Text(kind.summary)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Choose TTS Provider")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
