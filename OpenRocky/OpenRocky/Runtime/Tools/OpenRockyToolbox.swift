//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import CoreLocation
import FFmpegSupport
import Foundation
import HealthKit
#if !targetEnvironment(simulator)
import OpenRockyPython
#endif
@preconcurrency import SwiftOpenAI

@MainActor
final class OpenRockyToolbox {
    private let locationService = OpenRockyLocationService()
    private let weatherService = OpenRockyWeatherService()
    private let memoryService = OpenRockyMemoryService.shared
    private let healthService = OpenRockyHealthService.shared
    private let todoService = OpenRockyTodoService.shared
    private let shellRuntime = OpenRockyShellRuntime.shared
    private let alarmService: OpenRockyAlarmService?
    private let calendarService = OpenRockyCalendarService.shared
    private let reminderService = OpenRockyReminderService.shared
    private let notificationService = OpenRockyNotificationService.shared
    private let contactsService = OpenRockyContactsService.shared
    private let nearbySearchService = OpenRockyNearbySearchService.shared
    private let urlService = OpenRockyURLService.shared

    /// Chat provider configuration for subagent execution. Set by the session runtime.
    var subagentChatConfiguration: OpenRockyProviderConfiguration?
    /// Callback for subagent status updates (forwarded to session runtime's statusText).
    var subagentStatusHandler: (@MainActor (String) -> Void)?

    init() {
        if #available(iOS 26.0, *) {
            alarmService = OpenRockyAlarmService()
        } else {
            alarmService = nil
        }
    }

    // MARK: - Realtime Tool Definitions

    nonisolated static func realtimeToolDefinitions() -> [OpenAIRealtimeSessionConfiguration.RealtimeTool] {
        [
            .function(
                .init(
                    name: "apple-location",
                    description: "Get the user's current Apple device location. Use this before weather if the user asked about here, local weather, or current conditions.",
                    parameters: [
                        "type": "object",
                        "properties": [:]
                    ]
                )
            ),
            .function(
                .init(
                    name: "apple-geocode",
                    description: "Convert a place name or address into geographic coordinates. Use this when the user mentions a specific city, address, or landmark to get its latitude and longitude before calling weather.",
                    parameters: [
                        "type": "object",
                        "properties": [
                            "address": [
                                "type": "string",
                                "description": "The place name, city, or address to look up (e.g. 'San Francisco', '东京', 'Eiffel Tower')."
                            ]
                        ],
                        "required": ["address"]
                    ]
                )
            ),
            .function(
                .init(
                    name: "weather",
                    description: "Get current weather data and hourly forecast for the current location or provided coordinates. Uses Open-Meteo (free, no API key).",
                    parameters: [
                        "type": "object",
                        "properties": [
                            "latitude": [
                                "type": "number",
                                "description": "Optional latitude. Omit to use the device's current location."
                            ],
                            "longitude": [
                                "type": "number",
                                "description": "Optional longitude. Omit to use the device's current location."
                            ],
                            "label": [
                                "type": "string",
                                "description": "Optional location label to mention in the result."
                            ]
                        ]
                    ]
                )
            ),
            .function(
                .init(
                    name: "apple-alarm",
                    description: "Create a real Apple alarm at one exact ISO-8601 datetime. Use this only after the user gave a precise time.",
                    parameters: [
                        "type": "object",
                        "properties": [
                            "title": [
                                "type": "string",
                                "description": "Short label for the alarm."
                            ],
                            "scheduled_at": [
                                "type": "string",
                                "description": "Exact ISO-8601 date-time for the alarm in the user's local timezone."
                            ]
                        ],
                        "required": ["scheduled_at"]
                    ]
                )
            ),
            .function(
                .init(
                    name: "memory_get",
                    description: "Retrieve a stored memory by key. Use when the user references something they told you before.",
                    parameters: [
                        "type": "object",
                        "properties": [
                            "key": [
                                "type": "string",
                                "description": "The memory key to look up."
                            ]
                        ],
                        "required": ["key"]
                    ]
                )
            ),
            .function(
                .init(
                    name: "memory_write",
                    description: "Store a key-value memory that persists across sessions. Use when the user explicitly asks you to remember something.",
                    parameters: [
                        "type": "object",
                        "properties": [
                            "key": [
                                "type": "string",
                                "description": "Short descriptive key for the memory."
                            ],
                            "value": [
                                "type": "string",
                                "description": "The value to store."
                            ]
                        ],
                        "required": ["key", "value"]
                    ]
                )
            ),
            .function(
                .init(
                    name: "apple-health-summary",
                    description: "Get a daily health summary including steps, active energy, heart rate, distance, and sleep for a given date.",
                    parameters: [
                        "type": "object",
                        "properties": [
                            "date": [
                                "type": "string",
                                "description": "The date in YYYY-MM-DD format."
                            ]
                        ],
                        "required": ["date"]
                    ]
                )
            ),
            .function(
                .init(
                    name: "apple-health-metric",
                    description: "Query a specific health metric from HealthKit for a date range. Supported metrics: steps, heart_rate, active_energy, distance_walking_running, sleep.",
                    parameters: [
                        "type": "object",
                        "properties": [
                            "metric": [
                                "type": "string",
                                "description": "The health metric: steps, heart_rate, active_energy, distance_walking_running, or sleep."
                            ],
                            "start_date": [
                                "type": "string",
                                "description": "Start date in YYYY-MM-DD format."
                            ],
                            "end_date": [
                                "type": "string",
                                "description": "End date in YYYY-MM-DD format."
                            ]
                        ],
                        "required": ["metric", "start_date", "end_date"]
                    ]
                )
            ),
            .function(
                .init(
                    name: "shell-execute",
                    description: "Execute a shell command in the local iOS sandbox. Supports Unix commands (ls, cat, echo, pwd, cp, mv, mkdir, rm, grep, wc, sort, head, tail, curl, ssh, tar, etc.) and network tools (ping, nslookup, dig, host, whois, nc, telnet). Use this for file operations, text processing, network diagnostics, or exploring the workspace.",
                    parameters: [
                        "type": "object",
                        "properties": [
                            "command": [
                                "type": "string",
                                "description": "The shell command to execute (e.g. 'ls -la', 'cat file.txt', 'ping google.com', 'dig example.com', 'curl -I https://example.com')."
                            ]
                        ],
                        "required": ["command"]
                    ]
                )
            ),
            .function(
                .init(
                    name: "python-execute",
                    description: "Execute Python 3.13 code directly on the device. Use this for calculations, data processing, text manipulation, algorithms, generating files, or any task that benefits from a programming language. The code runs in an embedded CPython interpreter with access to the full standard library (json, math, re, datetime, collections, itertools, csv, urllib, etc.). Print output to return results to the user.",
                    parameters: [
                        "type": "object",
                        "properties": [
                            "code": [
                                "type": "string",
                                "description": "Python source code to execute. Use print() to produce output."
                            ]
                        ],
                        "required": ["code"]
                    ]
                )
            ),
            .function(
                .init(
                    name: "ffmpeg-execute",
                    description: "Run an FFmpeg command on the device for audio/video processing. Supports merging audio+video streams, extracting audio, transcoding, trimming, generating thumbnails, creating GIFs, and more. Provide arguments as you would on the command line (without the leading 'ffmpeg'). Files are relative to the workspace.",
                    parameters: [
                        "type": "object",
                        "properties": [
                            "args": [
                                "type": "string",
                                "description": "FFmpeg arguments (e.g. '-i input.mp4 -vn -c:a copy output.m4a'). Do NOT include 'ffmpeg' itself."
                            ]
                        ],
                        "required": ["args"]
                    ]
                )
            ),
            .function(
                .init(
                    name: "browser-open",
                    description: "Open a URL in the built-in browser. The user can interact with the page (e.g. login to a website). When the user taps Done, returns the final URL and page title. Use this when the user needs to login to a service to obtain cookies/credentials for API access.",
                    parameters: [
                        "type": "object",
                        "properties": [
                            "url": [
                                "type": "string",
                                "description": "The URL to open (e.g. 'https://x.com', 'https://bilibili.com')."
                            ]
                        ],
                        "required": ["url"]
                    ]
                )
            ),
            .function(
                .init(
                    name: "browser-cookies",
                    description: "Get browser cookies for a specific domain. Use after browser-open to extract authentication cookies (e.g. session tokens, CSRF tokens) for API access. Returns cookie names and values as JSON.",
                    parameters: [
                        "type": "object",
                        "properties": [
                            "domain": [
                                "type": "string",
                                "description": "The domain to get cookies for (e.g. 'x.com', 'bilibili.com', '.weibo.com')."
                            ]
                        ],
                        "required": ["domain"]
                    ]
                )
            ),
            .function(
                .init(
                    name: "browser-read",
                    description: "Fetch a URL and extract the main text content from the page. Uses a real browser engine (WKWebView) so JavaScript-rendered content is included. Returns page title, URL, and extracted text. For static pages, prefer shell-execute with curl for speed.",
                    parameters: [
                        "type": "object",
                        "properties": [
                            "url": [
                                "type": "string",
                                "description": "The URL to read content from."
                            ]
                        ],
                        "required": ["url"]
                    ]
                )
            ),
            .function(
                .init(
                    name: "oauth-authenticate",
                    description: "Start an OAuth authentication flow. Opens a system browser sheet for the user to login and authorize. Returns the callback URL with tokens/codes. Use this for services that require OAuth (Spotify, GitHub, Google, etc.).",
                    parameters: [
                        "type": "object",
                        "properties": [
                            "auth_url": [
                                "type": "string",
                                "description": "The full OAuth authorization URL (e.g. 'https://accounts.spotify.com/authorize?client_id=...&redirect_uri=...')."
                            ],
                            "callback_scheme": [
                                "type": "string",
                                "description": "The URL scheme for the callback (e.g. 'rocky-oauth', 'myapp'). The redirect_uri should use this scheme."
                            ]
                        ],
                        "required": ["auth_url", "callback_scheme"]
                    ]
                )
            ),
            .function(
                .init(
                    name: "crypto",
                    description: "Perform cryptographic operations: HMAC-SHA256, SHA256 hash, MD5 hash, AES-128-CBC encrypt/decrypt, base64 encode/decode. Use this when a skill or API requires signing requests, generating tokens, or encrypting data.",
                    parameters: [
                        "type": "object",
                        "properties": [
                            "operation": [
                                "type": "string",
                                "description": "Operation: hmac_sha256, sha256, md5, aes_encrypt, aes_decrypt, base64_encode, base64_decode."
                            ],
                            "data": [
                                "type": "string",
                                "description": "The input data (text or hex-encoded for binary)."
                            ],
                            "key": [
                                "type": "string",
                                "description": "Key for HMAC or AES operations (hex-encoded)."
                            ],
                            "iv": [
                                "type": "string",
                                "description": "Initialization vector for AES-CBC (hex-encoded, 16 bytes)."
                            ]
                        ],
                        "required": ["operation", "data"]
                    ]
                )
            ),
            .function(
                .init(
                    name: "todo",
                    description: "Manage a persistent todo list. Actions: 'add' (create a new item), 'list' (show all items), 'complete' (mark done by id), 'delete' (remove by id).",
                    parameters: [
                        "type": "object",
                        "properties": [
                            "action": [
                                "type": "string",
                                "description": "The action: add, list, complete, or delete."
                            ],
                            "title": [
                                "type": "string",
                                "description": "Title for the new todo item (required for 'add')."
                            ],
                            "id": [
                                "type": "string",
                                "description": "The UUID of the item (required for 'complete' and 'delete')."
                            ]
                        ],
                        "required": ["action"]
                    ]
                )
            ),
            .function(
                .init(
                    name: "file-read",
                    description: "Read a file from the OpenRocky workspace sandbox. Returns the file content as text.",
                    parameters: [
                        "type": "object",
                        "properties": [
                            "path": [
                                "type": "string",
                                "description": "The relative file path within the workspace (e.g. 'notes.txt', 'data/config.json')."
                            ]
                        ],
                        "required": ["path"]
                    ]
                )
            ),
            .function(
                .init(
                    name: "file-write",
                    description: "Write content to a file in the OpenRocky workspace sandbox. Creates the file if it doesn't exist, overwrites if it does.",
                    parameters: [
                        "type": "object",
                        "properties": [
                            "path": [
                                "type": "string",
                                "description": "The relative file path within the workspace (e.g. 'notes.txt', 'data/output.json')."
                            ],
                            "content": [
                                "type": "string",
                                "description": "The text content to write to the file."
                            ]
                        ],
                        "required": ["path", "content"]
                    ]
                )
            ),
            .function(
                .init(
                    name: "web-search",
                    description: "Search the web using DuckDuckGo. Returns relevant results with titles, text snippets, and URLs.",
                    parameters: [
                        "type": "object",
                        "properties": [
                            "query": [
                                "type": "string",
                                "description": "The search query (e.g. 'Swift concurrency tutorial', '今天新闻')."
                            ]
                        ],
                        "required": ["query"]
                    ]
                )
            ),
            .function(
                .init(
                    name: "apple-calendar-list",
                    description: "List calendar events in a date range. Returns titles, times, locations.",
                    parameters: [
                        "type": "object",
                        "properties": [
                            "start_date": [
                                "type": "string",
                                "description": "Start date in YYYY-MM-DD format."
                            ],
                            "end_date": [
                                "type": "string",
                                "description": "End date in YYYY-MM-DD format."
                            ]
                        ],
                        "required": ["start_date", "end_date"]
                    ]
                )
            ),
            .function(
                .init(
                    name: "apple-calendar-create",
                    description: "Create a new calendar event. Provide title, start time (ISO-8601), optional end time, location, and notes.",
                    parameters: [
                        "type": "object",
                        "properties": [
                            "title": ["type": "string", "description": "Event title."],
                            "start_date": ["type": "string", "description": "Start datetime in ISO-8601 format."],
                            "end_date": ["type": "string", "description": "Optional end datetime in ISO-8601 format. Defaults to 1 hour after start."],
                            "all_day": ["type": "boolean", "description": "Whether this is an all-day event."],
                            "location": ["type": "string", "description": "Optional event location."],
                            "notes": ["type": "string", "description": "Optional notes."]
                        ],
                        "required": ["title", "start_date"]
                    ]
                )
            ),
            .function(
                .init(
                    name: "apple-reminder-list",
                    description: "List reminders from Apple Reminders app. Shows title, due date, completion status.",
                    parameters: [
                        "type": "object",
                        "properties": [
                            "include_completed": [
                                "type": "boolean",
                                "description": "Whether to include completed reminders. Defaults to false."
                            ]
                        ]
                    ]
                )
            ),
            .function(
                .init(
                    name: "apple-reminder-create",
                    description: "Create a new reminder in Apple Reminders. Always include due_date when the user mentions a time or deadline.",
                    parameters: [
                        "type": "object",
                        "properties": [
                            "title": ["type": "string", "description": "Reminder title."],
                            "due_date": ["type": "string", "description": "Due date and time in ISO-8601 format (e.g. 2025-04-05T14:00:00). Always set this when user specifies a time."],
                            "notes": ["type": "string", "description": "Notes."],
                            "priority": ["type": "integer", "description": "Priority 0-9 (0=none, 1=high, 5=medium, 9=low)."]
                        ],
                        "required": ["title"]
                    ]
                )
            ),
            .function(
                .init(
                    name: "notification-schedule",
                    description: "Schedule a local notification. Can trigger at a specific time or after a delay.",
                    parameters: [
                        "type": "object",
                        "properties": [
                            "title": ["type": "string", "description": "Notification title."],
                            "body": ["type": "string", "description": "Optional notification body text."],
                            "trigger_date": ["type": "string", "description": "Optional ISO-8601 datetime to trigger the notification."],
                            "delay_seconds": ["type": "number", "description": "Optional delay in seconds from now."]
                        ],
                        "required": ["title"]
                    ]
                )
            ),
            .function(
                .init(
                    name: "open-url",
                    description: "Open a URL or deep link. Can open websites in Safari, phone numbers (tel:), maps, or other apps via URL schemes.",
                    parameters: [
                        "type": "object",
                        "properties": [
                            "url": [
                                "type": "string",
                                "description": "The URL to open (e.g. 'https://apple.com', 'tel:+1234567890', 'maps://?q=coffee')."
                            ]
                        ],
                        "required": ["url"]
                    ]
                )
            ),
            .function(
                .init(
                    name: "nearby-search",
                    description: "Search for nearby places, businesses, or points of interest using Apple Maps. Returns name, address, phone, coordinates.",
                    parameters: [
                        "type": "object",
                        "properties": [
                            "query": ["type": "string", "description": "What to search for (e.g. 'coffee shop', 'gas station', 'pharmacy')."],
                            "latitude": ["type": "number", "description": "Optional center latitude. Uses current location if omitted."],
                            "longitude": ["type": "number", "description": "Optional center longitude."]
                        ],
                        "required": ["query"]
                    ]
                )
            ),
            .function(
                .init(
                    name: "apple-contacts-search",
                    description: "Search contacts by name. Use \"*\" to list all contacts. Returns name, phone numbers, emails, organization, birthday. Max 50 results.",
                    parameters: [
                        "type": "object",
                        "properties": [
                            "query": [
                                "type": "string",
                                "description": "Name to search for, or \"*\" to list all contacts."
                            ]
                        ],
                        "required": ["query"]
                    ]
                )
            ),
            .function(
                .init(
                    name: "camera-capture",
                    description: "Take a photo using the device camera. The photo is saved to the workspace and the file path is returned.",
                    parameters: [
                        "type": "object",
                        "properties": [:]
                    ]
                )
            ),
            .function(
                .init(
                    name: "photo-pick",
                    description: "Let the user select a photo from their photo library. The photo is saved to the workspace and the file path is returned.",
                    parameters: [
                        "type": "object",
                        "properties": [:]
                    ]
                )
            ),
            .function(
                .init(
                    name: "file-pick",
                    description: "Let the user select a file from the device. The file is saved to the workspace and the file path is returned.",
                    parameters: [
                        "type": "object",
                        "properties": [:]
                    ]
                )
            ),
            .function(
                .init(
                    name: "delegate-task",
                    description: "Delegate a complex task to a background agent that can use multiple tools and perform deep analysis in parallel. Use this when the task requires multiple steps, combining information from different sources (e.g. weather + calendar), research, or multi-step data gathering. Do NOT use for simple single-tool tasks.",
                    parameters: [
                        "type": "object",
                        "properties": [
                            "task": [
                                "type": "string",
                                "description": "Detailed description of the overall task to accomplish."
                            ],
                            "subtasks": [
                                "type": "array",
                                "description": "Optional list of parallel subtasks. Each subtask runs independently.",
                                "items": [
                                    "type": "object",
                                    "properties": [
                                        "description": [
                                            "type": "string",
                                            "description": "What this subtask should accomplish."
                                        ],
                                        "tools": [
                                            "type": "array",
                                            "description": "Optional allowlist of tool names this subtask can use.",
                                            "items": ["type": "string"]
                                        ]
                                    ],
                                    "required": ["description"]
                                ]
                            ],
                            "context": [
                                "type": "string",
                                "description": "Relevant conversation context to help the agent understand the task."
                            ]
                        ],
                        "required": ["task"]
                    ]
                )
            )
        ]
    }

    // MARK: - Skill Tool Definitions (dynamic, from custom skills)

    @MainActor
    static func skillToolDefinitions() -> [ChatCompletionParameters.Tool] {
        OpenRockyCustomSkillStore.shared.skills.filter(\.isEnabled).map { skill in
            let toolName = "skill-\(OpenRockyCustomSkillStore.sanitizeToolName(skill.name))"
            let desc = skill.description + (skill.triggerConditions.isEmpty ? "" : " Trigger: \(skill.triggerConditions)")
            return .init(function: .init(
                name: toolName,
                strict: nil,
                description: desc,
                parameters: .init(type: .object, properties: [:])
            ))
        }
    }

    // MARK: - Chat Tool Definitions (OpenAI function calling format)

    nonisolated static func chatToolDefinitions() -> [ChatCompletionParameters.Tool] {
        [
            .init(function: .init(
                name: "apple-location",
                strict: nil,
                description: "Get the user's current Apple device location.",
                parameters: .init(type: .object, properties: [:])
            )),
            .init(function: .init(
                name: "apple-geocode",
                strict: nil,
                description: "Convert a place name or address into coordinates. Use before weather when user mentions a specific place.",
                parameters: .init(
                    type: .object,
                    properties: [
                        "address": .init(type: .string, description: "Place name, city, or address to look up.")
                    ],
                    required: ["address"]
                )
            )),
            .init(function: .init(
                name: "weather",
                strict: nil,
                description: "Get current weather and hourly forecast for the current location or provided coordinates.",
                parameters: .init(
                    type: .object,
                    properties: [
                        "latitude": .init(type: .number, description: "Optional latitude."),
                        "longitude": .init(type: .number, description: "Optional longitude."),
                        "label": .init(type: .string, description: "Optional location label.")
                    ]
                )
            )),
            .init(function: .init(
                name: "apple-alarm",
                strict: nil,
                description: "Create a real Apple alarm at one exact ISO-8601 datetime.",
                parameters: .init(
                    type: .object,
                    properties: [
                        "title": .init(type: .string, description: "Short label for the alarm."),
                        "scheduled_at": .init(type: .string, description: "Exact ISO-8601 date-time.")
                    ],
                    required: ["scheduled_at"]
                )
            )),
            .init(function: .init(
                name: "memory_get",
                strict: nil,
                description: "Retrieve a stored memory by key.",
                parameters: .init(
                    type: .object,
                    properties: [
                        "key": .init(type: .string, description: "The memory key to look up.")
                    ],
                    required: ["key"]
                )
            )),
            .init(function: .init(
                name: "memory_write",
                strict: nil,
                description: "Store a key-value memory that persists across sessions.",
                parameters: .init(
                    type: .object,
                    properties: [
                        "key": .init(type: .string, description: "Short descriptive key."),
                        "value": .init(type: .string, description: "The value to store.")
                    ],
                    required: ["key", "value"]
                )
            )),
            .init(function: .init(
                name: "apple-health-summary",
                strict: nil,
                description: "Get a daily health summary including steps, active energy, heart rate, distance, and sleep.",
                parameters: .init(
                    type: .object,
                    properties: [
                        "date": .init(type: .string, description: "Date in YYYY-MM-DD format.")
                    ],
                    required: ["date"]
                )
            )),
            .init(function: .init(
                name: "apple-health-metric",
                strict: nil,
                description: "Query a specific health metric for a date range. Metrics: steps, heart_rate, active_energy, distance_walking_running, sleep.",
                parameters: .init(
                    type: .object,
                    properties: [
                        "metric": .init(type: .string, description: "The health metric name."),
                        "start_date": .init(type: .string, description: "Start date YYYY-MM-DD."),
                        "end_date": .init(type: .string, description: "End date YYYY-MM-DD.")
                    ],
                    required: ["metric", "start_date", "end_date"]
                )
            )),
            .init(function: .init(
                name: "shell-execute",
                strict: nil,
                description: "Execute a shell command in the local iOS sandbox. Supports Unix commands (ls, cat, echo, pwd, cp, mv, mkdir, rm, grep, wc, curl, ssh, tar) and network tools (ping, nslookup, dig, host, whois, nc, telnet).",
                parameters: .init(
                    type: .object,
                    properties: [
                        "command": .init(type: .string, description: "The shell command to execute.")
                    ],
                    required: ["command"]
                )
            )),
            .init(function: .init(
                name: "python-execute",
                strict: nil,
                description: "Execute Python 3.13 code on the device. Use for calculations, data processing, text manipulation, algorithms, or any task that benefits from code. Full standard library available (json, math, re, datetime, collections, itertools, csv, urllib, etc.). Use print() to return results.",
                parameters: .init(
                    type: .object,
                    properties: [
                        "code": .init(type: .string, description: "Python source code to execute. Use print() to produce output.")
                    ],
                    required: ["code"]
                )
            )),
            .init(function: .init(
                name: "ffmpeg-execute",
                strict: nil,
                description: "Run FFmpeg for audio/video processing. Merge streams, extract audio, transcode, trim, generate thumbnails, create GIFs. Provide args without leading 'ffmpeg'.",
                parameters: .init(
                    type: .object,
                    properties: [
                        "args": .init(type: .string, description: "FFmpeg arguments (e.g. '-i input.mp4 -vn -c:a copy output.m4a').")
                    ],
                    required: ["args"]
                )
            )),
            .init(function: .init(
                name: "browser-open",
                strict: nil,
                description: "Open URL in browser for user interaction (e.g. login). Returns final URL and title when user taps Done.",
                parameters: .init(
                    type: .object,
                    properties: [
                        "url": .init(type: .string, description: "URL to open.")
                    ],
                    required: ["url"]
                )
            )),
            .init(function: .init(
                name: "browser-cookies",
                strict: nil,
                description: "Get browser cookies for a domain. Use after browser-open to extract auth cookies.",
                parameters: .init(
                    type: .object,
                    properties: [
                        "domain": .init(type: .string, description: "Domain (e.g. 'x.com', 'bilibili.com').")
                    ],
                    required: ["domain"]
                )
            )),
            .init(function: .init(
                name: "browser-read",
                strict: nil,
                description: "Fetch URL with browser engine and extract main text content (JS-rendered pages supported).",
                parameters: .init(
                    type: .object,
                    properties: [
                        "url": .init(type: .string, description: "URL to read content from.")
                    ],
                    required: ["url"]
                )
            )),
            .init(function: .init(
                name: "oauth-authenticate",
                strict: nil,
                description: "Start OAuth flow in system browser. Returns callback URL with tokens.",
                parameters: .init(
                    type: .object,
                    properties: [
                        "auth_url": .init(type: .string, description: "OAuth authorization URL."),
                        "callback_scheme": .init(type: .string, description: "Callback URL scheme (e.g. 'rocky-oauth').")
                    ],
                    required: ["auth_url", "callback_scheme"]
                )
            )),
            .init(function: .init(
                name: "crypto",
                strict: nil,
                description: "Crypto operations: hmac_sha256, sha256, md5, aes_encrypt, aes_decrypt, base64_encode, base64_decode.",
                parameters: .init(
                    type: .object,
                    properties: [
                        "operation": .init(type: .string, description: "hmac_sha256, sha256, md5, aes_encrypt, aes_decrypt, base64_encode, base64_decode."),
                        "data": .init(type: .string, description: "Input data."),
                        "key": .init(type: .string, description: "Key for HMAC/AES (hex)."),
                        "iv": .init(type: .string, description: "IV for AES-CBC (hex, 16 bytes).")
                    ],
                    required: ["operation", "data"]
                )
            )),
            .init(function: .init(
                name: "todo",
                strict: nil,
                description: "Manage a persistent todo list. Actions: add, list, complete, delete.",
                parameters: .init(
                    type: .object,
                    properties: [
                        "action": .init(type: .string, description: "The action: add, list, complete, or delete."),
                        "title": .init(type: .string, description: "Title for new todo (required for add)."),
                        "id": .init(type: .string, description: "UUID of the item (required for complete/delete).")
                    ],
                    required: ["action"]
                )
            )),
            .init(function: .init(
                name: "file-read",
                strict: nil,
                description: "Read a file from the OpenRocky workspace sandbox.",
                parameters: .init(
                    type: .object,
                    properties: [
                        "path": .init(type: .string, description: "Relative file path within the workspace.")
                    ],
                    required: ["path"]
                )
            )),
            .init(function: .init(
                name: "file-write",
                strict: nil,
                description: "Write content to a file in the OpenRocky workspace sandbox.",
                parameters: .init(
                    type: .object,
                    properties: [
                        "path": .init(type: .string, description: "Relative file path within the workspace."),
                        "content": .init(type: .string, description: "The text content to write.")
                    ],
                    required: ["path", "content"]
                )
            )),
            .init(function: .init(
                name: "web-search",
                strict: nil,
                description: "Search the web using DuckDuckGo.",
                parameters: .init(
                    type: .object,
                    properties: [
                        "query": .init(type: .string, description: "The search query.")
                    ],
                    required: ["query"]
                )
            )),
            .init(function: .init(
                name: "apple-calendar-list",
                strict: nil,
                description: "List calendar events in a date range.",
                parameters: .init(
                    type: .object,
                    properties: [
                        "start_date": .init(type: .string, description: "Start date YYYY-MM-DD."),
                        "end_date": .init(type: .string, description: "End date YYYY-MM-DD.")
                    ],
                    required: ["start_date", "end_date"]
                )
            )),
            .init(function: .init(
                name: "apple-calendar-create",
                strict: nil,
                description: "Create a new calendar event.",
                parameters: .init(
                    type: .object,
                    properties: [
                        "title": .init(type: .string, description: "Event title."),
                        "start_date": .init(type: .string, description: "Start datetime ISO-8601."),
                        "end_date": .init(type: .string, description: "End datetime ISO-8601 (optional)."),
                        "all_day": .init(type: .boolean, description: "All-day event flag."),
                        "location": .init(type: .string, description: "Event location."),
                        "notes": .init(type: .string, description: "Event notes.")
                    ],
                    required: ["title", "start_date"]
                )
            )),
            .init(function: .init(
                name: "apple-reminder-list",
                strict: nil,
                description: "List reminders from Apple Reminders.",
                parameters: .init(
                    type: .object,
                    properties: [
                        "include_completed": .init(type: .boolean, description: "Include completed reminders.")
                    ]
                )
            )),
            .init(function: .init(
                name: "apple-reminder-create",
                strict: nil,
                description: "Create a new reminder in Apple Reminders. Always include due_date when the user mentions a time or deadline.",
                parameters: .init(
                    type: .object,
                    properties: [
                        "title": .init(type: .string, description: "Reminder title."),
                        "due_date": .init(type: .string, description: "Due date and time ISO-8601 (e.g. 2025-04-05T14:00:00). Always set when user specifies a time."),
                        "notes": .init(type: .string, description: "Notes."),
                        "priority": .init(type: .integer, description: "Priority 0-9.")
                    ],
                    required: ["title"]
                )
            )),
            .init(function: .init(
                name: "notification-schedule",
                strict: nil,
                description: "Schedule a local notification at a time or after a delay.",
                parameters: .init(
                    type: .object,
                    properties: [
                        "title": .init(type: .string, description: "Notification title."),
                        "body": .init(type: .string, description: "Notification body."),
                        "trigger_date": .init(type: .string, description: "ISO-8601 trigger time."),
                        "delay_seconds": .init(type: .number, description: "Delay in seconds.")
                    ],
                    required: ["title"]
                )
            )),
            .init(function: .init(
                name: "open-url",
                strict: nil,
                description: "Open a URL or deep link in Safari or another app.",
                parameters: .init(
                    type: .object,
                    properties: [
                        "url": .init(type: .string, description: "URL to open.")
                    ],
                    required: ["url"]
                )
            )),
            .init(function: .init(
                name: "nearby-search",
                strict: nil,
                description: "Search for nearby places using Apple Maps.",
                parameters: .init(
                    type: .object,
                    properties: [
                        "query": .init(type: .string, description: "What to search for."),
                        "latitude": .init(type: .number, description: "Optional center latitude."),
                        "longitude": .init(type: .number, description: "Optional center longitude.")
                    ],
                    required: ["query"]
                )
            )),
            .init(function: .init(
                name: "apple-contacts-search",
                strict: nil,
                description: "Search contacts by name. Use \"*\" to list all. Max 50 results.",
                parameters: .init(
                    type: .object,
                    properties: [
                        "query": .init(type: .string, description: "Name to search for, or \"*\" for all.")
                    ],
                    required: ["query"]
                )
            )),
            .init(function: .init(
                name: "camera-capture",
                strict: nil,
                description: "Take a photo using the device camera. Returns the workspace file path.",
                parameters: .init(
                    type: .object,
                    properties: [:],
                    required: []
                )
            )),
            .init(function: .init(
                name: "photo-pick",
                strict: nil,
                description: "Let the user select a photo from the photo library. Returns the workspace file path.",
                parameters: .init(
                    type: .object,
                    properties: [:],
                    required: []
                )
            )),
            .init(function: .init(
                name: "file-pick",
                strict: nil,
                description: "Let the user select a file from the device. Returns the workspace file path and filename.",
                parameters: .init(
                    type: .object,
                    properties: [:],
                    required: []
                )
            )),
            .init(function: .init(
                name: "delegate-task",
                strict: nil,
                description: "Delegate a complex task to a background agent that can use multiple tools and perform deep analysis in parallel. Use when the task requires multiple steps, combining information from different sources, research, or multi-step data gathering.",
                parameters: .init(
                    type: .object,
                    properties: [
                        "task": .init(type: .string, description: "Detailed description of the overall task."),
                        "subtasks": .init(
                            type: .array,
                            description: "Optional parallel subtasks.",
                            items: .init(
                                type: .object,
                                properties: [
                                    "description": .init(type: .string, description: "What this subtask should accomplish."),
                                    "tools": .init(type: .array, description: "Optional tool name allowlist.", items: .init(type: .string))
                                ],
                                required: ["description"]
                            )
                        ),
                        "context": .init(type: .string, description: "Relevant conversation context.")
                    ],
                    required: ["task"]
                )
            ))
        ]
    }

    /// Returns realtime tool definitions plus any enabled custom skills.
    func realtimeTools() -> [OpenAIRealtimeSessionConfiguration.RealtimeTool] {
        var tools = Self.realtimeToolDefinitions()
        // Append enabled skills so voice providers can call them directly
        let skills = OpenRockyCustomSkillStore.shared.skills.filter(\.isEnabled)
        for skill in skills {
            let toolName = "skill-\(OpenRockyCustomSkillStore.sanitizeToolName(skill.name))"
            let desc = skill.description + (skill.triggerConditions.isEmpty ? "" : " Trigger: \(skill.triggerConditions)")
            tools.append(.function(.init(
                name: toolName,
                description: desc,
                parameters: ["type": "object", "properties": [:]]
            )))
        }
        return tools
    }

    // MARK: - Execution

    func execute(name: String, arguments: String) async throws -> String {
        rlog.info("Tool execute: \(name) args=\(arguments.prefix(200))", category: "Tools")
        let startTime = CFAbsoluteTimeGetCurrent()
        do {
            let result = try await _execute(name: name, arguments: arguments)
            let elapsed = String(format: "%.1fms", (CFAbsoluteTimeGetCurrent() - startTime) * 1000)
            rlog.info("Tool \(name) OK [\(elapsed)] result=\(result.prefix(200))", category: "Tools")
            return result
        } catch {
            let elapsed = String(format: "%.1fms", (CFAbsoluteTimeGetCurrent() - startTime) * 1000)
            let nsError = error as NSError
            rlog.error("Tool \(name) FAILED [\(elapsed)] args=\(arguments.prefix(300)) error=\(error.localizedDescription) domain=\(nsError.domain) code=\(nsError.code)", category: "Tools")
            throw error
        }
    }

    private func _execute(name: String, arguments: String) async throws -> String {
        switch name {
        case "apple-location":
            return try encode(try await locationService.currentSnapshot())
        case "apple-geocode":
            return try await executeGeocode(arguments: arguments)
        case "weather", "apple-weather":
            return try await executeWeather(arguments: arguments)
        case "apple-alarm":
            return try await executeAlarm(arguments: arguments)
        case "memory_get":
            return try executeMemoryGet(arguments: arguments)
        case "memory_write":
            return try executeMemoryWrite(arguments: arguments)
        case "apple-health-summary":
            return try await executeHealthSummary(arguments: arguments)
        case "apple-health-metric":
            return try await executeHealthMetric(arguments: arguments)
        case "shell-execute":
            return try executeShell(arguments: arguments)
        case "python-execute":
            return try executePython(arguments: arguments)
        case "ffmpeg-execute":
            return try executeFFmpeg(arguments: arguments)
        case "browser-open":
            return try await executeBrowserOpen(arguments: arguments)
        case "browser-cookies":
            return try await executeBrowserCookies(arguments: arguments)
        case "browser-read":
            return try await executeBrowserRead(arguments: arguments)
        case "oauth-authenticate":
            return try await executeOAuth(arguments: arguments)
        case "crypto":
            return try executeCrypto(arguments: arguments)
        case "todo":
            return try executeTodo(arguments: arguments)
        case "file-read":
            return try executeFileRead(arguments: arguments)
        case "file-write":
            return try executeFileWrite(arguments: arguments)
        case "web-search":
            return try await executeWebSearch(arguments: arguments)
        case "apple-calendar-list":
            return try await executeCalendarList(arguments: arguments)
        case "apple-calendar-create":
            return try await executeCalendarCreate(arguments: arguments)
        case "apple-reminder-list":
            return try await executeReminderList(arguments: arguments)
        case "apple-reminder-create":
            return try await executeReminderCreate(arguments: arguments)
        case "notification-schedule":
            return try await executeNotificationSchedule(arguments: arguments)
        case "open-url":
            return try await executeOpenURL(arguments: arguments)
        case "nearby-search":
            return try await executeNearbySearch(arguments: arguments)
        case "apple-contacts-search":
            return try await executeContactsSearch(arguments: arguments)
        case "camera-capture":
            return try await executeCameraCapture()
        case "photo-pick":
            return try await executePhotoPick()
        case "file-pick":
            return try await executeFilePick()
        case "app-exit":
            return try await executeAppExit(arguments: arguments)
        case "email-send":
            return try await executeEmailSend(arguments: arguments)
        case "delegate-task":
            return try await executeDelegateTask(arguments: arguments)
        default:
            // Check if it's a custom skill tool (skill-*)
            if let skill = OpenRockyCustomSkillStore.shared.skill(forToolName: name) {
                return skill.promptContent
            }
            throw OpenRockyToolboxError.unsupportedTool(name)
        }
    }

    // MARK: - Geocode

    private func executeGeocode(arguments: String) async throws -> String {
        let request = try decode(GeocodeRequest.self, from: arguments)
        let snapshot = try await locationService.geocode(address: request.address)
        return try encode(snapshot)
    }

    // MARK: - Shell

    private func executeShell(arguments: String) throws -> String {
        let request = try decode(ShellRequest.self, from: arguments)
        let result = shellRuntime.execute(command: request.command)
        return try encode(ShellResponse(
            command: result.command,
            exitCode: result.exitCode,
            output: String(result.output.prefix(4000))
        ))
    }

    // MARK: - Python

    private func executePython(arguments: String) throws -> String {
        let request = try decode(PythonRequest.self, from: arguments)
        #if targetEnvironment(simulator)
        return try encode(PythonResponse(
            success: false,
            output: "",
            error: "Python is not available on Simulator"
        ))
        #else
        let result = OpenRockyPythonRuntime.shared.execute(request.code)
        return try encode(PythonResponse(
            success: result.success,
            output: String(result.output.prefix(8000)),
            error: result.error.isEmpty ? nil : String(result.error.prefix(2000))
        ))
        #endif
    }

    // MARK: - FFmpeg

    private func executeFFmpeg(arguments: String) throws -> String {
        let request = try decode(FFmpegRequest.self, from: arguments)

        // Parse args string into array, respecting quotes
        var argv = ["ffmpeg", "-y"]  // -y to overwrite without asking
        argv.append(contentsOf: Self.shellSplit(request.args))

        // Resolve relative paths against workspace
        if let ws = shellRuntime.workspacePath {
            argv = argv.map { arg in
                // If it looks like a relative file path (has extension, no flag prefix)
                if !arg.hasPrefix("-"), arg.contains("."), !arg.hasPrefix("/") {
                    return (ws as NSString).appendingPathComponent(arg)
                }
                return arg
            }
        }

        let exitCode = ffmpeg(argv)

        return try encode(FFmpegResponse(
            success: exitCode == 0,
            exitCode: Int(exitCode),
            args: argv.joined(separator: " ")
        ))
    }

    /// Split a string into arguments respecting single/double quotes.
    private static func shellSplit(_ input: String) -> [String] {
        var args: [String] = []
        var current = ""
        var inSingle = false
        var inDouble = false

        for char in input {
            if char == "'" && !inDouble {
                inSingle.toggle()
            } else if char == "\"" && !inSingle {
                inDouble.toggle()
            } else if char == " " && !inSingle && !inDouble {
                if !current.isEmpty {
                    args.append(current)
                    current = ""
                }
            } else {
                current.append(char)
            }
        }
        if !current.isEmpty { args.append(current) }
        return args
    }

    // MARK: - Browser

    private func executeBrowserOpen(arguments: String) async throws -> String {
        let request = try decode(BrowserOpenRequest.self, from: arguments)
        let result = try await OpenRockyBrowserService.shared.openURL(request.url)
        return try encode(BrowserOpenResponse(
            finalURL: result.finalURL,
            pageTitle: result.pageTitle
        ))
    }

    private func executeBrowserCookies(arguments: String) async throws -> String {
        let request = try decode(BrowserCookiesRequest.self, from: arguments)
        let cookies = try await OpenRockyBrowserService.shared.getCookies(for: request.domain)
        return try encode(BrowserCookiesResponse(
            domain: request.domain,
            count: cookies.count,
            cookies: cookies
        ))
    }

    private func executeBrowserRead(arguments: String) async throws -> String {
        let request = try decode(BrowserReadRequest.self, from: arguments)
        let result = try await OpenRockyBrowserService.shared.readContent(request.url)
        return try encode(BrowserReadResponse(
            url: result.url,
            title: result.title,
            content: String(result.textContent.prefix(8000))
        ))
    }

    // MARK: - OAuth

    private func executeOAuth(arguments: String) async throws -> String {
        let request = try decode(OAuthRequest.self, from: arguments)
        let result = try await OpenRockyOAuthService.shared.authenticate(
            authURL: request.authURL,
            callbackScheme: request.callbackScheme
        )
        return try encode(OAuthResponse(
            callbackURL: result.callbackURL,
            parameters: result.parameters
        ))
    }

    // MARK: - Crypto

    private func executeCrypto(arguments: String) throws -> String {
        let request = try decode(CryptoRequest.self, from: arguments)
        let service = OpenRockyCryptoService.shared

        switch request.operation {
        case "hmac_sha256":
            guard let keyHex = request.key else { throw OpenRockyToolboxError.missingParameter("key") }
            let keyData = hexToData(keyHex)
            let result = service.hmacSHA256(key: keyData, message: Data(request.data.utf8))
            return try encode(["result": result])

        case "sha256":
            let result = service.sha256(data: Data(request.data.utf8))
            return try encode(["result": result])

        case "md5":
            let result = service.md5(data: Data(request.data.utf8))
            return try encode(["result": result])

        case "aes_encrypt":
            guard let keyHex = request.key, let ivHex = request.iv else {
                throw OpenRockyToolboxError.missingParameter("key and iv")
            }
            let encrypted = try service.aesEncryptCBC(
                key: hexToData(keyHex), iv: hexToData(ivHex), plaintext: Data(request.data.utf8)
            )
            return try encode(["result": encrypted.map { String(format: "%02x", $0) }.joined()])

        case "aes_decrypt":
            guard let keyHex = request.key, let ivHex = request.iv else {
                throw OpenRockyToolboxError.missingParameter("key and iv")
            }
            let decrypted = try service.aesDecryptCBC(
                key: hexToData(keyHex), iv: hexToData(ivHex), ciphertext: hexToData(request.data)
            )
            return try encode(["result": String(data: decrypted, encoding: .utf8) ?? decrypted.base64EncodedString()])

        case "base64_encode":
            return try encode(["result": service.base64Encode(data: Data(request.data.utf8))])

        case "base64_decode":
            let decoded = try service.base64Decode(string: request.data)
            return try encode(["result": String(data: decoded, encoding: .utf8) ?? decoded.map { String(format: "%02x", $0) }.joined()])

        default:
            throw OpenRockyToolboxError.unsupportedTool("crypto:\(request.operation)")
        }
    }

    private func hexToData(_ hex: String) -> Data {
        var data = Data()
        var index = hex.startIndex
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2, limitedBy: hex.endIndex) ?? hex.endIndex
            if let byte = UInt8(hex[index..<nextIndex], radix: 16) {
                data.append(byte)
            }
            index = nextIndex
        }
        return data
    }

    // MARK: - Weather

    private func executeWeather(arguments: String) async throws -> String {
        let request = try decode(OpenRockyWeatherRequest.self, from: arguments)
        let location: CLLocation
        let label: String

        if let latitude = request.latitude, let longitude = request.longitude {
            location = CLLocation(latitude: latitude, longitude: longitude)
            label = request.label?.trimmingCharacters(in: .whitespacesAndNewlines).ifEmpty("Requested coordinates")
                ?? "Requested coordinates"
        } else {
            let snapshot = try await locationService.currentSnapshot()
            location = CLLocation(latitude: snapshot.latitude, longitude: snapshot.longitude)
            label = request.label?.trimmingCharacters(in: .whitespacesAndNewlines).ifEmpty(snapshot.label) ?? snapshot.label
        }

        return try encode(try await weatherService.currentWeather(for: location, label: label))
    }

    // MARK: - Alarm

    private func executeAlarm(arguments: String) async throws -> String {
        guard let alarmService else {
            throw OpenRockyToolboxError.unsupportedAlarmPlatform
        }

        let request = try decode(OpenRockyAlarmRequest.self, from: arguments)
        let title = request.title?.trimmingCharacters(in: .whitespacesAndNewlines).ifEmpty("OpenRocky Alarm") ?? "OpenRocky Alarm"
        let scheduledAt = try request.parseScheduledAt()
        return try encode(try await alarmService.createAlarm(title: title, scheduledAt: scheduledAt))
    }

    // MARK: - Memory

    private func executeMemoryGet(arguments: String) throws -> String {
        let request = try decode(MemoryGetRequest.self, from: arguments)
        if let value = memoryService.get(key: request.key) {
            return try encode(["key": request.key, "value": value])
        } else {
            return try encode(["key": request.key, "value": NSNull(), "found": false] as [String: Any])
        }
    }

    private func executeMemoryWrite(arguments: String) throws -> String {
        let request = try decode(MemoryWriteRequest.self, from: arguments)
        memoryService.write(key: request.key, value: request.value)
        return try encode(["key": request.key, "stored": true])
    }

    // MARK: - Health

    private func executeHealthSummary(arguments: String) async throws -> String {
        let request = try decode(HealthSummaryRequest.self, from: arguments)
        let result = try await healthService.querySummary(dateString: request.date)
        return try encode(result)
    }

    private func executeHealthMetric(arguments: String) async throws -> String {
        let request = try decode(HealthMetricRequest.self, from: arguments)
        let result = try await healthService.queryMetric(
            metric: request.metric,
            startDate: request.startDate,
            endDate: request.endDate
        )
        return try encode(result)
    }

    // MARK: - Todo

    private func executeTodo(arguments: String) throws -> String {
        let request = try decode(TodoRequest.self, from: arguments)

        switch request.action {
        case "add":
            guard let title = request.title, !title.isEmpty else {
                return try encode(["error": "Title is required for 'add' action."])
            }
            let item = todoService.add(title: title)
            return try encode(TodoItemResponse(id: item.id.uuidString, title: item.title, isComplete: item.isComplete, created: true))

        case "list":
            let items = todoService.list()
            let mapped = items.map {
                TodoItemResponse(id: $0.id.uuidString, title: $0.title, isComplete: $0.isComplete, created: nil)
            }
            return try encode(["items": mapped, "count": items.count] as [String: Any])

        case "complete":
            guard let id = request.id else {
                return try encode(["error": "ID is required for 'complete' action."])
            }
            let success = todoService.complete(id: id)
            return try encode(["id": id, "completed": success])

        case "delete":
            guard let id = request.id else {
                return try encode(["error": "ID is required for 'delete' action."])
            }
            let success = todoService.delete(id: id)
            return try encode(["id": id, "deleted": success])

        default:
            return try encode(["error": "Unknown action '\(request.action)'. Use add, list, complete, or delete."])
        }
    }

    // MARK: - File Read/Write

    private func executeFileRead(arguments: String) throws -> String {
        let request = try decode(FileReadRequest.self, from: arguments)
        guard let workspace = shellRuntime.workspacePath else {
            throw OpenRockyToolboxError.workspaceNotReady
        }
        let fileURL = URL(fileURLWithPath: workspace).appendingPathComponent(request.path)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return try encode(["error": "File not found: \(request.path)"])
        }
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        return try encode(["path": request.path, "content": String(content.prefix(8000))])
    }

    private func executeFileWrite(arguments: String) throws -> String {
        let request = try decode(FileWriteRequest.self, from: arguments)
        guard let workspace = shellRuntime.workspacePath else {
            throw OpenRockyToolboxError.workspaceNotReady
        }
        let fileURL = URL(fileURLWithPath: workspace).appendingPathComponent(request.path)

        // Create intermediate directories if needed
        let dir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        try request.content.write(to: fileURL, atomically: true, encoding: .utf8)
        let encodedPath = request.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? request.path
        let link = "rocky://workspace/\(encodedPath)"
        return try encode(["path": request.path, "written": true, "bytes": request.content.utf8.count, "link": link, "markdown_link": "[\(request.path)](\(link))"])
    }

    // MARK: - Web Search

    private func executeWebSearch(arguments: String) async throws -> String {
        let request = try decode(WebSearchRequest.self, from: arguments)
        let query = request.query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? request.query

        guard let url = URL(string: "https://html.duckduckgo.com/html/?q=\(query)") else {
            return try encode(["error": "Invalid search query."])
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              let html = String(data: data, encoding: .utf8) else {
            return try encode(["error": "Web search request failed."])
        }

        let searchResults = parseDuckDuckGoHTML(html)

        if searchResults.isEmpty {
            return try encode(["query": request.query, "results": [] as [String], "message": "No results found. Try a different query."])
        }

        return try encode(["query": request.query, "results": searchResults])
    }

    private func parseDuckDuckGoHTML(_ html: String) -> [[String: String]] {
        var results: [[String: String]] = []

        // Match result blocks: <a class="result__a" href="...">title</a> and <a class="result__snippet">snippet</a>
        let linkPattern = #"<a[^>]+class="result__a"[^>]+href="([^"]*)"[^>]*>(.*?)</a>"#
        let snippetPattern = #"<a[^>]+class="result__snippet"[^>]*>(.*?)</a>"#

        guard let linkRegex = try? NSRegularExpression(pattern: linkPattern, options: .dotMatchesLineSeparators),
              let snippetRegex = try? NSRegularExpression(pattern: snippetPattern, options: .dotMatchesLineSeparators) else {
            return []
        }

        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        let linkMatches = linkRegex.matches(in: html, range: range)
        let snippetMatches = snippetRegex.matches(in: html, range: range)

        for (i, linkMatch) in linkMatches.prefix(8).enumerated() {
            guard let urlRange = Range(linkMatch.range(at: 1), in: html),
                  let titleRange = Range(linkMatch.range(at: 2), in: html) else { continue }

            var resultURL = String(html[urlRange])
            // DuckDuckGo wraps URLs in a redirect — extract the actual URL
            if let uddgRange = resultURL.range(of: "uddg=") {
                let encoded = String(resultURL[uddgRange.upperBound...])
                    .components(separatedBy: "&").first ?? ""
                resultURL = encoded.removingPercentEncoding ?? resultURL
            }

            let rawTitle = String(html[titleRange])
            let title = rawTitle.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

            var snippet = ""
            if i < snippetMatches.count,
               let snippetRange = Range(snippetMatches[i].range(at: 1), in: html) {
                snippet = String(html[snippetRange])
                    .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "&amp;", with: "&")
                    .replacingOccurrences(of: "&lt;", with: "<")
                    .replacingOccurrences(of: "&gt;", with: ">")
                    .replacingOccurrences(of: "&quot;", with: "\"")
                    .replacingOccurrences(of: "&#x27;", with: "'")
            }

            guard !title.isEmpty, !resultURL.isEmpty else { continue }
            results.append(["title": title, "text": snippet, "url": resultURL])
        }

        return results
    }

    // MARK: - Calendar

    private func executeCalendarList(arguments: String) async throws -> String {
        let request = try decode(CalendarListRequest.self, from: arguments)
        let events = try await calendarService.listEvents(startDate: request.startDate, endDate: request.endDate)
        return try encode(["events": events, "count": events.count] as [String: Any])
    }

    private func executeCalendarCreate(arguments: String) async throws -> String {
        let request = try decode(CalendarCreateRequest.self, from: arguments)
        let result = try await calendarService.createEvent(
            title: request.title,
            startDate: request.startDate,
            endDate: request.endDate,
            allDay: request.allDay ?? false,
            location: request.location,
            notes: request.notes
        )
        return try encode(result)
    }

    // MARK: - Reminders

    private func executeReminderList(arguments: String) async throws -> String {
        let request = try decode(ReminderListRequest.self, from: arguments)
        let reminders = try await reminderService.listReminders(includeCompleted: request.includeCompleted ?? false)
        return try encode(["reminders": reminders, "count": reminders.count] as [String: Any])
    }

    private func executeReminderCreate(arguments: String) async throws -> String {
        let request = try decode(ReminderCreateRequest.self, from: arguments)
        let result = try await reminderService.createReminder(
            title: request.title,
            dueDate: request.dueDate,
            notes: request.notes,
            priority: request.priority
        )
        return try encode(result)
    }

    // MARK: - Notifications

    private func executeNotificationSchedule(arguments: String) async throws -> String {
        let request = try decode(NotificationRequest.self, from: arguments)
        let result = try await notificationService.schedule(
            title: request.title,
            body: request.body,
            triggerDate: request.triggerDate,
            delaySeconds: request.delaySeconds
        )
        return try encode(result)
    }

    // MARK: - Open URL

    private func executeOpenURL(arguments: String) async throws -> String {
        let request = try decode(OpenURLRequest.self, from: arguments)
        let result = try await urlService.open(urlString: request.url)
        return try encode(result)
    }

    // MARK: - Nearby Search

    private func executeNearbySearch(arguments: String) async throws -> String {
        let request = try decode(NearbySearchRequest.self, from: arguments)
        let results = try await nearbySearchService.search(
            query: request.query,
            latitude: request.latitude,
            longitude: request.longitude
        )
        return try encode(["results": results, "count": results.count] as [String: Any])
    }

    // MARK: - Contacts

    private func executeContactsSearch(arguments: String) async throws -> String {
        let request = try decode(ContactsSearchRequest.self, from: arguments)
        let contacts = try await contactsService.search(query: request.query)
        return try encode(["contacts": contacts, "count": contacts.count] as [String: Any])
    }

    // MARK: - Camera / Photo / File

    private func executeCameraCapture() async throws -> String {
        let imageData = try await OpenRockyUIPresenterService.shared.capturePhoto()
        guard let workspace = shellRuntime.workspacePath else {
            throw OpenRockyToolboxError.workspaceNotReady
        }
        let filename = "capture-\(UUID().uuidString.prefix(8)).jpg"
        let fileURL = URL(fileURLWithPath: workspace).appendingPathComponent(filename)
        try imageData.write(to: fileURL)
        return try encode([
            "path": filename,
            "size_bytes": imageData.count,
            "type": "image/jpeg",
            "description": "Photo captured from camera and saved to workspace."
        ] as [String: Any])
    }

    private func executePhotoPick() async throws -> String {
        let imageData = try await OpenRockyUIPresenterService.shared.pickPhoto()
        guard let workspace = shellRuntime.workspacePath else {
            throw OpenRockyToolboxError.workspaceNotReady
        }
        let filename = "photo-\(UUID().uuidString.prefix(8)).jpg"
        let fileURL = URL(fileURLWithPath: workspace).appendingPathComponent(filename)
        try imageData.write(to: fileURL)
        return try encode([
            "path": filename,
            "size_bytes": imageData.count,
            "type": "image/jpeg",
            "description": "Photo selected from library and saved to workspace."
        ] as [String: Any])
    }

    private func executeFilePick() async throws -> String {
        let result = try await OpenRockyUIPresenterService.shared.pickFile()
        guard let workspace = shellRuntime.workspacePath else {
            throw OpenRockyToolboxError.workspaceNotReady
        }
        let fileURL = URL(fileURLWithPath: workspace).appendingPathComponent(result.filename)
        let dir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try result.data.write(to: fileURL)
        return try encode([
            "path": result.filename,
            "size_bytes": result.data.count,
            "description": "File '\(result.filename)' imported and saved to workspace."
        ] as [String: Any])
    }

    // MARK: - App Exit

    private struct AppExitRequest: Decodable {
        let farewell_message: String
    }

    private func executeAppExit(arguments: String) async throws -> String {
        let request = try decode(AppExitRequest.self, from: arguments)
        let trimmed = request.farewell_message.trimmingCharacters(in: .whitespacesAndNewlines)
        let message = trimmed.isEmpty ? "OpenRocky is about to exit." : trimmed
        OpenRockyAppLifecycleService.shared.exitApp(afterDelay: 1.0)
        return try encode([
            "status": "exiting",
            "message": message,
            "delay_seconds": 1
        ] as [String: Any])
    }

    // MARK: - Email

    private struct EmailSendRequest: Decodable {
        let to: String
        let subject: String
        let body: String
        let cc: String?
    }

    private func executeEmailSend(arguments: String) async throws -> String {
        let request = try decode(EmailSendRequest.self, from: arguments)
        let toList = request.to.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let ccList = request.cc?.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? []
        let messageID = try await OpenRockyEmailService.shared.send(to: toList, subject: request.subject, body: request.body, cc: ccList)
        return try encode(["status": "sent", "message_id": messageID, "to": request.to] as [String: Any])
    }

    // MARK: - Delegate Task (Subagent)

    private func executeDelegateTask(arguments: String) async throws -> String {
        guard let config = subagentChatConfiguration else {
            throw OpenRockyToolboxError.missingParameter("subagent chat configuration")
        }

        let request = try decode(OpenRockyDelegateTaskRequest.self, from: arguments)

        let subtasks: [OpenRockySubagentTask]
        if let requestedSubtasks = request.subtasks, !requestedSubtasks.isEmpty {
            subtasks = requestedSubtasks.map { sub in
                OpenRockySubagentTask(
                    description: sub.description,
                    allowedTools: sub.tools
                )
            }
        } else {
            subtasks = []
        }

        let runtime = OpenRockySubagentRuntime(
            toolbox: self,
            configuration: config,
            timeout: OpenRockySubagentRuntime.defaultTimeout,
            onStatusUpdate: subagentStatusHandler
        )

        let result = await runtime.execute(
            taskDescription: request.task,
            subtasks: subtasks,
            context: request.context ?? ""
        )

        let response = OpenRockyDelegateTaskResponse(
            status: "completed",
            taskDescription: result.taskDescription,
            subtaskCount: result.results.count,
            results: result.results.map { sub in
                OpenRockyDelegateTaskResponse.SubtaskResult(
                    summary: sub.summary,
                    details: sub.details,
                    toolsUsed: sub.toolCalls.map(\.name),
                    succeeded: sub.succeeded,
                    elapsedSeconds: sub.elapsedSeconds
                )
            },
            totalElapsedSeconds: result.totalElapsedSeconds
        )

        return try encode(response)
    }

    // MARK: - Encoding/Decoding

    private func decode<T: Decodable>(_ type: T.Type, from text: String) throws -> T {
        let data = Data(text.utf8)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func encode<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }

    private func encode(_ dict: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }
}

// MARK: - Request Types

private struct GeocodeRequest: Decodable {
    let address: String
}

private struct ShellRequest: Decodable {
    let command: String
}

private struct ShellResponse: Encodable {
    let command: String
    let exitCode: Int32
    let output: String

    enum CodingKeys: String, CodingKey {
        case command
        case exitCode = "exit_code"
        case output
    }
}

private struct PythonRequest: Decodable {
    let code: String
}

private struct PythonResponse: Encodable {
    let success: Bool
    let output: String
    let error: String?
}

private struct FFmpegRequest: Decodable {
    let args: String
}

private struct FFmpegResponse: Encodable {
    let success: Bool
    let exitCode: Int
    let args: String

    enum CodingKeys: String, CodingKey {
        case success
        case exitCode = "exit_code"
        case args
    }
}

private struct BrowserOpenRequest: Decodable {
    let url: String
}

private struct BrowserOpenResponse: Encodable {
    let finalURL: String
    let pageTitle: String

    enum CodingKeys: String, CodingKey {
        case finalURL = "final_url"
        case pageTitle = "page_title"
    }
}

private struct BrowserCookiesRequest: Decodable {
    let domain: String
}

private struct BrowserCookiesResponse: Encodable {
    let domain: String
    let count: Int
    let cookies: [BrowserCookie]
}

private struct BrowserReadRequest: Decodable {
    let url: String
}

private struct BrowserReadResponse: Encodable {
    let url: String
    let title: String
    let content: String
}

private struct OAuthRequest: Decodable {
    let authURL: String
    let callbackScheme: String

    enum CodingKeys: String, CodingKey {
        case authURL = "auth_url"
        case callbackScheme = "callback_scheme"
    }
}

private struct OAuthResponse: Encodable {
    let callbackURL: String
    let parameters: [String: String]

    enum CodingKeys: String, CodingKey {
        case callbackURL = "callback_url"
        case parameters
    }
}

private struct CryptoRequest: Decodable {
    let operation: String
    let data: String
    let key: String?
    let iv: String?
}

private struct OpenRockyWeatherRequest: Decodable {
    let latitude: Double?
    let longitude: Double?
    let label: String?
}

private struct OpenRockyAlarmRequest: Decodable {
    let title: String?
    let scheduledAt: String

    enum CodingKeys: String, CodingKey {
        case title
        case scheduledAt = "scheduled_at"
    }

    func parseScheduledAt() throws -> Date {
        let iso8601 = ISO8601DateFormatter()
        iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso8601.date(from: scheduledAt) {
            return date
        }

        let relaxed = ISO8601DateFormatter()
        relaxed.formatOptions = [.withInternetDateTime]
        if let date = relaxed.date(from: scheduledAt) {
            return date
        }

        // Handle datetime without timezone (e.g. "2026-03-31T18:02:00") — assume local timezone
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = .current
        for fmt in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm"] {
            df.dateFormat = fmt
            if let date = df.date(from: scheduledAt) {
                return date
            }
        }

        throw OpenRockyToolboxError.invalidAlarmTime(scheduledAt)
    }
}

private struct MemoryGetRequest: Decodable {
    let key: String
}

private struct MemoryWriteRequest: Decodable {
    let key: String
    let value: String
}

private struct HealthSummaryRequest: Decodable {
    let date: String
}

private struct HealthMetricRequest: Decodable {
    let metric: String
    let startDate: String
    let endDate: String

    enum CodingKeys: String, CodingKey {
        case metric
        case startDate = "start_date"
        case endDate = "end_date"
    }
}

private struct TodoRequest: Decodable {
    let action: String
    let title: String?
    let id: String?
}

private struct TodoItemResponse: Encodable {
    let id: String
    let title: String
    let isComplete: Bool
    let created: Bool?

    enum CodingKeys: String, CodingKey {
        case id, title
        case isComplete = "is_complete"
        case created
    }
}

private struct FileReadRequest: Decodable {
    let path: String
}

private struct FileWriteRequest: Decodable {
    let path: String
    let content: String
}

private struct WebSearchRequest: Decodable {
    let query: String
}

private struct CalendarListRequest: Decodable {
    let startDate: String
    let endDate: String

    enum CodingKeys: String, CodingKey {
        case startDate = "start_date"
        case endDate = "end_date"
    }
}

private struct CalendarCreateRequest: Decodable {
    let title: String
    let startDate: String
    let endDate: String?
    let allDay: Bool?
    let location: String?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case title
        case startDate = "start_date"
        case endDate = "end_date"
        case allDay = "all_day"
        case location, notes
    }
}

private struct ReminderListRequest: Decodable {
    let includeCompleted: Bool?

    enum CodingKeys: String, CodingKey {
        case includeCompleted = "include_completed"
    }
}

private struct ReminderCreateRequest: Decodable {
    let title: String
    let dueDate: String?
    let notes: String?
    let priority: Int?

    enum CodingKeys: String, CodingKey {
        case title
        case dueDate = "due_date"
        case notes, priority
    }
}

private struct NotificationRequest: Decodable {
    let title: String
    let body: String?
    let triggerDate: String?
    let delaySeconds: Double?

    enum CodingKeys: String, CodingKey {
        case title, body
        case triggerDate = "trigger_date"
        case delaySeconds = "delay_seconds"
    }
}

private struct OpenURLRequest: Decodable {
    let url: String
}

private struct NearbySearchRequest: Decodable {
    let query: String
    let latitude: Double?
    let longitude: Double?
}

private struct ContactsSearchRequest: Decodable {
    let query: String
}

private struct DuckDuckGoResponse: Decodable {
    let heading: String
    let abstractText: String
    let abstractURL: String
    let relatedTopics: [DuckDuckGoTopic]

    enum CodingKeys: String, CodingKey {
        case heading = "Heading"
        case abstractText = "AbstractText"
        case abstractURL = "AbstractURL"
        case relatedTopics = "RelatedTopics"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        heading = (try? container.decode(String.self, forKey: .heading)) ?? ""
        abstractText = (try? container.decode(String.self, forKey: .abstractText)) ?? ""
        abstractURL = (try? container.decode(String.self, forKey: .abstractURL)) ?? ""
        relatedTopics = (try? container.decode([DuckDuckGoTopic].self, forKey: .relatedTopics)) ?? []
    }
}

private struct DuckDuckGoTopic: Decodable {
    let text: String
    let firstURL: String

    enum CodingKeys: String, CodingKey {
        case text = "Text"
        case firstURL = "FirstURL"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = (try? container.decode(String.self, forKey: .text)) ?? ""
        firstURL = (try? container.decode(String.self, forKey: .firstURL)) ?? ""
    }
}

// MARK: - Errors

enum OpenRockyToolboxError: LocalizedError {
    case unsupportedTool(String)
    case unsupportedAlarmPlatform
    case invalidAlarmTime(String)
    case workspaceNotReady
    case missingParameter(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedTool(let name):
            "OpenRocky does not recognize tool `\(name)`."
        case .unsupportedAlarmPlatform:
            "Alarm creation requires iOS 26 or later."
        case .invalidAlarmTime(let value):
            "OpenRocky could not parse the alarm time `\(value)` as ISO-8601."
        case .workspaceNotReady:
            "The OpenRocky workspace is not initialized yet."
        case .missingParameter(let name):
            "Missing required parameter: \(name)."
        }
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}
