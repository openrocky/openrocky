//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-04-13
// Copyright (c) 2026 everettjf. All rights reserved.
//

import SwiftUI

struct OpenRockyMountSettingsView: View {
    private var mountStore = OpenRockyMountStore.shared
    @State private var showAddSheet = false

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "externaldrive.fill.badge.icloud")
                        .font(.system(size: 24))
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mount External Folders")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                        Text("Mount iCloud Drive folders so the AI can read and write files. Supports Obsidian vaults and other iCloud apps.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                if mountStore.mounts.isEmpty {
                    Text("No folders mounted. Tap + to add one.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(mountStore.mounts) { mount in
                        NavigationLink {
                            OpenRockyMountEditorView(editingMount: mount)
                        } label: {
                            mountRow(mount)
                        }
                    }
                    .onDelete { indices in
                        for index in indices {
                            mountStore.delete(id: mountStore.mounts[index].id)
                        }
                    }
                }
            } header: {
                Text("Mounted Folders \(mountStore.mounts.count) / \(OpenRockyMountStore.maxMounts)")
            }
        }
        .navigationTitle("External Folders")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(mountStore.mounts.count >= OpenRockyMountStore.maxMounts)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            NavigationStack {
                OpenRockyMountEditorView(editingMount: nil)
            }
        }
    }

    private func mountRow(_ mount: OpenRockyMount) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .font(.system(size: 20))
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(mount.name)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Text(mount.readWrite ? "Read/Write" : "Read Only")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(mount.readWrite ? Color.green : Color.orange, in: Capsule())
                }
                Text(mount.displayPath)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

struct OpenRockyMountEditorView: View {
    let editingMount: OpenRockyMount?

    init(editingMount: OpenRockyMount?) {
        self.editingMount = editingMount
    }

    @Environment(\.dismiss) private var dismiss

    private var mountStore = OpenRockyMountStore.shared
    @State private var name: String = ""
    @State private var containerIdentifier: String = ""
    @State private var subpath: String = ""
    @State private var readWrite: Bool = true

    private var isNew: Bool { editingMount == nil }

    private let presets: [(String, String)] = [
        ("Obsidian", "iCloud~md~obsidian"),
        ("iA Writer", "iCloud~com~iawriter~iAWriter"),
        ("Textastic", "iCloud~com~textasticapp~textastic"),
        ("Working Copy", "iCloud~com~workingcopyapp~workingcopy"),
    ]

    var body: some View {
        List {
            Section {
                TextField("Mount name (e.g. obsidian)", text: $name)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("Name")
            } footer: {
                Text("A short name the AI will use to reference this folder.")
            }

            Section {
                TextField("iCloud~md~obsidian", text: $containerIdentifier)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 14, design: .monospaced))

                ForEach(presets, id: \.0) { preset in
                    Button {
                        containerIdentifier = preset.1
                        if name.isEmpty { name = preset.0.lowercased() }
                    } label: {
                        HStack {
                            Text(preset.0)
                                .foregroundStyle(.primary)
                            Spacer()
                            if containerIdentifier == preset.1 {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            } header: {
                Text("iCloud Container")
            } footer: {
                Text("The iCloud container identifier. Pick a preset or enter a custom one.")
            }

            Section {
                TextField("/ (root)", text: $subpath)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 14, design: .monospaced))
            } header: {
                Text("Subpath (Optional)")
            } footer: {
                Text("Subfolder within the container's Documents directory. Leave empty for root.")
            }

            Section {
                Toggle("Read & Write", isOn: $readWrite)
            } header: {
                Text("Permissions")
            }

            if let mount = editingMount {
                Section {
                    let url = mount.resolvedURL
                    HStack {
                        Text("Status")
                        Spacer()
                        if url != nil {
                            HStack(spacing: 4) {
                                Circle().fill(.green).frame(width: 8, height: 8)
                                Text("Available")
                            }
                            .foregroundStyle(.green)
                        } else {
                            HStack(spacing: 4) {
                                Circle().fill(.red).frame(width: 8, height: 8)
                                Text("Not Found")
                            }
                            .foregroundStyle(.red)
                        }
                    }
                    .font(.system(size: 14, weight: .medium))
                }
            }
        }
        .navigationTitle(isNew ? "Add Mount" : "Edit Mount")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let mount = editingMount {
                name = mount.name
                containerIdentifier = mount.containerIdentifier
                subpath = mount.subpath
                readWrite = mount.readWrite
            }
        }
        .toolbar {
            if isNew {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    saveMount()
                    dismiss()
                }
                .fontWeight(.bold)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || containerIdentifier.trimmingCharacters(in: .whitespaces).isEmpty || !hasValidSubpath)
            }
        }
    }

    private var hasValidSubpath: Bool {
        let trimmed = subpath.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed == "/" { return true }
        return !trimmed.contains("..") && !trimmed.contains("//")
    }

    private func saveMount() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedContainer = containerIdentifier.trimmingCharacters(in: .whitespaces)
        let trimmedSubpath = subpath.trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        if let existing = editingMount {
            var updated = existing
            updated.name = trimmedName
            updated.containerIdentifier = trimmedContainer
            updated.subpath = trimmedSubpath
            updated.readWrite = readWrite
            mountStore.update(updated)
        } else {
            let mount = OpenRockyMount(
                id: UUID().uuidString,
                name: trimmedName,
                containerIdentifier: trimmedContainer,
                subpath: trimmedSubpath,
                readWrite: readWrite
            )
            mountStore.add(mount)
        }
    }
}
