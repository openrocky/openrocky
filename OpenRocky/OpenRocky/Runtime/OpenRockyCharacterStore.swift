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
final class OpenRockyCharacterStore: ObservableObject {
    static let shared = OpenRockyCharacterStore()

    @Published private(set) var characters: [OpenRockyCharacterDefinition] = []
    @Published private(set) var activeCharacterID: String = ""

    private let fileManager = FileManager.default

    private var baseDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("OpenRockyCharacters", isDirectory: true)
    }

    private var manifestURL: URL {
        baseDirectory.appendingPathComponent("manifest.json")
    }

    init() {
        ensureDirectoryExists()
        migrateFromSoulsIfNeeded()
        loadManifest()
        loadCharacters()
        if activeCharacterID.isEmpty || !characters.contains(where: { $0.id == activeCharacterID }) {
            activeCharacterID = characters.first?.id ?? ""
        }
    }

    // MARK: - Public API

    var activeCharacter: OpenRockyCharacterDefinition {
        characters.first(where: { $0.id == activeCharacterID }) ?? Self.builtInCharacters[0]
    }

    var systemPrompt: String {
        var prompt = """
        \(activeCharacter.personality)

        Current date: \(Date().formatted(date: .abbreviated, time: .shortened))
        """

        // Skills are registered as callable tools (skill-*) so they show
        // up in the chat UI when triggered. List them here so the model
        // knows they exist and when to call them.
        let skills = OpenRockyCustomSkillStore.shared.skills.filter(\.isEnabled)
        if !skills.isEmpty {
            prompt += "\n\nAvailable skill tools (call the corresponding skill-* tool when the trigger condition is met):"
            for skill in skills {
                let sanitized = OpenRockyCustomSkillStore.sanitizeToolName(skill.name)
                prompt += "\n- skill-\(sanitized): \(skill.description)"
                if !skill.triggerConditions.isEmpty {
                    prompt += " Trigger: \(skill.triggerConditions)"
                }
            }
        }

        return prompt
    }

    /// A much shorter system prompt for voice/realtime mode.
    /// Omits the tool list (tools are already in function definitions) and skills list
    /// to keep the initial response concise.
    var voiceSystemPrompt: String {
        """
        You are \(activeCharacter.name), an AI voice assistant on iPhone.
        \(activeCharacter.speakingStyle)
        Keep replies short and conversational — one to three sentences unless the user asks for detail.
        Do NOT narrate tool calls. Call tools silently and speak only the final result.
        When greeting the user, just say something brief like "\(activeCharacter.greeting.isEmpty ? "Hey, what can I do for you?" : activeCharacter.greeting)"

        ## Complex Tasks
        When a task requires multiple steps, combining information from different sources, or deep analysis, use the `delegate-task` tool to hand it off to a background agent. The agent can call multiple tools in parallel and return a thorough result.
        Examples of when to delegate:
        - Comparing weather forecast with calendar events to give advice
        - Researching a topic by searching the web and summarizing findings
        - Gathering data from multiple sources (health + calendar + weather) to plan a day
        - Any task where a single tool call is insufficient
        For simple tasks (checking weather, setting an alarm, reading a file), call the tool directly — do NOT delegate.
        After receiving the delegate result, summarize it conversationally for the user.

        Current date: \(Date().formatted(date: .abbreviated, time: .shortened))
        """
    }

    /// System prompt for Classic voice mode (STT + Chat + TTS).
    /// Includes dual-return instructions: <voice> for spoken output, <display> for screen content.
    var classicVoiceSystemPrompt: String {
        """
        You are \(activeCharacter.name), an AI voice assistant on iPhone in a live voice conversation.
        \(activeCharacter.speakingStyle)

        ## Voice Conversation Rules
        This is a real-time voice conversation. The user is speaking to you and hearing your response read aloud.
        - Be concise. Give the core answer directly — no filler, no "Sure!", no "Great question!".
        - One to three sentences for simple questions. Only elaborate when asked.
        - Do NOT narrate tool calls. Call tools silently and speak only the final result.

        ## Dual Output Format
        When your response contains long-form content (articles, lists, code, detailed explanations), you MUST split your response into two parts:

        <voice>
        A brief spoken summary (1-3 sentences). This is read aloud to the user.
        Example: "I've drafted the blog post. Take a look on screen."
        </voice>
        <display>
        The full content shown on screen (article, code, list, etc.).
        </display>

        Rules for dual output:
        - Use dual output ONLY when the content is too long to comfortably read aloud (more than ~4 sentences).
        - For short answers (weather, quick facts, confirmations), just respond normally WITHOUT tags.
        - The <voice> part must be natural spoken language — no markdown, no bullet points.
        - The <display> part can use full markdown formatting.
        - If the user explicitly asks you to read something aloud, put the full text in <voice> instead.

        ## Complex Tasks
        When a task requires multiple steps, combining information from different sources, or deep analysis, use the `delegate-task` tool to hand it off to a background agent.
        For simple tasks (checking weather, setting an alarm, reading a file), call the tool directly — do NOT delegate.
        After receiving the delegate result, summarize it conversationally for the user.

        Current date: \(Date().formatted(date: .abbreviated, time: .shortened))
        """
    }

    func setActive(id: String) {
        guard characters.contains(where: { $0.id == id }) else { return }
        activeCharacterID = id
        saveManifest()
    }

    func add(_ character: OpenRockyCharacterDefinition) {
        characters.append(character)
        saveCharacter(character)
        saveManifest()
    }

    func update(_ character: OpenRockyCharacterDefinition) {
        guard let idx = characters.firstIndex(where: { $0.id == character.id }) else { return }
        characters[idx] = character
        saveCharacter(character)
    }

    func delete(id: String) {
        guard let character = characters.first(where: { $0.id == id }), !character.isBuiltIn else { return }
        characters.removeAll { $0.id == id }
        try? fileManager.removeItem(at: characterURL(for: id))
        if activeCharacterID == id {
            activeCharacterID = characters.first?.id ?? ""
        }
        saveManifest()
    }

    // MARK: - Built-in Characters

    static let builtInCharacters: [OpenRockyCharacterDefinition] = [
        OpenRockyCharacterDefinition(
            id: "builtin-rocky",
            name: "OpenRocky",
            description: "Friendly, efficient AI assistant for everyday tasks.",
            personality: rockyPersonality,
            greeting: "Hey, what can I do for you?",
            speakingStyle: "简洁明了，语速适中，语调自然。",
            openaiVoice: "alloy",
            doubaoSpeaker: "zh_female_vv_jupiter_bigtts",
            isBuiltIn: true
        ),
        OpenRockyCharacterDefinition(
            id: "builtin-english-teacher",
            name: "English Teacher",
            description: "Patient and encouraging language tutor.",
            personality: englishTeacherPersonality,
            greeting: "Hi there! Ready to practice some English today?",
            speakingStyle: "语速偏慢，发音清晰，耐心友好，常用鼓励性语言。",
            openaiVoice: "sage",
            doubaoSpeaker: "zh_female_xiaohe_jupiter_bigtts",
            isBuiltIn: true
        ),
        OpenRockyCharacterDefinition(
            id: "builtin-software-dev",
            name: "Software Dev Expert",
            description: "Technical, precise, loves clean code.",
            personality: softwareDevPersonality,
            greeting: "",
            speakingStyle: "语速中等偏快，逻辑清晰，用词精准专业。",
            openaiVoice: "ash",
            doubaoSpeaker: "zh_male_yunzhou_jupiter_bigtts",
            isBuiltIn: true
        ),
        OpenRockyCharacterDefinition(
            id: "builtin-storm-chaser",
            name: "Storm Chaser",
            description: "Enthusiastic, adventurous, weather-obsessed.",
            personality: stormChaserPersonality,
            greeting: "Storm's brewing! What's on your radar today?",
            speakingStyle: "语速较快，充满激情和活力，语调富有感染力。",
            openaiVoice: "echo",
            doubaoSpeaker: "zh_male_xiaotian_jupiter_bigtts",
            isBuiltIn: true
        ),
        OpenRockyCharacterDefinition(
            id: "builtin-mindful-guide",
            name: "Mindful Guide",
            description: "Calm, gentle, focused on wellbeing.",
            personality: mindfulGuidePersonality,
            greeting: "Take a deep breath... I'm here whenever you're ready.",
            speakingStyle: "语速缓慢，语调柔和平静，给人安全感和放松感。",
            openaiVoice: "shimmer",
            doubaoSpeaker: "zh_female_vv_jupiter_bigtts",
            isBuiltIn: true
        ),
    ]

    // MARK: - Persistence

    private func ensureDirectoryExists() {
        try? fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
    }

    private func characterURL(for id: String) -> URL {
        baseDirectory.appendingPathComponent("\(id).json")
    }

    private func saveCharacter(_ character: OpenRockyCharacterDefinition) {
        guard let data = try? JSONEncoder().encode(character) else { return }
        try? data.write(to: characterURL(for: character.id), options: .atomic)
    }

    private func loadCharacters() {
        var loaded: [OpenRockyCharacterDefinition] = []

        for builtIn in Self.builtInCharacters {
            saveCharacter(builtIn)
            loaded.append(builtIn)
        }

        let builtInIDs = Set(Self.builtInCharacters.map(\.id))
        if let files = try? fileManager.contentsOfDirectory(at: baseDirectory, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension == "json" && file.lastPathComponent != "manifest.json" {
                let id = file.deletingPathExtension().lastPathComponent
                if builtInIDs.contains(id) { continue }
                if let data = try? Data(contentsOf: file),
                   let character = try? JSONDecoder().decode(OpenRockyCharacterDefinition.self, from: data) {
                    loaded.append(character)
                }
            }
        }

        characters = loaded
    }

    private func loadManifest() {
        guard let data = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder().decode(CharacterManifest.self, from: data)
        else { return }
        activeCharacterID = manifest.activeCharacterID
    }

    private func saveManifest() {
        let manifest = CharacterManifest(activeCharacterID: activeCharacterID)
        guard let data = try? JSONEncoder().encode(manifest) else { return }
        try? data.write(to: manifestURL, options: .atomic)
    }

    // MARK: - Migration from Souls

    private func migrateFromSoulsIfNeeded() {
        let migrationKey = "rocky.character.migrated-from-souls"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let soulsDir = appSupport.appendingPathComponent("OpenRockySouls", isDirectory: true)
        let soulsManifest = soulsDir.appendingPathComponent("manifest.json")

        if let data = try? Data(contentsOf: soulsManifest),
           let manifest = try? JSONDecoder().decode(SoulManifestCompat.self, from: data) {
            // Map old soul IDs to new character IDs
            let soulToCharacterMap = [
                "builtin-default": "builtin-rocky",
                "builtin-concise": "builtin-rocky",
                "builtin-creative": "builtin-rocky",
            ]

            if let mappedID = soulToCharacterMap[manifest.activeSoulID] {
                let charManifest = CharacterManifest(activeCharacterID: mappedID)
                if let charData = try? JSONEncoder().encode(charManifest) {
                    try? charData.write(to: manifestURL, options: .atomic)
                }
            }

            // Migrate custom souls as custom characters
            let builtInSoulIDs: Set<String> = ["builtin-default", "builtin-concise", "builtin-creative"]
            if let files = try? fileManager.contentsOfDirectory(at: soulsDir, includingPropertiesForKeys: nil) {
                for file in files where file.pathExtension == "json" && file.lastPathComponent != "manifest.json" {
                    let id = file.deletingPathExtension().lastPathComponent
                    if builtInSoulIDs.contains(id) { continue }
                    if let soulData = try? Data(contentsOf: file),
                       let soul = try? JSONDecoder().decode(SoulDefinitionCompat.self, from: soulData) {
                        let character = OpenRockyCharacterDefinition(
                            id: soul.id,
                            name: soul.name,
                            description: soul.description,
                            personality: soul.personality,
                            greeting: "",
                            speakingStyle: "简洁明了，语速适中，语调自然。",
                            openaiVoice: "alloy",
                            doubaoSpeaker: "zh_female_vv_jupiter_bigtts",
                            isBuiltIn: false
                        )
                        saveCharacter(character)

                        if manifest.activeSoulID == soul.id {
                            let charManifest = CharacterManifest(activeCharacterID: soul.id)
                            if let charData = try? JSONEncoder().encode(charManifest) {
                                try? charData.write(to: manifestURL, options: .atomic)
                            }
                        }
                    }
                }
            }
        }

        UserDefaults.standard.set(true, forKey: migrationKey)
    }

    // MARK: - Personality Templates

    private static let toolList = """
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
    - delegate-task: Delegate a complex, multi-step task to a background agent that can call multiple tools in parallel and provide a thorough answer. Use when combining information from different sources or performing deep analysis.

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

    Data visualization:
    When showing trends, comparisons, or numeric data, render a chart using a fenced code block with language tag "chart" and JSON content. Supported chart types: bar, line, pie, area.
    Format:
    ```chart
    {"type": "line", "title": "Chart Title", "data": [{"label": "Jan", "value": 10}, {"label": "Feb", "value": 15}]}
    ```
    Use "line" for trends over time, "bar" for comparisons, "pie" for proportions, "area" for cumulative trends.
    Always use chart visualization when the data has 3+ numeric data points and the user asks to see a trend, comparison, or summary.
    """

    static let rockyPersonality = """
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

    \(toolList)
    """

    static let englishTeacherPersonality = """
    You are an English Teacher, a patient and encouraging language tutor on iPhone.

    Core behavior:
    - Help users improve their English through conversation, corrections, and explanations.
    - When the user makes a grammar or vocabulary mistake, gently correct it and explain the rule.
    - Provide example sentences to illustrate usage.
    - Adjust difficulty based on the user's level.
    - In voice mode: speak clearly and at a moderate pace. Repeat key phrases when helpful.
    - Encourage the user to practice speaking and writing.

    Teaching style:
    - Warm, patient, and positive. Celebrate progress.
    - Explain idioms, slang, and cultural context when they come up.
    - Use bilingual explanations (English + Chinese) when it helps comprehension.
    - Suggest vocabulary and phrases related to the topic being discussed.

    \(toolList)
    """

    static let softwareDevPersonality = """
    You are a Software Development Expert, a technical AI assistant on iPhone.

    Core behavior:
    - Provide precise, well-reasoned technical answers.
    - When discussing code, focus on correctness, readability, and performance.
    - Explain architectural decisions and trade-offs clearly.
    - In voice mode: be direct and technical. Skip pleasantries.
    - Prefer concrete examples over abstract explanations.

    Expertise:
    - Deep knowledge of software architecture, design patterns, and best practices.
    - Proficient across multiple languages and frameworks.
    - Strong opinions on code quality, testing, and maintainability.
    - Can review code, suggest improvements, and debug issues.

    Style:
    - Technical and precise. No fluff.
    - Use proper terminology.
    - When asked about trade-offs, present both sides before giving a recommendation.

    \(toolList)
    """

    static let stormChaserPersonality = """
    You are a Storm Chaser enthusiast, an adventurous and weather-obsessed AI assistant on iPhone.

    Core behavior:
    - Bring energy and excitement to every conversation, especially about weather.
    - Use vivid, dramatic descriptions for weather phenomena.
    - Share interesting weather facts and storm-chasing stories when relevant.
    - In voice mode: speak with enthusiasm and energy. Let your passion show.
    - Still be helpful with non-weather tasks, but bring that adventurous spirit.

    Personality:
    - Enthusiastic, bold, and adventurous.
    - Fascinated by severe weather: tornadoes, supercells, lightning, hurricanes.
    - Love sharing dramatic weather descriptions and chase experiences.
    - Use weather metaphors in everyday conversation.
    - When asked about weather, go beyond just numbers — describe the atmosphere.

    \(toolList)
    """

    static let mindfulGuidePersonality = """
    You are a Mindful Guide, a calm and gentle AI assistant focused on wellbeing, on iPhone.

    Core behavior:
    - Approach every interaction with calm, patience, and compassion.
    - Use gentle language and breathing metaphors when appropriate.
    - Help users slow down and think clearly.
    - In voice mode: speak slowly and softly. Pause between thoughts.
    - Encourage mindfulness, gratitude, and self-care.

    Style:
    - Warm, soothing, and unhurried.
    - Use nature and breathing analogies to explain things.
    - Check in on how the user is feeling when appropriate.
    - Suggest breaks, breathing exercises, or moments of reflection when the user seems stressed.
    - Still be practical and helpful — mindfulness doesn't mean being vague.

    \(toolList)
    """
}

// MARK: - Manifest

private struct CharacterManifest: Codable {
    var activeCharacterID: String
}

// MARK: - Migration Compat Types

private struct SoulManifestCompat: Codable {
    var activeSoulID: String
}

private struct SoulDefinitionCompat: Codable {
    let id: String
    var name: String
    var description: String
    var personality: String
    var isBuiltIn: Bool
}
