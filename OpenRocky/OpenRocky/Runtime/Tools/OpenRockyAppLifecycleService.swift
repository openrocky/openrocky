//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-04-06
// Copyright (c) 2026 everettjf. All rights reserved.
//

import UIKit

@MainActor
final class OpenRockyAppLifecycleService {
    static let shared = OpenRockyAppLifecycleService()

    func exitApp(afterDelay delay: TimeInterval = 1.5) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            // Suspend the app to background (iOS-friendly approach)
            UIControl().sendAction(#selector(URLSessionTask.suspend), to: UIApplication.shared, for: nil)
        }
    }
}
