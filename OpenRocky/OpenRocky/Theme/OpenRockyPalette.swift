//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import SwiftUI
import UIKit

enum OpenRockyPalette {
    // MARK: - Surfaces
    static let background = Color(light: .init(red: 0.96, green: 0.96, blue: 0.98),
                                  dark: .init(red: 0.06, green: 0.08, blue: 0.12))
    static let card = Color(light: .init(red: 1.0, green: 1.0, blue: 1.0),
                            dark: .init(red: 0.10, green: 0.12, blue: 0.17))
    static let cardElevated = Color(light: .init(red: 0.93, green: 0.93, blue: 0.95),
                                    dark: .init(red: 0.13, green: 0.16, blue: 0.22))
    static let cardPressed = Color(light: .init(red: 0.90, green: 0.90, blue: 0.92),
                                   dark: .init(red: 0.08, green: 0.10, blue: 0.14))

    // MARK: - Strokes & Separators
    static let stroke = Color(light: .black.opacity(0.10),
                              dark: .white.opacity(0.10))
    static let strokeSubtle = Color(light: .black.opacity(0.06),
                                    dark: .white.opacity(0.06))
    static let separator = Color(light: .black.opacity(0.08),
                                 dark: .white.opacity(0.08))

    // MARK: - Semantic Colors
    static let accent = Color(red: 0.29, green: 0.78, blue: 0.89)
    static let secondary = Color(red: 0.98, green: 0.55, blue: 0.34)
    static let success = Color(red: 0.43, green: 0.89, blue: 0.62)
    static let warning = Color(red: 0.98, green: 0.75, blue: 0.35)

    // MARK: - Text
    static let text = Color(light: .black.opacity(0.88),
                            dark: .white.opacity(0.88))
    static let muted = Color(light: .black.opacity(0.50),
                             dark: .white.opacity(0.55))
    static let label = Color(light: .black.opacity(0.35),
                             dark: .white.opacity(0.40))

    // MARK: - Shadows
    static let shadow = Color.black.opacity(0.32)
}

// MARK: - Adaptive Color Helper

extension Color {
    /// Adaptive light/dark color.
    /// Must be `nonisolated` because `Color` conforms to `View` which is
    /// `@MainActor`, but UIKit's dynamic-provider closure can be resolved
    /// on any thread (e.g. SwiftUI's AsyncRenderer).
    nonisolated init(light: Color, dark: Color) {
        let l = UIColor(light)
        let d = UIColor(dark)
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? d : l
        })
    }
}
