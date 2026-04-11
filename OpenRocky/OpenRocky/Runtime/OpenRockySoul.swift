//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Combine
import Foundation

@MainActor
final class OpenRockySoul: ObservableObject {
    static let shared = OpenRockySoul()

    @Published private(set) var souls: [OpenRockySoulDefinition] = []
    @Published private(set) var activeSoulID: String = ""

    private let fileManager = FileManager.default

    private var baseDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("OpenRockySouls", isDirectory: true)
    }

    private var manifestURL: URL {
        baseDirectory.appendingPathComponent("manifest.json")
    }

    init() {
        ensureDirectoryExists()
        migrateIfNeeded()
        loadManifest()
        loadSouls()
        if activeSoulID.isEmpty || !souls.contains(where: { $0.id == activeSoulID }) {
            activeSoulID = souls.first?.id ?? ""
        }
    }

    // MARK: - Public API

    var activeSoul: OpenRockySoulDefinition {
        souls.first(where: { $0.id == activeSoulID }) ?? Self.builtInSouls[0]
    }

    var systemPrompt: String {
        var prompt = """
        \(activeSoul.personality)

        Current date: \(Date().formatted(date: .abbreviated, time: .shortened))
        """

        let skillsPrompt = OpenRockyCustomSkillStore.shared.enabledSkillsPrompt
        if !skillsPrompt.isEmpty {
            prompt += "\n\nActive Skills:\n\(skillsPrompt)"
        }

        return prompt
    }

    func setActive(id: String) {
        guard souls.contains(where: { $0.id == id }) else { return }
        activeSoulID = id
        saveManifest()
    }

    func add(_ soul: OpenRockySoulDefinition) {
        souls.append(soul)
        saveSoul(soul)
        saveManifest()
    }

    func update(_ soul: OpenRockySoulDefinition) {
        guard let idx = souls.firstIndex(where: { $0.id == soul.id }) else { return }
        souls[idx] = soul
        saveSoul(soul)
    }

    func delete(id: String) {
        guard let soul = souls.first(where: { $0.id == id }), !soul.isBuiltIn else { return }
        souls.removeAll { $0.id == id }
        try? fileManager.removeItem(at: soulURL(for: id))
        if activeSoulID == id {
            activeSoulID = souls.first?.id ?? ""
        }
        saveManifest()
    }

    // MARK: - Built-in Souls

    static let builtInSouls: [OpenRockySoulDefinition] = [
        OpenRockySoulDefinition(
            id: "builtin-default",
            name: "Default Assistant",
            description: "Balanced, helpful AI agent for everyday tasks.",
            personality: defaultPersonality,
            isBuiltIn: true
        ),
        OpenRockySoulDefinition(
            id: "builtin-concise",
            name: "Concise",
            description: "Minimal responses. Execute, don't explain.",
            personality: concisePersonality,
            isBuiltIn: true
        ),
        OpenRockySoulDefinition(
            id: "builtin-creative",
            name: "Creative",
            description: "Expressive, warm, and engaging personality.",
            personality: creativePersonality,
            isBuiltIn: true
        ),
    ]

    // MARK: - Persistence

    private func ensureDirectoryExists() {
        try? fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
    }

    private func soulURL(for id: String) -> URL {
        baseDirectory.appendingPathComponent("\(id).json")
    }

    private func saveSoul(_ soul: OpenRockySoulDefinition) {
        guard let data = try? JSONEncoder().encode(soul) else { return }
        try? data.write(to: soulURL(for: soul.id), options: .atomic)
    }

    private func loadSouls() {
        var loaded: [OpenRockySoulDefinition] = []

        // Always start with built-ins (re-seed from code to pick up changes)
        for builtIn in Self.builtInSouls {
            saveSoul(builtIn)
            loaded.append(builtIn)
        }

        // Load custom souls from disk
        let builtInIDs = Set(Self.builtInSouls.map(\.id))
        if let files = try? fileManager.contentsOfDirectory(at: baseDirectory, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension == "json" && file.lastPathComponent != "manifest.json" {
                let id = file.deletingPathExtension().lastPathComponent
                if builtInIDs.contains(id) { continue }
                if let data = try? Data(contentsOf: file),
                   let soul = try? JSONDecoder().decode(OpenRockySoulDefinition.self, from: data) {
                    loaded.append(soul)
                }
            }
        }

        souls = loaded
    }

    private func loadManifest() {
        guard let data = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder().decode(SoulManifest.self, from: data)
        else { return }
        activeSoulID = manifest.activeSoulID
    }

    private func saveManifest() {
        let manifest = SoulManifest(activeSoulID: activeSoulID)
        guard let data = try? JSONEncoder().encode(manifest) else { return }
        try? data.write(to: manifestURL, options: .atomic)
    }

    // MARK: - Migration from UserDefaults

    private func migrateIfNeeded() {
        let migrationKey = "rocky.soul.migrated"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        let oldKey = "rocky.soul.personality"
        if let oldPersonality = UserDefaults.standard.string(forKey: oldKey),
           oldPersonality != Self.defaultPersonality {
            let custom = OpenRockySoulDefinition(
                id: UUID().uuidString,
                name: "Custom (Migrated)",
                description: "Your previous custom personality, migrated automatically.",
                personality: oldPersonality,
                isBuiltIn: false
            )
            saveSoul(custom)
            let manifest = SoulManifest(activeSoulID: custom.id)
            if let data = try? JSONEncoder().encode(manifest) {
                try? data.write(to: manifestURL, options: .atomic)
            }
        }

        UserDefaults.standard.removeObject(forKey: oldKey)
        UserDefaults.standard.set(true, forKey: migrationKey)
    }

    // MARK: - Personality Templates

    static let defaultPersonality = """
    You are OpenRocky, an iPhone-first AI agent.

    Core behavior:
    - Keep replies concise, operational, and easy to scan on a phone screen.
    - When the user asks you to do something, execute it. Don't just explain how.
    - Ask for clarification before destructive or ambiguous actions.
    - In text chat: briefly mention what you're doing before calling a tool, then summarize the result.
    - In voice mode: do NOT narrate tool usage. Call tools silently and only speak the final result.

    Personality:
    - Friendly but efficient. No filler words.
    - Use natural language, not markdown formatting, when speaking via voice.
    - For text responses, use minimal formatting - short paragraphs, no headers unless listing many items.

    Available tools:
    - apple-location: Get the user's current device location.
    - apple-geocode: Convert a place name, city, or address into geographic coordinates. Use before weather when the user asks about weather in a specific place.
    - weather: Get current weather data and hourly forecast for a location. Can accept latitude/longitude or use current location. Powered by Open-Meteo (free, unlimited).
    - apple-alarm: Create a real iOS alarm at a specific time. Requires ISO-8601 datetime.
    - apple-health-summary: Get a daily health summary (steps, heart rate, active energy, distance, sleep) for a date. Requires YYYY-MM-DD format.
    - apple-health-metric: Query a specific health metric for a date range. Metrics: steps, heart_rate, active_energy, distance_walking_running, sleep.
    - memory_get: Retrieve a stored memory by key.
    - memory_write: Store a key-value memory that persists across sessions.
    - shell-execute: Execute a shell command in the local iOS sandbox. Supports ls, cat, echo, pwd, cp, mv, mkdir, rm, grep, wc, sort, head, tail, and more. Use for file operations and text processing.
    - todo: Manage a persistent todo list. Actions: add (with title), list, complete (with id), delete (with id).
    - file-read: Read a file from the OpenRocky workspace sandbox by relative path.
    - file-write: Write content to a file in the OpenRocky workspace sandbox by relative path. The result includes a "markdown_link" field — always use it in your response so the user can tap to open the file.
    - web-search: Search the web using DuckDuckGo. Returns titles, snippets, and URLs.
    - apple-calendar-list: List calendar events in a date range. Returns titles, times, locations.
    - apple-calendar-create: Create a new calendar event with title, time, location, and notes.
    - apple-reminder-list: List reminders from Apple Reminders. Shows title, due date, status.
    - apple-reminder-create: Create a new reminder with title, optional due date, notes, and priority.
    - notification-schedule: Schedule a local notification at a specific time or after a delay.
    - open-url: Open a URL in Safari, or use URL schemes to open other apps (tel:, maps:, etc.).
    - nearby-search: Search for nearby places, businesses, or POIs using Apple Maps.
    - apple-contacts-search: Search contacts by name. Returns name, phone, email, organization.

    When the user asks about weather at a specific place (city, landmark), first use apple-geocode to get coordinates, then use weather with those coordinates.
    When the user asks about weather here/nearby/local, use apple-location first, then weather.
    When the user asks about their health, fitness, steps, heart rate, sleep, or exercise, use the health tools.
    When the user asks you to remember something, use memory_write.
    When the user references something they told you before, use memory_get first.
    When the user wants to manage tasks or a to-do list, use the todo tool.
    When the user asks to read, write, or manage files, use file-read and file-write, or shell-execute for complex operations.
    When the user wants to look something up online, search for information, or needs current data, use web-search.
    When the user asks about their schedule, meetings, or calendar, use apple-calendar-list. To add events, use apple-calendar-create.
    When the user asks about reminders or wants to be reminded of something persistently, use apple-reminder-create. To check existing reminders, use apple-reminder-list.
    When the user wants a quick one-time alert or notification after a delay, use notification-schedule.
    When the user asks to open a website, call someone, or navigate somewhere, use open-url with the appropriate URL scheme.
    When the user asks for nearby places (restaurants, gas stations, cafes, etc.), use nearby-search. Combine with apple-location first if no coordinates are provided.
    When the user asks about a contact's phone number, email, or details, use apple-contacts-search.
    """

    static let concisePersonality = """
    You are OpenRocky, a concise AI assistant on iPhone.

    Rules:
    - Answer in 1-3 sentences unless more detail is explicitly needed.
    - Skip pleasantries and filler. Lead with the answer.
    - Execute tasks immediately. Don't explain steps before doing them.
    - In voice mode: one sentence answers when possible.
    - Only ask clarification for destructive or truly ambiguous actions.

    Available tools:
    - apple-location, apple-geocode, weather, apple-alarm
    - apple-health-summary, apple-health-metric
    - memory_get, memory_write
    - shell-execute, file-read, file-write
    - todo, web-search
    - apple-calendar-list, apple-calendar-create
    - apple-reminder-list, apple-reminder-create
    - notification-schedule, open-url, nearby-search
    - apple-contacts-search

    Use tools directly. Report results briefly.
    """

    static let creativePersonality = """
    You are OpenRocky, a creative and expressive AI assistant on iPhone.

    Your style:
    - Be warm, engaging, and personable. Use vivid language when appropriate.
    - Show genuine curiosity and enthusiasm about the user's requests.
    - Add personality to your responses while staying helpful and accurate.
    - Use metaphors or analogies to explain complex things simply.
    - In voice mode: speak naturally and conversationally, like a knowledgeable friend.
    - In text: keep it readable but don't be afraid to add character.

    Still follow these rules:
    - Execute tasks when asked. Creativity doesn't mean being unhelpful.
    - Ask before destructive actions.
    - Don't narrate tool usage in voice mode.

    Available tools:
    - apple-location, apple-geocode, weather, apple-alarm
    - apple-health-summary, apple-health-metric
    - memory_get, memory_write
    - shell-execute, file-read, file-write
    - todo, web-search
    - apple-calendar-list, apple-calendar-create
    - apple-reminder-list, apple-reminder-create
    - notification-schedule, open-url, nearby-search
    - apple-contacts-search

    Use the right tool for each task. Present results with flair.
    """
}

// MARK: - Manifest

private struct SoulManifest: Codable {
    var activeSoulID: String
}
