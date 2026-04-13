//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-04-13
// Copyright (c) 2026 everettjf. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers

struct OpenRockyMountSettingsView: View {
    private var mountStore = OpenRockyMountStore.shared
    @State private var showFolderPicker = false
    @State private var pendingName = ""
    @State private var showNamePrompt = false
    @State private var pickedURL: URL?

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
                        Text("Select folders from iCloud Drive (e.g. Obsidian vault) so the AI can read and write files.")
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
                        mountRow(mount)
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
                    showFolderPicker = true
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(mountStore.mounts.count >= OpenRockyMountStore.maxMounts)
            }
        }
        .sheet(isPresented: $showFolderPicker) {
            FolderPickerView { url in
                pickedURL = url
                // Derive a default name from the folder name
                pendingName = url.lastPathComponent.lowercased()
                showNamePrompt = true
            }
        }
        .alert("Mount Name", isPresented: $showNamePrompt) {
            TextField("e.g. obsidian", text: $pendingName)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Mount") {
                if let url = pickedURL {
                    let name = pendingName.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty else { return }
                    if let mount = OpenRockyMountStore.createMount(name: name, url: url, readWrite: true) {
                        mountStore.add(mount)
                    }
                }
                pickedURL = nil
                pendingName = ""
            }
            Button("Cancel", role: .cancel) {
                pickedURL = nil
                pendingName = ""
            }
        } message: {
            Text("Enter a short name the AI will use to reference this folder.")
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
            Spacer()
            // Status indicator
            if mount.resolvedURL() != nil {
                Circle().fill(.green).frame(width: 8, height: 8)
            } else {
                Circle().fill(.red).frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Folder Picker (UIDocumentPicker wrapper)

private struct FolderPickerView: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {}
    }
}
