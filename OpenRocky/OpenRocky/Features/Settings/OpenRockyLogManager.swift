//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation
import OSLog

// MARK: - Log Entry

struct OpenRockyLogEntry: Identifiable, Sendable {
    let id = UUID()
    let date: Date
    let level: OpenRockyLogLevel
    let category: String
    let message: String
}

enum OpenRockyLogLevel: String, CaseIterable, Sendable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"

    nonisolated var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        }
    }
}

/// Represents one log file (one app launch session or hourly segment).
struct OpenRockyLogFile: Identifiable, Sendable {
    let id: String          // filename without extension
    let url: URL
    let size: Int64
    let date: Date          // parsed from filename
    let isSegment: Bool     // true if _b, _c, etc.
    var sessionLabel: String = ""  // "Current Session" or "Previous Session"

    var displayName: String {
        let df = DateFormatter()
        df.dateFormat = "MM-dd HH:mm:ss"
        let suffix = isSegment ? " (cont.)" : ""
        return df.string(from: date) + suffix
    }

    var sizeText: String {
        if size < 1024 { return "\(size) B" }
        if size < 1024 * 1024 { return String(format: "%.1f KB", Double(size) / 1024) }
        return String(format: "%.1f MB", Double(size) / (1024 * 1024))
    }
}

// MARK: - Log Manager (fully nonisolated, thread-safe via DispatchQueue)

nonisolated final class OpenRockyLogManager: Sendable {
    nonisolated static let shared = OpenRockyLogManager()

    private let logger = Logger(subsystem: "org.openrocky", category: "App")
    private let impl = _OpenRockyLogStorage()

    private nonisolated init() {}

    // MARK: - Write

    nonisolated func debug(_ message: String, category: String = "General") {
        impl.append(level: .debug, category: category, message: message)
        logger.debug("\(message)")
    }

    nonisolated func info(_ message: String, category: String = "General") {
        impl.append(level: .info, category: category, message: message)
        logger.info("\(message)")
    }

    nonisolated func warning(_ message: String, category: String = "General") {
        impl.append(level: .warning, category: category, message: message)
        logger.warning("\(message)")
    }

    nonisolated func error(_ message: String, category: String = "General") {
        impl.append(level: .error, category: category, message: message)
        logger.error("\(message)")
    }

    // MARK: - Read

    nonisolated func allEntries(maxFiles: Int = 50) -> [OpenRockyLogEntry] {
        impl.allEntries(maxFiles: maxFiles)
    }

    nonisolated var totalLogSize: Int64 { impl.totalLogSize }
    nonisolated var logFileCount: Int { impl.logFileCount }

    // MARK: - Export

    nonisolated func exportAsText() -> String {
        impl.flush()
        return impl.exportAsText()
    }

    nonisolated func exportFileURL() -> URL? {
        let text = exportAsText()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let filename = "openrocky_logs_\(formatter.string(from: Date())).txt"
        let url = FileManager().temporaryDirectory.appendingPathComponent(filename)
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    // MARK: - File-level access

    /// The file key prefix for the current app launch session (e.g. "2026-04-05_153055").
    nonisolated var currentSessionPrefix: String { impl.currentSessionPrefix }

    nonisolated func logFiles() -> [OpenRockyLogFile] { impl.logFiles() }

    nonisolated func entries(for file: OpenRockyLogFile) -> [OpenRockyLogEntry] {
        impl.entries(for: file)
    }

    nonisolated func exportZipURL() -> URL? { impl.exportZipURL() }

    nonisolated func exportSingleFileURL(_ file: OpenRockyLogFile) -> URL? {
        impl.exportSingleFileURL(file)
    }

    // MARK: - Delete & Clear

    nonisolated func deleteFile(_ file: OpenRockyLogFile) { impl.deleteFile(file) }

    nonisolated func clear() { impl.clear() }
}

// MARK: - Storage implementation (nonisolated, @unchecked Sendable)

/// File naming: `2026-04-05_1430_a.log`
///   - date+time = launch time
///   - suffix `_a`, `_b`, ... = new segment every hour within a launch
/// One file per app launch, splits at 1-hour boundaries. Retains 7 days.
nonisolated private final class _OpenRockyLogStorage: @unchecked Sendable {
    private let queue = DispatchQueue(label: "org.openrocky.logmanager")
    private let fm = FileManager()
    private var buffer: [String] = []
    private var currentFileKey: String
    private var currentFileStart: Date
    private var segmentIndex: Int = 0
    private var flushTimer: DispatchSourceTimer?

    private static let retentionDays = 7
    private static let maxSegmentSeconds: TimeInterval = 3600 // 1 hour
    /// The launch key prefix (without segment suffix) for the current session.
    private let launchPrefix: String

    /// The launch key prefix (date+time without segment) for the current session.
    var currentSessionPrefix: String { launchPrefix }

    init() {
        let now = Date()
        currentFileKey = Self.launchKey(for: now, segment: 0)
        currentFileStart = now
        // Store the prefix (everything before the last underscore + segment letter)
        let key = currentFileKey
        launchPrefix = String(key.prefix(key.count - 2)) // remove "_a"
        ensureDirectoryExists()
        cleanupOldLogs()
        startFlushTimer()
        // Write launch header
        let header = "── App Launch: \(Self.timestampFormatter().string(from: now)) ──"
        buffer.append(header)
    }

    private var logDirectory: URL {
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("OpenRockyLogs", isDirectory: true)
    }

    private func ensureDirectoryExists() {
        try? fm.createDirectory(at: logDirectory, withIntermediateDirectories: true)
    }

    func append(level: OpenRockyLogLevel, category: String, message: String) {
        let now = Date()
        let formatter = Self.timestampFormatter()
        let line = "[\(formatter.string(from: now))] [\(level.rawValue)] [\(category)] \(message)"

        queue.sync {
            // Check if current segment exceeded 1 hour
            if now.timeIntervalSince(currentFileStart) >= Self.maxSegmentSeconds {
                flushBufferUnsafe()
                segmentIndex += 1
                currentFileKey = Self.launchKey(for: currentFileStart, segment: segmentIndex)
                currentFileStart = now
                buffer.append("── Segment \(segmentIndex + 1): \(formatter.string(from: now)) ──")
            }
            buffer.append(line)
            if buffer.count >= 100 {
                flushBufferUnsafe()
            }
        }
    }

    func allEntries(maxFiles: Int) -> [OpenRockyLogEntry] {
        flush()
        let files = logFilesSorted()
        let selected = files.suffix(maxFiles)
        var entries: [OpenRockyLogEntry] = []
        let formatter = Self.timestampFormatter()
        for file in selected {
            if let content = try? String(contentsOf: file, encoding: .utf8) {
                entries.append(contentsOf: parseLogFile(content, formatter: formatter))
            }
        }
        return entries
    }

    var totalLogSize: Int64 {
        logFilesSorted().reduce(0) { total, url in
            let size = (try? fm.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
            return total + size
        }
    }

    var logFileCount: Int { logFilesSorted().count }

    func exportAsText() -> String {
        let files = logFilesSorted()
        var lines: [String] = []
        lines.append("OpenRocky Logs")
        let exportFormatter = DateFormatter()
        exportFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        lines.append("Exported: \(exportFormatter.string(from: Date()))")
        lines.append("Device: \(ProcessInfo.processInfo.operatingSystemVersionString)")
        lines.append("Log files: \(files.count) (sessions)")
        lines.append(String(repeating: "─", count: 60))
        lines.append("")

        for file in files {
            lines.append("── \(file.deletingPathExtension().lastPathComponent) ──")
            if let content = try? String(contentsOf: file, encoding: .utf8) {
                lines.append(content)
            }
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    func flush() {
        queue.sync { flushBufferUnsafe() }
    }

    func deleteFile(_ file: OpenRockyLogFile) {
        try? fm.removeItem(at: file.url)
    }

    func clear() {
        queue.sync {
            buffer.removeAll()
        }
        let files = logFilesSorted()
        for file in files {
            try? fm.removeItem(at: file)
        }
    }

    // MARK: - File-level

    func logFiles() -> [OpenRockyLogFile] {
        flush()
        let prefix = launchPrefix
        var previousSessionPrefix: String?
        let files = logFilesSorted()
        // Find the previous session prefix (the one right before the current session)
        let sessionPrefixes = Set(files.map { url -> String in
            let name = url.deletingPathExtension().lastPathComponent
            return String(name.prefix(max(0, name.count - 2)))
        }).sorted()
        if let currentIndex = sessionPrefixes.firstIndex(of: prefix), currentIndex > 0 {
            previousSessionPrefix = sessionPrefixes[currentIndex - 1]
        }

        return files.map { url in
            let name = url.deletingPathExtension().lastPathComponent
            let size = (try? fm.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
            let date = Self.parseFileDate(name) ?? Date.distantPast
            let isSegment = name.last != "a"
            let filePrefix = String(name.prefix(max(0, name.count - 2)))
            let label: String
            if filePrefix == prefix {
                label = "Current Session"
            } else if filePrefix == previousSessionPrefix {
                label = "Previous Session"
            } else {
                label = ""
            }
            return OpenRockyLogFile(id: name, url: url, size: size, date: date, isSegment: isSegment, sessionLabel: label)
        }
    }

    func entries(for file: OpenRockyLogFile) -> [OpenRockyLogEntry] {
        flush()
        let formatter = Self.timestampFormatter()
        guard let content = try? String(contentsOf: file.url, encoding: .utf8) else { return [] }
        return parseLogFile(content, formatter: formatter)
    }

    func exportZipURL() -> URL? {
        flush()
        let files = logFilesSorted()
        guard !files.isEmpty else { return nil }

        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = df.string(from: Date())

        // Copy all log files to a temp staging directory, then zip it
        let stagingDir = fm.temporaryDirectory.appendingPathComponent("openrocky_logs_\(timestamp)")
        try? fm.removeItem(at: stagingDir)
        try? fm.createDirectory(at: stagingDir, withIntermediateDirectories: true)
        for file in files {
            try? fm.copyItem(at: file, to: stagingDir.appendingPathComponent(file.lastPathComponent))
        }

        let zipURL = fm.temporaryDirectory.appendingPathComponent("openrocky_logs_\(timestamp).zip")
        try? fm.removeItem(at: zipURL)

        let coordinator = NSFileCoordinator()
        var error: NSError?
        var resultURL: URL?
        coordinator.coordinate(readingItemAt: stagingDir, options: .forUploading, error: &error) { tempZipURL in
            try? fm.copyItem(at: tempZipURL, to: zipURL)
            resultURL = zipURL
        }
        try? fm.removeItem(at: stagingDir)
        return resultURL
    }

    func exportSingleFileURL(_ file: OpenRockyLogFile) -> URL? {
        flush()
        let dest = fm.temporaryDirectory.appendingPathComponent(file.url.lastPathComponent)
        try? fm.removeItem(at: dest)
        try? fm.copyItem(at: file.url, to: dest)
        return fm.fileExists(atPath: dest.path) ? dest : nil
    }

    private static func parseFileDate(_ name: String) -> Date? {
        // Format: 2026-04-05_153055_a
        guard name.count >= 17 else { return nil }
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd_HHmmss"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df.date(from: String(name.prefix(17)))
    }

    // MARK: - Private

    private func logFilesSorted() -> [URL] {
        guard let files = try? fm.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: nil) else {
            return []
        }
        return files
            .filter { $0.pathExtension == "log" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// Generate file key: `2026-04-05_1430_a` (launch time + segment letter)
    private static func launchKey(for date: Date, segment: Int) -> String {
        let cal = Calendar.current
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let suffix = segment < 26 ? String(UnicodeScalar(UInt8(97 + segment))) : "\(segment)"
        return String(format: "%04d-%02d-%02d_%02d%02d%02d_%@",
                      c.year ?? 0, c.month ?? 0, c.day ?? 0,
                      c.hour ?? 0, c.minute ?? 0, c.second ?? 0, suffix)
    }

    private func fileURL(for key: String) -> URL {
        logDirectory.appendingPathComponent("\(key).log")
    }

    /// Must be called while holding `queue`.
    private func flushBufferUnsafe() {
        guard !buffer.isEmpty else { return }
        let text = buffer.joined(separator: "\n") + "\n"
        buffer.removeAll()

        let url = fileURL(for: currentFileKey)
        if fm.fileExists(atPath: url.path) {
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(text.data(using: .utf8) ?? Data())
                handle.closeFile()
            }
        } else {
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func cleanupOldLogs() {
        queue.async { [self] in
            let cutoff = Calendar.current.date(byAdding: .day, value: -Self.retentionDays, to: Date()) ?? Date()
            let cutoffKey = Self.launchKey(for: cutoff, segment: 0)
            let files = logFilesSorted()
            for file in files {
                let name = file.deletingPathExtension().lastPathComponent
                if name < cutoffKey {
                    try? fm.removeItem(at: file)
                }
            }
        }
    }

    private func startFlushTimer() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 30, repeating: 30)
        timer.setEventHandler { [weak self] in
            self?.flushBufferUnsafe()
        }
        timer.resume()
        flushTimer = timer
    }

    private static func timestampFormatter() -> DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }

    private func parseLogFile(_ content: String, formatter: DateFormatter) -> [OpenRockyLogEntry] {
        var entries: [OpenRockyLogEntry] = []
        for line in content.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let entry = parseLine(String(line), formatter: formatter) else { continue }
            entries.append(entry)
        }
        return entries
    }

    private func parseLine(_ line: String, formatter: DateFormatter) -> OpenRockyLogEntry? {
        guard line.hasPrefix("[") else { return nil }
        var scanner = line[line.startIndex...]

        guard let dateEnd = scanner.range(of: "] [") else { return nil }
        let dateStr = String(scanner[scanner.index(after: scanner.startIndex)..<dateEnd.lowerBound])
        scanner = scanner[dateEnd.upperBound...]

        guard let levelEnd = scanner.range(of: "] [") else { return nil }
        let levelStr = String(scanner[scanner.startIndex..<levelEnd.lowerBound])
        scanner = scanner[levelEnd.upperBound...]

        guard let catEnd = scanner.range(of: "] ") else { return nil }
        let category = String(scanner[scanner.startIndex..<catEnd.lowerBound])
        let message = String(scanner[catEnd.upperBound...])

        let level = OpenRockyLogLevel(rawValue: levelStr) ?? .info
        let date = formatter.date(from: dateStr) ?? Date()

        return OpenRockyLogEntry(date: date, level: level, category: category, message: message)
    }
}

// MARK: - Convenience global

nonisolated(unsafe) let rlog = OpenRockyLogManager.shared
