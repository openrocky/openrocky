//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation
import UIKit

@MainActor
final class OpenRockyURLService {
    static let shared = OpenRockyURLService()

    func open(urlString: String) async throws -> [String: String] {
        guard let url = URL(string: urlString) else {
            throw OpenRockyURLError.invalidURL(urlString)
        }

        let canOpen = UIApplication.shared.canOpenURL(url)
        guard canOpen else {
            throw OpenRockyURLError.cannotOpen(urlString)
        }

        await UIApplication.shared.open(url)

        return [
            "opened": "true",
            "url": urlString
        ]
    }
}

enum OpenRockyURLError: LocalizedError {
    case invalidURL(String)
    case cannotOpen(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url): "Invalid URL: \(url)"
        case .cannotOpen(let url): "Cannot open URL: \(url). The app may not be installed."
        }
    }
}
