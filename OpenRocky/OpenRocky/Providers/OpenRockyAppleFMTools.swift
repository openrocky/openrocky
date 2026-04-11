//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-04-10
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels

// MARK: - Generic Tool Input

/// A generic input type for the tool dispatcher.
/// The on-device model generates a tool name and JSON arguments string.
@available(iOS 26.0, *)
@Generable
struct OpenRockyFMToolInput {
    /// The name of the tool to execute
    var toolName: String
    /// JSON object string with arguments for the tool, e.g. {"query":"tokyo"}. Use {} if no arguments needed.
    var arguments: String
}

// MARK: - Tool Dispatcher

/// A single FoundationModels Tool that dispatches to any OpenRocky tool by name.
/// This bridges the existing OpenRockyToolbox to Apple's native tool calling protocol,
/// so the on-device model can call tools through the standard FM tool loop.
@available(iOS 26.0, *)
struct OpenRockyFMToolDispatcher: Tool {
    typealias Arguments = OpenRockyFMToolInput
    typealias Output = String

    let description = """
        Execute a device tool by name. Available tools and their arguments:
        apple-location: Get current GPS (no args)
        weather: Get forecast (latitude:Number, longitude:Number, label:String — all optional)
        apple-geocode: Address to coordinates (address:String)
        apple-contacts-search: Find contacts (query:String)
        apple-calendar-list: List events (startDate:String, endDate:String — ISO8601)
        apple-calendar-create: Create event (title:String, startDate:String, endDate:String, notes:String)
        apple-reminder-list: List reminders (no args)
        apple-reminder-create: Create reminder (title:String, dueDate:String, notes:String)
        web-search: Search the web (query:String)
        browser-read: Read a URL (url:String)
        todo: Manage todos (action:String[add/list/complete/delete], title:String, id:String)
        notification-schedule: Set notification (title:String, body:String, delaySeconds:Number)
        apple-health-summary: Health data summary (no args)
        open-url: Open a URL (url:String)
        memory_get: Read memory (key:String)
        memory_write: Write memory (key:String, value:String)
        """

    func call(arguments input: OpenRockyFMToolInput) async throws -> String {
        let toolbox = await OpenRockyToolbox()
        let args = Self.normalizeArguments(input.arguments, forTool: input.toolName)
        return try await toolbox.execute(name: input.toolName, arguments: args)
    }

    /// Ensure arguments is a valid JSON object string.
    /// If the model passes a raw string instead of JSON, wrap it in a
    /// reasonable JSON object based on the tool name.
    private static func normalizeArguments(_ raw: String, forTool tool: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // Already valid JSON object
        if trimmed.hasPrefix("{"),
           let data = trimmed.data(using: .utf8),
           (try? JSONSerialization.jsonObject(with: data)) != nil {
            return trimmed
        }

        // Empty or "{}" equivalent
        if trimmed.isEmpty || trimmed == "{}" {
            return "{}"
        }

        // Raw string — wrap in a sensible key based on tool name
        let key: String
        switch tool {
        case "weather", "apple-geocode":
            key = "address"
        case "web-search", "apple-contacts-search":
            key = "query"
        case "browser-read", "open-url":
            key = "url"
        case "shell-execute":
            key = "command"
        case "memory_get", "memory_write":
            key = "key"
        default:
            key = "query"
        }

        // Escape the string for JSON
        if let data = try? JSONSerialization.data(withJSONObject: [key: trimmed]),
           let json = String(data: data, encoding: .utf8) {
            return json
        }
        return "{}"
    }
}

#endif
