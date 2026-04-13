//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation
import Combine

struct OpenRockyBuiltInTool: Identifiable, Sendable {
    let id: String  // tool name
    let displayName: String
    let description: String
    let icon: String
    let group: OpenRockyBuiltInToolGroup
    let defaultEnabled: Bool
    let requiresSetup: Bool

    init(id: String, displayName: String, description: String, icon: String, group: OpenRockyBuiltInToolGroup, defaultEnabled: Bool = true, requiresSetup: Bool = false) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.icon = icon
        self.group = group
        self.defaultEnabled = defaultEnabled
        self.requiresSetup = requiresSetup
    }
}

typealias OpenRockyBuiltInToolDefinition = OpenRockyBuiltInTool

enum OpenRockyBuiltInToolGroup: String, CaseIterable, Sendable {
    case locationWeather = "Location & Weather"
    case healthFitness = "Health & Fitness"
    case memory = "Memory"
    case fileShell = "Files & Shell"
    case media = "Media"
    case productivity = "Productivity"
    case calendar = "Calendar & Reminders"
    case contacts = "Contacts"
    case browser = "Browser"
    case web = "Web & Search"
    case system = "System"
}

@MainActor
final class OpenRockyBuiltInToolStore: ObservableObject {
    static let shared = OpenRockyBuiltInToolStore()

    @Published private(set) var tools: [OpenRockyBuiltInTool]
    @Published private var disabledToolIDs: Set<String>

    private static let disabledToolsKey = "rocky.tools.disabled"

    init() {
        tools = Self.allTools
        let saved = UserDefaults.standard.stringArray(forKey: Self.disabledToolsKey) ?? []
        disabledToolIDs = Set(saved)
        // Tools that are defaultEnabled=false should be disabled unless explicitly enabled
        for tool in Self.allTools where !tool.defaultEnabled {
            if !UserDefaults.standard.bool(forKey: "rocky.tools.enabled.\(tool.id)") {
                disabledToolIDs.insert(tool.id)
            }
        }
    }

    var enabledToolNames: Set<String> {
        Set(tools.map(\.id)).subtracting(disabledToolIDs)
    }

    func isEnabled(_ toolID: String) -> Bool {
        !disabledToolIDs.contains(toolID)
    }

    func setEnabled(_ toolID: String, enabled: Bool) {
        if enabled {
            disabledToolIDs.remove(toolID)
            // For non-default tools, mark as explicitly enabled
            if let tool = tools.first(where: { $0.id == toolID }), !tool.defaultEnabled {
                UserDefaults.standard.set(true, forKey: "rocky.tools.enabled.\(toolID)")
            }
        } else {
            disabledToolIDs.insert(toolID)
            UserDefaults.standard.removeObject(forKey: "rocky.tools.enabled.\(toolID)")
        }
        persistDisabledTools()
    }

    private func persistDisabledTools() {
        UserDefaults.standard.set(Array(disabledToolIDs), forKey: Self.disabledToolsKey)
    }

    func tool(for id: String) -> OpenRockyBuiltInTool? {
        tools.first { $0.id == id }
    }

    func toolsByGroup() -> [(group: OpenRockyBuiltInToolGroup, tools: [OpenRockyBuiltInTool])] {
        OpenRockyBuiltInToolGroup.allCases.compactMap { group in
            // Exclude feature-managed tools (requiresSetup) from the tools toggle list
            let groupTools = tools.filter { $0.group == group && !$0.requiresSetup }
            return groupTools.isEmpty ? nil : (group: group, tools: groupTools)
        }
    }

    // MARK: - All Built-in Tool Definitions

    private static let allTools: [OpenRockyBuiltInToolDefinition] = [
        // Location & Weather
        .init(id: "apple-location", displayName: "Location", description: "Get the device's current GPS location.", icon: "location.fill", group: .locationWeather),
        .init(id: "apple-geocode", displayName: "Geocode", description: "Convert place names to coordinates.", icon: "map.fill", group: .locationWeather),
        .init(id: "weather", displayName: "Weather", description: "Current weather and forecast via Open-Meteo.", icon: "cloud.sun.fill", group: .locationWeather),
        .init(id: "nearby-search", displayName: "Nearby Search", description: "Search nearby places via Apple Maps.", icon: "mappin.and.ellipse", group: .locationWeather),

        // Health
        .init(id: "apple-health-summary", displayName: "Health Summary", description: "Daily health summary from HealthKit.", icon: "heart.fill", group: .healthFitness),
        .init(id: "apple-health-metric", displayName: "Health Metric", description: "Query specific health metrics over a date range.", icon: "chart.bar.fill", group: .healthFitness),

        // Memory
        .init(id: "memory_get", displayName: "Memory Read", description: "Retrieve a stored memory by key.", icon: "brain.head.profile.fill", group: .memory),
        .init(id: "memory_write", displayName: "Memory Write", description: "Store a key-value memory persistently.", icon: "square.and.pencil", group: .memory),

        // Files & Shell
        .init(id: "shell-execute", displayName: "Shell & Network", description: "Shell commands plus network tools (ping, dig, nslookup, whois, nc, telnet).", icon: "terminal.fill", group: .fileShell),
        .init(id: "python-execute", displayName: "Python", description: "Run Python 3.13 code for calculations, data processing, and algorithms.", icon: "chevron.left.forwardslash.chevron.right", group: .fileShell),
        .init(id: "ffmpeg-execute", displayName: "FFmpeg", description: "Audio/video processing: merge, extract, transcode, trim, thumbnails.", icon: "film.fill", group: .fileShell),
        .init(id: "file-read", displayName: "File Read", description: "Read files from the workspace sandbox.", icon: "doc.text.fill", group: .fileShell),
        .init(id: "file-write", displayName: "File Write", description: "Write files to the workspace sandbox.", icon: "doc.badge.plus", group: .fileShell),
        .init(id: "icloud-read", displayName: "iCloud Read", description: "Read files from iCloud Drive (e.g. Obsidian vaults).", icon: "icloud.fill", group: .fileShell),
        .init(id: "icloud-list", displayName: "iCloud List", description: "List files in iCloud Drive containers.", icon: "icloud.and.arrow.down.fill", group: .fileShell),
        .init(id: "icloud-write", displayName: "iCloud Write", description: "Write files to iCloud Drive mounts.", icon: "icloud.and.arrow.up.fill", group: .fileShell),

        // Media
        .init(id: "camera-capture", displayName: "Camera", description: "Take a photo with the device camera.", icon: "camera.fill", group: .media),
        .init(id: "photo-pick", displayName: "Photo Library", description: "Select a photo from the library.", icon: "photo.fill", group: .media),
        .init(id: "file-pick", displayName: "File Picker", description: "Select a file from the device.", icon: "doc.fill", group: .media),

        // Productivity
        .init(id: "apple-alarm", displayName: "Alarm", description: "Create iOS alarms at specific times.", icon: "alarm.fill", group: .productivity),
        .init(id: "todo", displayName: "Todo List", description: "Manage a persistent todo list.", icon: "checklist", group: .productivity),

        // Browser
        .init(id: "browser-open", displayName: "Browser", description: "Open URLs for user interaction (login, auth).", icon: "safari.fill", group: .browser),
        .init(id: "browser-cookies", displayName: "Cookies", description: "Extract browser cookies for API authentication.", icon: "key.fill", group: .browser),
        .init(id: "browser-read", displayName: "Read Page", description: "Fetch and extract text from JS-rendered pages.", icon: "doc.richtext.fill", group: .browser),

        // Auth & Crypto
        .init(id: "oauth-authenticate", displayName: "OAuth", description: "OAuth login flow for third-party services.", icon: "person.badge.key.fill", group: .system),
        .init(id: "crypto", displayName: "Crypto", description: "HMAC, SHA256, MD5, AES encrypt/decrypt, base64.", icon: "lock.shield.fill", group: .system),

        // Web
        .init(id: "web-search", displayName: "Web Search", description: "Search the web via DuckDuckGo.", icon: "globe", group: .web),

        // Calendar & Reminders
        .init(id: "apple-calendar-list", displayName: "Calendar List", description: "List events from Apple Calendar.", icon: "calendar", group: .calendar),
        .init(id: "apple-calendar-create", displayName: "Calendar Create", description: "Create events in Apple Calendar.", icon: "calendar.badge.plus", group: .calendar),
        .init(id: "apple-reminder-list", displayName: "Reminders List", description: "List Apple Reminders.", icon: "list.bullet", group: .calendar),
        .init(id: "apple-reminder-create", displayName: "Reminder Create", description: "Create Apple Reminders.", icon: "plus.circle.fill", group: .calendar),

        // Contacts
        .init(id: "apple-contacts-search", displayName: "Contacts Search", description: "Search contacts by name.", icon: "person.crop.circle.fill", group: .contacts),

        // Features (managed via Settings → Features, hidden from tools toggle)
        .init(id: "email-send", displayName: "Send Email", description: "Send emails via SMTP.", icon: "envelope.fill", group: .system, defaultEnabled: false, requiresSetup: true),

        // System
        .init(id: "notification-schedule", displayName: "Notification", description: "Schedule local notifications.", icon: "bell.fill", group: .system),
        .init(id: "open-url", displayName: "Open URL", description: "Open URLs and deep links in other apps.", icon: "arrow.up.forward.app.fill", group: .system),
        .init(id: "app-exit", displayName: "Exit App", description: "Exit the OpenRocky app when the user explicitly requests.", icon: "power", group: .system),

        // Agent
        .init(id: "delegate-task", displayName: "Delegate Task", description: "Delegate complex tasks to a background agent for parallel multi-tool execution.", icon: "person.2.fill", group: .system),
    ]
}
