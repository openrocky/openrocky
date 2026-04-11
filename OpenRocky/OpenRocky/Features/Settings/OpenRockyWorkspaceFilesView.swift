//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import SwiftUI

struct OpenRockyWorkspaceFilesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var previewFile: PreviewableFile?
    @State private var shareItem: ShareItem?

    let rootURL: URL
    let title: String
    let showsDone: Bool

    init() {
        let path = OpenRockyShellRuntime.shared.workspacePath
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                .appendingPathComponent("OpenRockyWorkspace").path
        self.rootURL = URL(fileURLWithPath: path)
        self.title = "Workspace"
        self.showsDone = true
    }

    init(rootURL: URL, title: String, showsDone: Bool = false) {
        self.rootURL = rootURL
        self.title = title
        self.showsDone = showsDone
    }

    var body: some View {
        let content = FileBrowserContent(
            directoryURL: rootURL,
            previewFile: $previewFile,
            shareItem: $shareItem
        )

        Group {
            if showsDone {
                NavigationStack {
                    content
                        .navigationTitle(title)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") { dismiss() }
                                    .fontWeight(.bold)
                            }
                        }
                }
            } else {
                content
                    .navigationTitle(title)
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .sheet(item: $shareItem) { item in
            ActivityView(activityItems: [item.url])
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $previewFile) { file in
            OpenRockyFilePreviewView(url: file.url)
                .presentationDetents([.medium, .large])
        }
    }
}

// MARK: - File Browser Content

private struct FileBrowserContent: View {
    let directoryURL: URL
    @Binding var previewFile: PreviewableFile?
    @Binding var shareItem: ShareItem?

    @State private var entries: [FileEntry] = []

    var body: some View {
        Group {
            if entries.isEmpty {
                emptyState
            } else {
                fileList
            }
        }
        .onAppear { loadEntries() }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary)
            Text("Empty")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("No files in this directory.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var fileList: some View {
        List {
            ForEach(entries) { entry in
                if entry.isDirectory {
                    NavigationLink {
                        FileBrowserContent(
                            directoryURL: entry.url,
                            previewFile: $previewFile,
                            shareItem: $shareItem
                        )
                        .navigationTitle(entry.name)
                        .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        directoryRow(entry)
                    }
                } else {
                    fileRow(entry)
                }
            }
            .onDelete(perform: deleteEntries)
        }
        .refreshable { loadEntries() }
    }

    private func directoryRow(_ entry: FileEntry) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .font(.system(size: 22))
                .foregroundStyle(.tint)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(entry.dateText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func fileRow(_ entry: FileEntry) -> some View {
        Button {
            previewFile = PreviewableFile(url: entry.url)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: entry.icon)
                    .font(.system(size: 22))
                    .foregroundStyle(.tint)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(entry.sizeText)
                        Text(entry.dateText)
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    shareItem = ShareItem(url: entry.url)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16))
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func loadEntries() {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            entries = []
            return
        }

        var loaded: [FileEntry] = []
        for url in contents {
            guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]) else { continue }
            loaded.append(FileEntry(
                name: url.lastPathComponent,
                url: url,
                isDirectory: values.isDirectory ?? false,
                size: values.fileSize ?? 0,
                modified: values.contentModificationDate ?? Date.distantPast
            ))
        }

        // Directories first, then files, both sorted by modification time
        let dirs = loaded.filter(\.isDirectory).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let files = loaded.filter { !$0.isDirectory }.sorted { $0.modified > $1.modified }
        entries = dirs + files
    }

    private func deleteEntries(at offsets: IndexSet) {
        let fm = FileManager.default
        for index in offsets {
            try? fm.removeItem(at: entries[index].url)
        }
        entries.remove(atOffsets: offsets)
    }
}

// MARK: - Models

private struct FileEntry: Identifiable {
    let name: String
    let url: URL
    let isDirectory: Bool
    let size: Int
    let modified: Date

    var id: String { url.path }

    var sizeText: String {
        ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }

    var dateText: String {
        modified.formatted(.relative(presentation: .named))
    }

    var icon: String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "md", "txt", "log": return "doc.text"
        case "json": return "curlybraces"
        case "py": return "chevron.left.forwardslash.chevron.right"
        case "swift", "js", "ts", "html", "css": return "chevron.left.forwardslash.chevron.right"
        case "png", "jpg", "jpeg", "gif", "webp", "heic": return "photo"
        case "pdf": return "doc.richtext"
        case "csv": return "tablecells"
        case "mp3", "wav", "m4a": return "waveform"
        case "mp4", "mov": return "film"
        case "zip", "tar", "gz": return "doc.zipper"
        case "db", "sqlite": return "cylinder"
        case "plist": return "list.bullet.rectangle"
        default: return "doc"
        }
    }
}

struct PreviewableFile: Identifiable {
    let url: URL
    var id: String { url.path }
}

struct ShareItem: Identifiable {
    let url: URL
    var id: String { url.path }
}

// MARK: - UIActivityViewController wrapper

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
