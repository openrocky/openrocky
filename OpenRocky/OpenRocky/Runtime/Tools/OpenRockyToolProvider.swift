//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import ChatClientKit
import Foundation
import LanguageModelChatUI
import UIKit

final class OpenRockyToolProvider: ToolProvider, @unchecked Sendable {
    private var _toolbox: OpenRockyToolbox?
    private let skillStore: OpenRockyBuiltInToolStore

    init(skillStore: OpenRockyBuiltInToolStore) {
        self.skillStore = skillStore
    }

    @MainActor
    private var toolbox: OpenRockyToolbox {
        if let existing = _toolbox { return existing }
        let new = OpenRockyToolbox()
        _toolbox = new
        return new
    }

    func enabledTools() async -> [ChatRequestBody.Tool] {
        let enabled = await MainActor.run { skillStore.enabledToolNames }
        var tools = Self.allTools.filter { tool in
            if case let .function(name, _, _, _) = tool {
                return enabled.contains(name)
            }
            return false
        }
        // Add custom skills as callable tools
        let skillTools = await MainActor.run { Self.skillToolDefinitions() }
        tools.append(contentsOf: skillTools)
        return tools
    }

    func findTool(for request: ToolRequest) async -> ToolExecutor? {
        // Handle skill tools
        if request.name.hasPrefix("skill-") {
            let skill = await MainActor.run { OpenRockyCustomSkillStore.shared.skill(forToolName: request.name) }
            guard skill != nil else { return nil }
            return OpenRockyToolExecutor(name: request.name)
        }
        let enabled = await MainActor.run { skillStore.enabledToolNames }
        guard enabled.contains(request.name) else { return nil }
        return OpenRockyToolExecutor(name: request.name)
    }

    @MainActor
    private static func skillToolDefinitions() -> [ChatRequestBody.Tool] {
        OpenRockyCustomSkillStore.shared.skills.filter(\.isEnabled).map { skill in
            let toolName = "skill-\(OpenRockyCustomSkillStore.sanitizeToolName(skill.name))"
            let desc = skill.description + (skill.triggerConditions.isEmpty ? "" : " Trigger: \(skill.triggerConditions)")
            return .function(
                name: toolName,
                description: desc,
                parameters: ["type": "object", "properties": [:] as AnyCodingValue],
                strict: nil
            )
        }
    }

    func executeTool(
        _ tool: ToolExecutor,
        parameters: String,
        anchor: UIView?
    ) async throws -> ToolResult {
        guard let executor = tool as? OpenRockyToolExecutor else {
            rlog.error("Unknown tool executor type: \(type(of: tool))", category: "Tools")
            return ToolResult(error: "Unknown tool executor.")
        }
        do {
            let name = executor.name
            let result = try await Self.runOnMain(toolbox: toolbox, name: name, arguments: parameters)
            return ToolResult(text: result)
        } catch {
            return ToolResult(error: error.localizedDescription)
        }
    }

    @MainActor
    private static func runOnMain(toolbox: OpenRockyToolbox, name: String, arguments: String) async throws -> String {
        try await toolbox.execute(name: name, arguments: arguments)
    }

    func prepareForConversation() async {}

    // MARK: - Tool Definitions (ChatRequestBody.Tool format using AnyCodingValue literals)

    private static let allTools: [ChatRequestBody.Tool] = [
        .function(name: "apple-location", description: "Get the user's current device location.", parameters: ["type": "object", "properties": [:] as AnyCodingValue], strict: nil),
        .function(name: "apple-geocode", description: "Convert a place name or address into coordinates.", parameters: [
            "type": "object",
            "properties": ["address": ["type": "string", "description": "Place name, city, or address."]],
            "required": ["address"]
        ], strict: nil),
        .function(name: "weather", description: "Get current weather and hourly forecast.", parameters: [
            "type": "object",
            "properties": [
                "latitude": ["type": "number", "description": "Optional latitude."],
                "longitude": ["type": "number", "description": "Optional longitude."],
                "label": ["type": "string", "description": "Optional location label."]
            ]
        ], strict: nil),
        .function(name: "apple-alarm", description: "Create a real Apple alarm at one exact ISO-8601 datetime.", parameters: [
            "type": "object",
            "properties": [
                "title": ["type": "string", "description": "Short label for the alarm."],
                "scheduled_at": ["type": "string", "description": "Exact ISO-8601 date-time."]
            ],
            "required": ["scheduled_at"]
        ], strict: nil),
        .function(name: "memory_get", description: "Retrieve a stored memory by key.", parameters: [
            "type": "object",
            "properties": ["key": ["type": "string", "description": "The memory key."]],
            "required": ["key"]
        ], strict: nil),
        .function(name: "memory_write", description: "Store a key-value memory persistently.", parameters: [
            "type": "object",
            "properties": [
                "key": ["type": "string", "description": "Short descriptive key."],
                "value": ["type": "string", "description": "The value to store."]
            ],
            "required": ["key", "value"]
        ], strict: nil),
        .function(name: "apple-health-summary", description: "Get a daily health summary.", parameters: [
            "type": "object",
            "properties": ["date": ["type": "string", "description": "Date in YYYY-MM-DD format."]],
            "required": ["date"]
        ], strict: nil),
        .function(name: "apple-health-metric", description: "Query a specific health metric for a date range.", parameters: [
            "type": "object",
            "properties": [
                "metric": ["type": "string", "description": "The health metric name."],
                "start_date": ["type": "string", "description": "Start date YYYY-MM-DD."],
                "end_date": ["type": "string", "description": "End date YYYY-MM-DD."]
            ],
            "required": ["metric", "start_date", "end_date"]
        ], strict: nil),
        .function(name: "shell-execute", description: "Execute shell commands and network tools (ping, dig, nslookup, host, whois, nc, telnet, curl, ssh) in the iOS sandbox.", parameters: [
            "type": "object",
            "properties": ["command": ["type": "string", "description": "The shell command."]],
            "required": ["command"]
        ], strict: nil),
        .function(name: "python-execute", description: "Execute Python 3.13 code on device. Use for calculations, data processing, algorithms, or any code task. Full standard library available.", parameters: [
            "type": "object",
            "properties": ["code": ["type": "string", "description": "Python source code. Use print() for output."]],
            "required": ["code"]
        ], strict: nil),
        .function(name: "ffmpeg-execute", description: "Run FFmpeg for audio/video processing. Merge, extract, transcode, trim, thumbnails, GIFs.", parameters: [
            "type": "object",
            "properties": ["args": ["type": "string", "description": "FFmpeg arguments without leading 'ffmpeg'."]],
            "required": ["args"]
        ], strict: nil),
        .function(name: "browser-open", description: "Open URL in browser for user to interact (login). Returns final URL and title.", parameters: [
            "type": "object",
            "properties": ["url": ["type": "string", "description": "URL to open."]],
            "required": ["url"]
        ], strict: nil),
        .function(name: "browser-cookies", description: "Get browser cookies for a domain after user login.", parameters: [
            "type": "object",
            "properties": ["domain": ["type": "string", "description": "Domain to get cookies for."]],
            "required": ["domain"]
        ], strict: nil),
        .function(name: "browser-read", description: "Fetch URL with browser engine and extract text content.", parameters: [
            "type": "object",
            "properties": ["url": ["type": "string", "description": "URL to read."]],
            "required": ["url"]
        ], strict: nil),
        .function(name: "oauth-authenticate", description: "Start OAuth flow in system browser. Returns callback with tokens.", parameters: [
            "type": "object",
            "properties": [
                "auth_url": ["type": "string", "description": "OAuth authorization URL."],
                "callback_scheme": ["type": "string", "description": "Callback URL scheme."]
            ],
            "required": ["auth_url", "callback_scheme"]
        ], strict: nil),
        .function(name: "crypto", description: "Crypto: hmac_sha256, sha256, md5, aes_encrypt, aes_decrypt, base64_encode, base64_decode.", parameters: [
            "type": "object",
            "properties": [
                "operation": ["type": "string", "description": "Operation name."],
                "data": ["type": "string", "description": "Input data."],
                "key": ["type": "string", "description": "Key (hex) for HMAC/AES."],
                "iv": ["type": "string", "description": "IV (hex) for AES-CBC."]
            ],
            "required": ["operation", "data"]
        ], strict: nil),
        .function(name: "todo", description: "Manage a persistent todo list. Actions: add, list, complete, delete.", parameters: [
            "type": "object",
            "properties": [
                "action": ["type": "string", "description": "add, list, complete, or delete."],
                "title": ["type": "string", "description": "Title for new todo (add)."],
                "id": ["type": "string", "description": "UUID of item (complete/delete)."]
            ],
            "required": ["action"]
        ], strict: nil),
        .function(name: "file-read", description: "Read a file from the workspace sandbox.", parameters: [
            "type": "object",
            "properties": ["path": ["type": "string", "description": "Relative file path."]],
            "required": ["path"]
        ], strict: nil),
        .function(name: "file-write", description: "Write content to a file in the workspace sandbox.", parameters: [
            "type": "object",
            "properties": [
                "path": ["type": "string", "description": "Relative file path."],
                "content": ["type": "string", "description": "Text content to write."]
            ],
            "required": ["path", "content"]
        ], strict: nil),
        .function(name: "web-search", description: "Search the web using DuckDuckGo and return results.", parameters: [
            "type": "object",
            "properties": ["query": ["type": "string", "description": "The search query."]],
            "required": ["query"]
        ], strict: nil),
        .function(name: "camera-capture", description: "Take a photo using the device camera and save it to the workspace.", parameters: ["type": "object", "properties": [:] as AnyCodingValue], strict: nil),
        .function(name: "photo-pick", description: "Pick a photo from the device photo library and save it to the workspace.", parameters: ["type": "object", "properties": [:] as AnyCodingValue], strict: nil),
        .function(name: "file-pick", description: "Pick a file from the device and save it to the workspace.", parameters: ["type": "object", "properties": [:] as AnyCodingValue], strict: nil),
        .function(name: "icloud-read", description: "Read a file from a mounted iCloud Drive folder. Use mount name (configured in Settings → External Folders) or container ID.", parameters: [
            "type": "object",
            "properties": [
                "container": ["type": "string", "description": "Mount name (e.g. 'obsidian') or iCloud container ID (e.g. 'iCloud~md~obsidian')."],
                "path": ["type": "string", "description": "Relative file path within the container, e.g. 'MyVault/note.md'."]
            ],
            "required": ["container", "path"]
        ], strict: nil),
        .function(name: "icloud-list", description: "List files and folders in a mounted iCloud Drive folder. Use mount name or container ID.", parameters: [
            "type": "object",
            "properties": [
                "container": ["type": "string", "description": "Mount name (e.g. 'obsidian') or iCloud container ID."],
                "path": ["type": "string", "description": "Relative folder path within the container. Use '' or '/' for root."]
            ],
            "required": ["container"]
        ], strict: nil),
        .function(name: "icloud-write", description: "Write content to a file in an iCloud Drive mount. The mount must have read/write permission.", parameters: [
            "type": "object",
            "properties": [
                "container": ["type": "string", "description": "Mount name, e.g. 'obsidian'."],
                "path": ["type": "string", "description": "Relative file path, e.g. 'MyVault/note.md'."],
                "content": ["type": "string", "description": "Text content to write."]
            ],
            "required": ["container", "path", "content"]
        ], strict: nil),
        .function(name: "apple-calendar-list", description: "List events from Apple Calendar for a date range.", parameters: [
            "type": "object",
            "properties": [
                "start_date": ["type": "string", "description": "Start date (YYYY-MM-DD)."],
                "end_date": ["type": "string", "description": "End date (YYYY-MM-DD)."]
            ],
            "required": ["start_date"]
        ], strict: nil),
        .function(name: "apple-calendar-create", description: "Create an event in Apple Calendar.", parameters: [
            "type": "object",
            "properties": [
                "title": ["type": "string", "description": "Event title."],
                "start": ["type": "string", "description": "Start datetime (ISO-8601)."],
                "end": ["type": "string", "description": "End datetime (ISO-8601)."],
                "notes": ["type": "string", "description": "Event notes."]
            ],
            "required": ["title", "start"]
        ], strict: nil),
        .function(name: "apple-reminder-list", description: "List reminders from Apple Reminders.", parameters: [
            "type": "object",
            "properties": [
                "list_name": ["type": "string", "description": "Reminder list name (optional)."]
            ]
        ], strict: nil),
        .function(name: "apple-reminder-create", description: "Create a reminder in Apple Reminders. Always include due_date when the user mentions a time or deadline.", parameters: [
            "type": "object",
            "properties": [
                "title": ["type": "string", "description": "Reminder title."],
                "due_date": ["type": "string", "description": "Due date and time in ISO-8601 format (e.g. 2025-04-05T14:00:00). Always set this when user specifies a time."],
                "notes": ["type": "string", "description": "Notes."]
            ],
            "required": ["title"]
        ], strict: nil),
        .function(name: "apple-contacts-search", description: "Search contacts by name. Use \"*\" to list all. Max 50 results.", parameters: [
            "type": "object",
            "properties": [
                "query": ["type": "string", "description": "Name to search for, or \"*\" for all."]
            ],
            "required": ["query"]
        ], strict: nil),
        .function(name: "nearby-search", description: "Search nearby places via Apple Maps.", parameters: [
            "type": "object",
            "properties": [
                "query": ["type": "string", "description": "What to search for (e.g. coffee shop)."],
                "latitude": ["type": "number", "description": "Latitude (optional, uses current location if omitted)."],
                "longitude": ["type": "number", "description": "Longitude (optional)."]
            ],
            "required": ["query"]
        ], strict: nil),
        .function(name: "notification-schedule", description: "Schedule a local notification.", parameters: [
            "type": "object",
            "properties": [
                "title": ["type": "string", "description": "Notification title."],
                "body": ["type": "string", "description": "Notification body."],
                "delay_seconds": ["type": "number", "description": "Seconds from now to fire."]
            ],
            "required": ["title", "body", "delay_seconds"]
        ], strict: nil),
        .function(name: "open-url", description: "Open a URL or deep link in another app.", parameters: [
            "type": "object",
            "properties": [
                "url": ["type": "string", "description": "URL or deep link to open."]
            ],
            "required": ["url"]
        ], strict: nil),
        .function(name: "app-exit", description: "Exit/quit the OpenRocky app. Only call this when the user EXPLICITLY asks to quit, exit, or close the app. Before calling, always say a brief farewell.", parameters: [
            "type": "object",
            "properties": [
                "farewell_message": ["type": "string", "description": "A brief farewell message to display before exiting."]
            ],
            "required": ["farewell_message"]
        ], strict: nil),
        .function(name: "email-send", description: "Send an email via SMTP. Requires the user to have configured SMTP settings (Gmail app password, etc.) in Settings → Tools → Send Email. If not configured, tell the user to set it up first.", parameters: [
            "type": "object",
            "properties": [
                "to": ["type": "string", "description": "Comma-separated recipient email addresses."],
                "subject": ["type": "string", "description": "Email subject line."],
                "body": ["type": "string", "description": "Email body text (plain text)."],
                "cc": ["type": "string", "description": "Comma-separated CC addresses (optional)."]
            ],
            "required": ["to", "subject", "body"]
        ], strict: nil),
    ]
}

// MARK: - Tool Executor

private struct OpenRockyToolExecutor: ToolExecutor {
    let name: String

    var displayName: String {
        // Handle skill tools — derive readable name from the tool name suffix
        if name.hasPrefix("skill-") {
            let suffix = String(name.dropFirst(6))
            let skillName = suffix.split(separator: "-").map(\.capitalized).joined(separator: " ")
            return "Skill: \(skillName)"
        }
        return switch name {
        case "apple-location": "Location"
        case "apple-geocode": "Geocode"
        case "weather": "Weather"
        case "apple-alarm": "Alarm"
        case "memory_get": "Memory Read"
        case "memory_write": "Memory Write"
        case "apple-health-summary": "Health Summary"
        case "apple-health-metric": "Health Metric"
        case "shell-execute": "Shell"
        case "python-execute": "Python"
        case "ffmpeg-execute": "FFmpeg"
        case "browser-open": "Browser"
        case "browser-cookies": "Cookies"
        case "browser-read": "Read Page"
        case "oauth-authenticate": "OAuth"
        case "crypto": "Crypto"
        case "todo": "Todo"
        case "file-read": "File Read"
        case "file-write": "File Write"
        case "web-search": "Web Search"
        case "camera-capture": "Camera"
        case "photo-pick": "Photo Library"
        case "file-pick": "File Picker"
        case "apple-calendar-list": "Calendar"
        case "apple-calendar-create": "Create Event"
        case "apple-reminder-list": "Reminders"
        case "apple-reminder-create": "Create Reminder"
        case "apple-contacts-search": "Contacts"
        case "nearby-search": "Nearby"
        case "notification-schedule": "Notification"
        case "open-url": "Open URL"
        case "app-exit": "Exit App"
        case "email-send": "Send Email"
        case "icloud-read": "iCloud Read"
        case "icloud-list": "iCloud List"
        case "icloud-write": "iCloud Write"
        default: name
        }
    }

    var iconName: String {
        if name.hasPrefix("skill-") {
            return "sparkles"
        }
        return switch name {
        case "apple-location": "location.fill"
        case "apple-geocode": "map.fill"
        case "weather": "cloud.sun.fill"
        case "apple-alarm": "alarm.fill"
        case "memory_get": "brain.head.profile.fill"
        case "memory_write": "square.and.pencil"
        case "apple-health-summary": "heart.fill"
        case "apple-health-metric": "chart.bar.fill"
        case "shell-execute": "terminal.fill"
        case "python-execute": "chevron.left.forwardslash.chevron.right"
        case "ffmpeg-execute": "film.fill"
        case "browser-open": "safari.fill"
        case "browser-cookies": "key.fill"
        case "browser-read": "doc.richtext.fill"
        case "oauth-authenticate": "person.badge.key.fill"
        case "crypto": "lock.shield.fill"
        case "todo": "checklist"
        case "file-read": "doc.text.fill"
        case "file-write": "doc.badge.plus"
        case "web-search": "globe"
        case "camera-capture": "camera.fill"
        case "photo-pick": "photo.fill"
        case "file-pick": "doc.fill"
        case "apple-calendar-list": "calendar"
        case "apple-calendar-create": "calendar.badge.plus"
        case "apple-reminder-list": "list.bullet"
        case "apple-reminder-create": "plus.circle.fill"
        case "apple-contacts-search": "person.crop.circle.fill"
        case "nearby-search": "mappin.and.ellipse"
        case "notification-schedule": "bell.fill"
        case "open-url": "link"
        case "app-exit": "power"
        case "email-send": "envelope.fill"
        case "icloud-read": "icloud.fill"
        case "icloud-list": "icloud.and.arrow.down.fill"
        case "icloud-write": "icloud.and.arrow.up.fill"
        default: "wrench.fill"
        }
    }
}
