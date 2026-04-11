//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import UIKit
import UniformTypeIdentifiers

final class OpenRockyFilePickerCoordinator: NSObject, UIDocumentPickerDelegate {
    private var continuation: CheckedContinuation<(data: Data, filename: String), Error>?

    init(continuation: CheckedContinuation<(data: Data, filename: String), Error>) {
        self.continuation = continuation
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else {
            continuation?.resume(throwing: FilePickerError.noFile)
            continuation = nil
            return
        }

        guard url.startAccessingSecurityScopedResource() else {
            continuation?.resume(throwing: FilePickerError.accessDenied)
            continuation = nil
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let data = try Data(contentsOf: url)
            let filename = url.lastPathComponent
            continuation?.resume(returning: (data: data, filename: filename))
        } catch {
            continuation?.resume(throwing: error)
        }
        continuation = nil
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        continuation?.resume(throwing: FilePickerError.cancelled)
        continuation = nil
    }

    enum FilePickerError: Error, LocalizedError {
        case noFile
        case cancelled
        case accessDenied
        var errorDescription: String? {
            switch self {
            case .noFile: return "No file was selected"
            case .cancelled: return "File selection was cancelled"
            case .accessDenied: return "Cannot access the selected file"
            }
        }
    }
}
