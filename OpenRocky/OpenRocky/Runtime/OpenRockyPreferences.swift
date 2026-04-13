//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-04-13
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation
import Observation

@Observable
@MainActor
final class OpenRockyPreferences {
    static let shared = OpenRockyPreferences()

    var voiceInterruptionEnabled: Bool {
        didSet { UserDefaults.standard.set(voiceInterruptionEnabled, forKey: "rocky.pref.voiceInterruptionEnabled") }
    }

    var voiceAutoGreeting: Bool {
        didSet { UserDefaults.standard.set(voiceAutoGreeting, forKey: "rocky.pref.voiceAutoGreeting") }
    }

    var voiceTranscriptVisible: Bool {
        didSet { UserDefaults.standard.set(voiceTranscriptVisible, forKey: "rocky.pref.voiceTranscriptVisible") }
    }

    var chatAutoSaveConversation: Bool {
        didSet { UserDefaults.standard.set(chatAutoSaveConversation, forKey: "rocky.pref.chatAutoSaveConversation") }
    }

    var hapticFeedbackEnabled: Bool {
        didSet { UserDefaults.standard.set(hapticFeedbackEnabled, forKey: "rocky.pref.hapticFeedbackEnabled") }
    }

    private init() {
        let defaults = UserDefaults.standard
        self.voiceInterruptionEnabled = defaults.object(forKey: "rocky.pref.voiceInterruptionEnabled") as? Bool ?? false
        self.voiceAutoGreeting = defaults.object(forKey: "rocky.pref.voiceAutoGreeting") as? Bool ?? true
        self.voiceTranscriptVisible = defaults.object(forKey: "rocky.pref.voiceTranscriptVisible") as? Bool ?? true
        self.chatAutoSaveConversation = defaults.object(forKey: "rocky.pref.chatAutoSaveConversation") as? Bool ?? true
        self.hapticFeedbackEnabled = defaults.object(forKey: "rocky.pref.hapticFeedbackEnabled") as? Bool ?? true
    }
}
