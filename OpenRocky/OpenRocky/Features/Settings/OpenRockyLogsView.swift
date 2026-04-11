//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Combine
import SwiftUI
import UIKit

// MARK: - Page 1: Session List

struct OpenRockyLogsView: View {
    @State private var files: [OpenRockyLogFile] = []
    @State private var showClearAlert = false

    private let logManager = OpenRockyLogManager.shared

    var body: some View {
        Group {
            if files.isEmpty {
                ContentUnavailableView {
                    Label("No Logs", systemImage: "doc.text.magnifyingglass")
                } description: {
                    Text("Runtime logs will appear here as the app runs.\nOne file per launch, kept for 7 days.")
                }
            } else {
                List {
                    Section {
                        ForEach(files.reversed()) { file in
                            NavigationLink {
                                OpenRockyLogFileView(file: file)
                            } label: {
                                fileRow(file)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    logManager.deleteFile(file)
                                    refreshFiles()
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    } header: {
                        HStack {
                            Text("\(files.count) sessions")
                            Spacer()
                            Text(formatSize(logManager.totalLogSize))
                        }
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Logs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    showClearAlert = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .alert("Clear All Logs?", isPresented: $showClearAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                logManager.clear()
                refreshFiles()
            }
        } message: {
            Text("This will delete all log files.")
        }
        .task { refreshFiles() }
    }

    private func refreshFiles() {
        files = logManager.logFiles()
    }

    private func fileRow(_ file: OpenRockyLogFile) -> some View {
        HStack(spacing: 12) {
            Image(systemName: file.isSegment ? "doc.badge.clock" : "doc.text.fill")
                .font(.system(size: 16))
                .foregroundStyle(file.isSegment ? .orange : .cyan)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(file.displayName)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                    if !file.sessionLabel.isEmpty {
                        Text(file.sessionLabel)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                file.sessionLabel.contains("Current") ? Color.green.opacity(0.7) : Color.blue.opacity(0.5),
                                in: Capsule()
                            )
                    }
                }
                Text(file.sizeText)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }

    private func formatSize(_ bytes: Int64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
    }
}

// MARK: - Page 2: Log Entries in a File

struct OpenRockyLogFileView: View {
    let file: OpenRockyLogFile

    @State private var entries: [OpenRockyLogEntry] = []
    @State private var selectedLevel: OpenRockyLogLevel?
    @State private var showShareSheet = false
    @State private var shareURL: URL?
    @State private var copiedID: UUID?

    private let logManager = OpenRockyLogManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Filter bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip(title: "All (\(entries.count))", isSelected: selectedLevel == nil) {
                        selectedLevel = nil
                    }
                    ForEach(OpenRockyLogLevel.allCases, id: \.self) { level in
                        let count = entries.filter { $0.level == level }.count
                        if count > 0 {
                            filterChip(
                                title: "\(level.emoji) \(count)",
                                isSelected: selectedLevel == level
                            ) {
                                selectedLevel = level
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(.ultraThinMaterial)

            Divider()

            if filteredEntries.isEmpty {
                ContentUnavailableView("No Entries", systemImage: "doc.text")
            } else {
                List {
                    ForEach(filteredEntries) { entry in
                        NavigationLink {
                            OpenRockyLogDetailView(entry: entry)
                        } label: {
                            logRow(entry)
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                        .swipeActions(edge: .trailing) {
                            Button {
                                copyEntry(entry)
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                            .tint(.cyan)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(file.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        shareFile()
                    } label: {
                        Label("Share This File", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        copyAll()
                    } label: {
                        Label("Copy All Text", systemImage: "doc.on.doc")
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = shareURL {
                OpenRockyShareSheet(activityItems: [url])
            }
        }
        .task {
            entries = logManager.entries(for: file)
        }
    }

    private var filteredEntries: [OpenRockyLogEntry] {
        if let level = selectedLevel {
            return entries.filter { $0.level == level }
        }
        return entries
    }

    private func shareFile() {
        if let url = logManager.exportSingleFileURL(file) {
            shareURL = url
            showShareSheet = true
        }
    }

    private func copyAll() {
        if let content = try? String(contentsOf: file.url, encoding: .utf8) {
            UIPasteboard.general.string = content
        }
    }

    private func copyEntry(_ entry: OpenRockyLogEntry) {
        let text = "[\(formatDate(entry.date))] [\(entry.level.rawValue)] [\(entry.category)] \(entry.message)"
        UIPasteboard.general.string = text
        copiedID = entry.id
    }

    private func logRow(_ entry: OpenRockyLogEntry) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(entry.level.emoji)
                    .font(.system(size: 10))
                Text(entry.category)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(colorForLevel(entry.level))
                Spacer()
                if copiedID == entry.id {
                    Text("Copied")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.green)
                }
                Text(formatTime(entry.date))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            Text(entry.message)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(3)
        }
        .padding(.vertical, 2)
    }

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? Color.cyan.opacity(0.2) : Color.secondary.opacity(0.1))
                .foregroundStyle(isSelected ? .cyan : .secondary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func colorForLevel(_ level: OpenRockyLogLevel) -> Color {
        switch level {
        case .debug: return .secondary
        case .info: return .cyan
        case .warning: return .orange
        case .error: return .red
        }
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: date)
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f.string(from: date)
    }
}

// MARK: - Page 3: Log Detail

struct OpenRockyLogDetailView: View {
    let entry: OpenRockyLogEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Meta info
                VStack(alignment: .leading, spacing: 8) {
                    metaRow(label: "Level", value: "\(entry.level.emoji) \(entry.level.rawValue)", color: colorForLevel(entry.level))
                    metaRow(label: "Category", value: entry.category)
                    metaRow(label: "Time", value: formatDate(entry.date))
                }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                // Message
                VStack(alignment: .leading, spacing: 8) {
                    Text("Message")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Text(entry.message)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Log Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    let text = "[\(formatDate(entry.date))] [\(entry.level.rawValue)] [\(entry.category)] \(entry.message)"
                    UIPasteboard.general.string = text
                } label: {
                    Image(systemName: "doc.on.doc")
                }
            }
        }
    }

    private func metaRow(label: String, value: String, color: Color = .primary) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(color)
        }
    }

    private func colorForLevel(_ level: OpenRockyLogLevel) -> Color {
        switch level {
        case .debug: return .secondary
        case .info: return .cyan
        case .warning: return .orange
        case .error: return .red
        }
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f.string(from: date)
    }
}

// MARK: - Share Sheet

struct OpenRockyShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
