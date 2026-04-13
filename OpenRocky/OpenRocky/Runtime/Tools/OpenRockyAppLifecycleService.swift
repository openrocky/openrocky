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

    static let willExitNotification = Notification.Name("OpenRockyWillExit")

    func exitApp(afterDelay delay: TimeInterval = 1.0) {
        NotificationCenter.default.post(name: Self.willExitNotification, object: nil)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            exit(0)
        }
    }
}
