//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import SwiftUI

struct QuickTask: Identifiable {
    let id = UUID()
    let title: String
    let prompt: String
    let symbol: String
    let tint: Color
}
