//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-04-11
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation
@preconcurrency import SwiftOpenAI

@RealtimeActor
final class OpenRockyGLMRealtimeVoiceClient: OpenRockyRealtimeVoiceClient {
    let modelID: String
    let features: OpenRockyRealtimeVoiceFeatures

    private let configuration: OpenRockyRealtimeProviderConfiguration
    private let soulInstructions: String
    private let realtimeTools: [OpenAIRealtimeSessionConfiguration.RealtimeTool]
    private var socket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var eventSink: (@Sendable (OpenRockyRealtimeEvent) -> Void)?
    private var isReady = false

    /// Track pending function call IDs for tool output routing.
    private var pendingToolCallID: String?
    private var pendingToolCallName: String?
    /// Buffer transcript until response.done to avoid premature mic resume.
    private var pendingTranscript: String?
    /// Whether the next audio.delta is the first chunk in a new response.
    private var isFirstAudioChunk = true
    /// Whether a response is currently being generated — block new commits while true.
    private var isResponseInProgress = false

    init(configuration: OpenRockyRealtimeProviderConfiguration, soulInstructions: String, realtimeTools: [OpenAIRealtimeSessionConfiguration.RealtimeTool] = []) {
        self.configuration = configuration.normalized()
        self.modelID = configuration.modelID.isEmpty ? "glm-realtime" : configuration.modelID
        self.soulInstructions = soulInstructions
        self.realtimeTools = realtimeTools
        self.features = OpenRockyRealtimeVoiceFeatures(
            supportsTextInput: true,
            supportsAssistantStreaming: true,
            supportsToolCalls: true,
            supportsAudioOutput: true,
            needsMicSuspension: true
        )
    }

    func connect(eventSink: @escaping @Sendable (OpenRockyRealtimeEvent) -> Void) async throws {
        guard let credential = configuration.credential, !credential.isEmpty else {
            throw OpenRockyRealtimeVoiceClientError.notConnected
        }

        self.eventSink = eventSink
        emit(.status("Connecting GLM Realtime session..."))

        let baseHost = configuration.customHost ?? "wss://open.bigmodel.cn"
        let urlString = "\(baseHost)/api/paas/v4/realtime"
        guard let url = URL(string: urlString) else {
            throw OpenRockyRealtimeVoiceClientError.notConnected
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(credential)", forHTTPHeaderField: "Authorization")

        let socket = URLSession.shared.webSocketTask(with: request)
        self.socket = socket
        socket.resume()
        rlog.info("GLM WebSocket connecting model=\(modelID)", category: "Voice")

        // Wait for session.created before sending session.update
        let createdTimeout: UInt64 = 5_000_000_000 // 5 seconds
        let createdDeadline = ContinuousClock.now + .nanoseconds(Int64(createdTimeout))
        var gotCreated = false
        while ContinuousClock.now < createdDeadline {
            let message = try await socket.receive()
            if case .string(let text) = message {
                handleServerMessage(text)
                if let data = text.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   json["type"] as? String == "session.created" {
                    gotCreated = true
                    break
                }
            }
        }

        guard gotCreated else {
            rlog.error("GLM: did not receive session.created", category: "Voice")
            throw OpenRockyRealtimeVoiceClientError.notConnected
        }

        // Now send session.update
        try await sendSessionUpdate()
        rlog.info("GLM session.update sent, waiting for session.updated", category: "Voice")

        // Wait for session.updated
        let updateTimeout: UInt64 = 5_000_000_000
        let updateDeadline = ContinuousClock.now + .nanoseconds(Int64(updateTimeout))
        var gotUpdated = false
        while ContinuousClock.now < updateDeadline {
            let message = try await socket.receive()
            if case .string(let text) = message {
                handleServerMessage(text)
                if let data = text.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   json["type"] as? String == "session.updated" {
                    gotUpdated = true
                    break
                }
            }
        }

        if !gotUpdated {
            rlog.warning("GLM: did not receive session.updated, proceeding anyway", category: "Voice")
        }

        isReady = true
        emit(.sessionReady(model: modelID, features: features))

        // Start receive loop for ongoing events
        receiveTask?.cancel()
        receiveTask = Task { await self.receiveLoop() }

        emit(.status("GLM Realtime session is ready."))
    }

    func disconnect() async {
        rlog.info("GLM realtime disconnecting", category: "Voice")
        receiveTask?.cancel()
        receiveTask = nil
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        isReady = false
    }

    func sendText(_ text: String) async throws {
        guard socket != nil, isReady else { throw OpenRockyRealtimeVoiceClientError.notConnected }

        // Create a conversation item with user text and trigger response
        let createItem: [String: Any] = [
            "type": "conversation.item.create",
            "item": [
                "type": "message",
                "role": "user",
                "content": [
                    ["type": "input_text", "text": text]
                ]
            ] as [String: Any]
        ]
        try await sendJSON(createItem)

        let createResponse: [String: Any] = [
            "type": "response.create"
        ]
        try await sendJSON(createResponse)
    }

    private var audioChunkCount = 0
    /// Client-side VAD: track consecutive silence chunks to auto-commit.
    private var isSpeaking = false
    private var silenceChunkCount = 0
    /// Number of consecutive silent chunks before triggering commit (~800ms at 100ms/chunk).
    private let silenceThreshold = 8

    func sendAudioChunk(base64Audio: String) async throws {
        guard socket != nil, isReady else { return }

        // Decode raw PCM16 24kHz, downsample to 16kHz, wrap as WAV
        guard let pcm24k = Data(base64Encoded: base64Audio) else { return }
        let pcm16k = Self.downsample24kTo16k(pcm24k)
        let wavData = Self.wrapPCM16AsWAV(pcm16k, sampleRate: 16000)
        let wavBase64 = wavData.base64EncodedString()

        let message: [String: Any] = [
            "type": "input_audio_buffer.append",
            "audio": wavBase64
        ]
        try await sendJSON(message)

        audioChunkCount += 1
        if audioChunkCount == 1 {
            rlog.info("GLM: first audio chunk sent, pcm24k=\(pcm24k.count)bytes pcm16k=\(pcm16k.count)bytes wav=\(wavData.count)bytes", category: "Voice")
        }

        // Client-side VAD: detect silence to auto-commit
        let rms = Self.computeRMS(pcm16k)
        let isSilent = rms < 500 // Threshold for silence (PCM16 range 0-32768)

        if isSilent {
            if isSpeaking {
                silenceChunkCount += 1
                if silenceChunkCount >= silenceThreshold {
                    // Speech ended — commit and request response
                    isSpeaking = false
                    silenceChunkCount = 0

                    guard !isResponseInProgress else {
                        rlog.info("GLM: skipping commit, response already in progress", category: "Voice")
                        return
                    }

                    rlog.info("GLM: client VAD detected speech end, committing (rms=\(rms))", category: "Voice")
                    isResponseInProgress = true
                    emit(.status("Processing..."))

                    let commitMsg: [String: Any] = ["type": "input_audio_buffer.commit"]
                    try await sendJSON(commitMsg)

                    let responseMsg: [String: Any] = ["type": "response.create"]
                    try await sendJSON(responseMsg)
                }
            }
        } else {
            if !isSpeaking {
                isSpeaking = true
                rlog.info("GLM: client VAD detected speech start (rms=\(rms))", category: "Voice")
                emit(.inputSpeechStarted)
                emit(.status("Listening..."))
            }
            silenceChunkCount = 0
        }
    }

    /// Compute RMS energy of PCM16 data.
    private static func computeRMS(_ data: Data) -> Double {
        let samples: [Int16] = data.withUnsafeBytes { raw in
            let buffer = raw.bindMemory(to: Int16.self)
            return Array(buffer)
        }
        guard !samples.isEmpty else { return 0 }
        let sumSquares = samples.reduce(0.0) { $0 + Double($1) * Double($1) }
        return (sumSquares / Double(samples.count)).squareRoot()
    }

    /// Downsample PCM16 from 24kHz to 16kHz (ratio 3:2) using linear interpolation.
    private static func downsample24kTo16k(_ data: Data) -> Data {
        let sampleCount = data.count / 2
        guard sampleCount > 0 else { return data }

        let inputSamples: [Int16] = data.withUnsafeBytes { raw in
            let buffer = raw.bindMemory(to: Int16.self)
            return Array(buffer)
        }

        // 24kHz → 16kHz: for every 3 input samples, produce 2 output samples
        let outputCount = (sampleCount * 2) / 3
        var output = [Int16](repeating: 0, count: outputCount)

        for i in 0..<outputCount {
            // Map output index to fractional input index
            let srcPos = Double(i) * 3.0 / 2.0
            let srcIndex = Int(srcPos)
            let frac = srcPos - Double(srcIndex)

            if srcIndex + 1 < sampleCount {
                let a = Double(inputSamples[srcIndex])
                let b = Double(inputSamples[srcIndex + 1])
                output[i] = Int16(clamping: Int(a + frac * (b - a)))
            } else if srcIndex < sampleCount {
                output[i] = inputSamples[srcIndex]
            }
        }

        return output.withUnsafeBytes { Data($0) }
    }

    /// Wrap raw PCM16 mono data in a minimal WAV header.
    private static func wrapPCM16AsWAV(_ pcmData: Data, sampleRate: Int32) -> Data {
        let channels: Int16 = 1
        let bitsPerSample: Int16 = 16
        let byteRate = sampleRate * Int32(channels) * Int32(bitsPerSample / 8)
        let blockAlign = channels * (bitsPerSample / 8)
        let dataSize = Int32(pcmData.count)
        let chunkSize = 36 + dataSize

        var header = Data(capacity: 44 + pcmData.count)
        header.append(contentsOf: "RIFF".utf8)
        header.append(contentsOf: withUnsafeBytes(of: chunkSize.littleEndian) { Array($0) })
        header.append(contentsOf: "WAVE".utf8)
        header.append(contentsOf: "fmt ".utf8)
        header.append(contentsOf: withUnsafeBytes(of: Int32(16).littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: Int16(1).littleEndian) { Array($0) }) // PCM
        header.append(contentsOf: withUnsafeBytes(of: channels.littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: sampleRate.littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: bitsPerSample.littleEndian) { Array($0) })
        header.append(contentsOf: "data".utf8)
        header.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian) { Array($0) })
        header.append(pcmData)
        return header
    }

    func finishAudioInput() async throws {
        guard socket != nil, isReady else { return }
        let message: [String: Any] = [
            "type": "input_audio_buffer.commit"
        ]
        try await sendJSON(message)
    }

    func sendToolOutput(callID: String, output: String) async throws {
        guard socket != nil, isReady else { throw OpenRockyRealtimeVoiceClientError.notConnected }

        // Send function call output back to GLM
        let createItem: [String: Any] = [
            "type": "conversation.item.create",
            "item": [
                "type": "function_call_output",
                "call_id": callID,
                "output": output
            ] as [String: Any]
        ]
        try await sendJSON(createItem)

        // Trigger the model to continue
        let createResponse: [String: Any] = [
            "type": "response.create"
        ]
        try await sendJSON(createResponse)
    }

    func speakText(_ text: String) async throws {
        // GLM handles TTS natively via the realtime session, no external injection needed
    }

    func cancelResponse() async throws {
        guard socket != nil, isReady else { return }
        isResponseInProgress = false
        let message: [String: Any] = ["type": "response.cancel"]
        try await sendJSON(message)
        rlog.info("GLM: sent response.cancel for interruption", category: "Voice")
    }

    // MARK: - Session Configuration

    private func sendSessionUpdate() async throws {
        var personaPrefix = ""
        if let name = configuration.characterName, !name.isEmpty {
            personaPrefix += "Your name is \(name). "
        }
        if let style = configuration.characterSpeakingStyle, !style.isEmpty {
            personaPrefix += "Speaking style: \(style). "
        }

        let voice = configuration.glmVoice ?? "tongtong"

        let instructions = personaPrefix + soulInstructions + """

Voice-specific rules:
- Keep spoken replies short and natural. Do not read markdown formatting aloud.
- When you need to call tools, do NOT narrate the process. Just call the tool silently.
- After receiving tool results, directly tell the user the final answer.
- Be concise: give the answer in one or two sentences when possible.
"""

        let tools = buildGLMTools()

        var sessionConfig: [String: Any] = [
            "modalities": ["audio", "text"],
            "voice": voice,
            "input_audio_format": "wav",
            "output_audio_format": "pcm",
            "instructions": instructions,
            "input_audio_noise_reduction": [
                "type": "near_field"
            ] as [String: Any],
            "turn_detection": [
                "type": "client_vad"
            ] as [String: Any],
            "beta_fields": [
                "chat_mode": "audio",
                "tts_source": "e2e",
                "auto_search": false,
                "greeting_config": [
                    "enable": true,
                    "content": configuration.characterGreeting ?? "你好，有什么可以帮你的吗？"
                ] as [String: Any]
            ] as [String: Any]
        ]

        if !tools.isEmpty {
            sessionConfig["tools"] = tools
            rlog.info("GLM: sending \(tools.count) consolidated tools", category: "Voice")
        }

        let message: [String: Any] = [
            "type": "session.update",
            "session": sessionConfig
        ]
        // GLM strictly validates tool parameters — null properties/required cause 422.
        // Serialize to JSON string and fix nulls before sending.
        try await sendSanitizedJSON(message)
    }

    // MARK: - Receive Loop

    private func receiveLoop() async {
        guard let socket else { return }
        rlog.info("GLM receive loop started", category: "Voice")
        var messageCount = 0
        do {
            while !Task.isCancelled {
                let message = try await socket.receive()
                messageCount += 1
                switch message {
                case .string(let text):
                    handleServerMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        handleServerMessage(text)
                    } else {
                        rlog.info("GLM: received binary data, \(data.count) bytes", category: "Voice")
                    }
                @unknown default:
                    break
                }
            }
        } catch {
            if !Task.isCancelled {
                rlog.error("GLM connection error after \(messageCount) messages: \(error)", category: "Voice")
                emit(.error("Voice connection lost. Please try again."))
            }
        }
        rlog.info("GLM receive loop ended, total messages: \(messageCount)", category: "Voice")
    }

    private func handleServerMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        let eventType = json["type"] as? String ?? ""

        switch eventType {
        case "session.created":
            rlog.info("GLM session.created received", category: "Voice")
            if !isReady {
                isReady = true
                emit(.sessionReady(model: modelID, features: features))
            }

        case "session.updated":
            rlog.info("GLM session.updated received - configuration accepted", category: "Voice")
            if !isReady {
                isReady = true
                emit(.sessionReady(model: modelID, features: features))
            }

        case "input_audio_buffer.speech_started":
            rlog.info("GLM: speech_started detected by server VAD", category: "Voice")
            emit(.inputSpeechStarted)
            emit(.status("Listening..."))

        case "input_audio_buffer.speech_stopped":
            rlog.info("GLM: speech_stopped detected by server VAD", category: "Voice")
            emit(.status("Processing..."))

        case "conversation.item.input_audio_transcription.completed":
            if let transcript = json["transcript"] as? String, !transcript.isEmpty {
                emit(.userTranscriptFinal(transcript))
            }

        case "response.audio_transcript.delta":
            if let delta = json["delta"] as? String, !delta.isEmpty {
                emit(.assistantTranscriptDelta(delta))
            }

        case "response.audio_transcript.done":
            // Don't emit assistantTranscriptFinal here — GLM sends text.done BEFORE audio.delta,
            // so emitting final transcript here triggers mic resume before audio playback starts.
            // Instead, buffer it and emit in response.done.
            if let transcript = json["transcript"] as? String, !transcript.isEmpty {
                pendingTranscript = transcript
            }

        case "response.created":
            rlog.info("GLM: response.created - model is generating", category: "Voice")
            isFirstAudioChunk = true

        case "response.audio.delta":
            if let audioData = json["delta"] as? String, !audioData.isEmpty {
                emit(.assistantAudioChunk(audioData))
            }

        case "response.audio.done":
            rlog.info("GLM: response.audio.done", category: "Voice")
            emit(.assistantAudioDone)

        case "response.function_call_arguments.done":
            let rawName = json["name"] as? String ?? ""
            let callID = json["call_id"] as? String ?? UUID().uuidString
            let rawArguments = json["arguments"] as? String ?? "{}"
            // Resolve consolidated tool call to original tool name
            let (resolvedName, resolvedArgs) = Self.resolveConsolidatedToolCall(name: rawName, arguments: rawArguments)
            rlog.info("GLM tool call: \(rawName) → \(resolvedName) callID=\(callID)", category: "Voice")
            emit(.toolCallRequested(name: resolvedName, arguments: resolvedArgs, callID: callID))

        case "response.done":
            isResponseInProgress = false
            // Emit final transcript AFTER all audio has been delivered
            if let transcript = pendingTranscript {
                emit(.assistantTranscriptFinal(transcript))
                pendingTranscript = nil
            } else {
                // Extract transcript from response output if available
                let resp = json["response"] as? [String: Any]
                let output = resp?["output"] as? [[String: Any]]
                for item in output ?? [] {
                    for content in item["content"] as? [[String: Any]] ?? [] {
                        if let t = content["transcript"] as? String, !t.isEmpty {
                            emit(.assistantTranscriptFinal(t))
                            break
                        }
                    }
                }
            }
            emit(.status("Ready for next input."))

        case "error":
            let errorObj = json["error"] as? [String: Any]
            let msg = errorObj?["message"] as? String ?? "Unknown GLM error"
            rlog.error("GLM error: \(msg)", category: "Voice")
            emit(.error("GLM: \(msg)"))

        case "heartbeat":
            // Connection keep-alive, ignore
            break

        default:
            rlog.info("GLM event: \(eventType)", category: "Voice")
        }
    }

    // MARK: - Consolidated Tool Definitions for GLM

    /// GLM can only handle ~10 tools. Consolidate 31+ tools into category-based tools.
    /// Each category tool has an `action` parameter that maps to individual tool names.
    private func buildGLMTools() -> [[String: Any]] {
        Self.consolidatedTools
    }

    /// Map a consolidated GLM tool call back to the original tool name + arguments.
    /// Returns (originalToolName, originalArguments) for the Toolbox to execute.
    static func resolveConsolidatedToolCall(name: String, arguments: String) -> (String, String) {
        guard let data = arguments.data(using: .utf8),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (name, arguments)
        }

        // delegate_task is a pass-through — just rename to "delegate-task"
        if name == "delegate_task" {
            return ("delegate-task", arguments)
        }

        let action = json.removeValue(forKey: "action") as? String ?? ""
        let mapping = consolidatedToolMapping[name] ?? [:]

        if let originalName = mapping[action] {
            // Re-serialize remaining args without the "action" key
            if let newData = try? JSONSerialization.data(withJSONObject: json),
               let newArgs = String(data: newData, encoding: .utf8) {
                return (originalName, newArgs)
            }
            return (originalName, arguments)
        }

        // No mapping found — pass through as-is
        return (name, arguments)
    }

    // MARK: - Consolidated Tool Definitions

    private static let consolidatedToolMapping: [String: [String: String]] = [
        "location_weather": [
            "get_location": "apple-location",
            "geocode": "apple-geocode",
            "weather": "weather",
            "nearby": "nearby-search"
        ],
        "calendar_reminders": [
            "list_events": "apple-calendar-list",
            "create_event": "apple-calendar-create",
            "list_reminders": "apple-reminder-list",
            "create_reminder": "apple-reminder-create",
            "set_alarm": "apple-alarm"
        ],
        "contacts_communication": [
            "search_contacts": "apple-contacts-search",
            "send_notification": "notification-schedule",
            "open_url": "open-url",
            "exit_app": "app-exit"
        ],
        "health": [
            "summary": "apple-health-summary",
            "metric": "apple-health-metric"
        ],
        "web_search": [
            "search": "web-search",
            "read_page": "browser-read",
            "open_browser": "browser-open"
        ],
        "files_memory": [
            "read_file": "file-read",
            "write_file": "file-write",
            "icloud_read": "icloud-read",
            "icloud_list": "icloud-list",
            "icloud_write": "icloud-write",
            "memory_get": "memory_get",
            "memory_write": "memory_write",
            "todo": "todo"
        ],
        "code_execute": [
            "shell": "shell-execute",
            "python": "python-execute",
            "ffmpeg": "ffmpeg-execute"
        ],
        "media_capture": [
            "camera": "camera-capture",
            "photo_pick": "photo-pick",
            "file_pick": "file-pick"
        ],
        "delegate_task": ["delegate": "delegate-task"]
    ]

    private static let consolidatedTools: [[String: Any]] = [
        [
            "type": "function",
            "name": "location_weather",
            "description": "Location and weather tools. Actions: get_location (get device GPS), geocode (address to coordinates, needs: address), weather (get weather, optional: latitude, longitude, label), nearby (search nearby places, needs: query)",
            "parameters": [
                "type": "object",
                "properties": [
                    "action": ["type": "string", "description": "One of: get_location, geocode, weather, nearby"] as [String: Any],
                    "address": ["type": "string", "description": "For geocode: place name or address"] as [String: Any],
                    "latitude": ["type": "number", "description": "For weather: latitude"] as [String: Any],
                    "longitude": ["type": "number", "description": "For weather: longitude"] as [String: Any],
                    "label": ["type": "string", "description": "For weather: location label"] as [String: Any],
                    "query": ["type": "string", "description": "For nearby: search query"] as [String: Any]
                ] as [String: Any],
                "required": ["action"]
            ] as [String: Any]
        ] as [String: Any],
        [
            "type": "function",
            "name": "calendar_reminders",
            "description": "Calendar, reminders and alarms. Actions: list_events (needs: start_date, end_date), create_event (needs: title, start_date; optional: end_date, location, notes, all_day), list_reminders (optional: include_completed), create_reminder (needs: title; optional: due_date, notes, priority), set_alarm (needs: time in ISO-8601; optional: title)",
            "parameters": [
                "type": "object",
                "properties": [
                    "action": ["type": "string", "description": "One of: list_events, create_event, list_reminders, create_reminder, set_alarm"] as [String: Any],
                    "title": ["type": "string", "description": "Event/reminder/alarm title"] as [String: Any],
                    "start_date": ["type": "string", "description": "Start date ISO-8601 with timezone e.g. 2026-04-12T09:00:00+08:00"] as [String: Any],
                    "end_date": ["type": "string", "description": "End date ISO-8601"] as [String: Any],
                    "location": ["type": "string", "description": "Event location"] as [String: Any],
                    "notes": ["type": "string", "description": "Notes"] as [String: Any],
                    "all_day": ["type": "boolean", "description": "All-day event flag"] as [String: Any],
                    "due_date": ["type": "string", "description": "Reminder due date ISO-8601"] as [String: Any],
                    "priority": ["type": "integer", "description": "Reminder priority 1-9"] as [String: Any],
                    "time": ["type": "string", "description": "Alarm time ISO-8601"] as [String: Any],
                    "include_completed": ["type": "boolean", "description": "Include completed reminders"] as [String: Any]
                ] as [String: Any],
                "required": ["action"]
            ] as [String: Any]
        ] as [String: Any],
        [
            "type": "function",
            "name": "contacts_communication",
            "description": "Contacts, notifications, URLs and app control. Actions: search_contacts (needs: query), send_notification (needs: title; optional: body, delay_seconds), open_url (needs: url), exit_app (quit the app, only when user explicitly asks; optional: farewell_message)",
            "parameters": [
                "type": "object",
                "properties": [
                    "action": ["type": "string", "description": "One of: search_contacts, send_notification, open_url, exit_app"] as [String: Any],
                    "query": ["type": "string", "description": "Contact search query"] as [String: Any],
                    "title": ["type": "string", "description": "Notification title"] as [String: Any],
                    "body": ["type": "string", "description": "Notification body"] as [String: Any],
                    "delay_seconds": ["type": "integer", "description": "Notification delay in seconds"] as [String: Any],
                    "url": ["type": "string", "description": "URL to open"] as [String: Any],
                    "farewell_message": ["type": "string", "description": "For exit_app: a brief farewell message before exiting"] as [String: Any]
                ] as [String: Any],
                "required": ["action"]
            ] as [String: Any]
        ] as [String: Any],
        [
            "type": "function",
            "name": "health",
            "description": "Apple Health data. Actions: summary (get health overview), metric (get specific metric, needs: metric_name e.g. steps/heartRate/sleepAnalysis; optional: days)",
            "parameters": [
                "type": "object",
                "properties": [
                    "action": ["type": "string", "description": "One of: summary, metric"] as [String: Any],
                    "metric_name": ["type": "string", "description": "Health metric: steps, heartRate, sleepAnalysis, activeEnergyBurned, etc."] as [String: Any],
                    "days": ["type": "integer", "description": "Number of days to look back"] as [String: Any]
                ] as [String: Any],
                "required": ["action"]
            ] as [String: Any]
        ] as [String: Any],
        [
            "type": "function",
            "name": "web_search",
            "description": "Web search and browsing. Actions: search (needs: query), read_page (needs: url), open_browser (needs: url)",
            "parameters": [
                "type": "object",
                "properties": [
                    "action": ["type": "string", "description": "One of: search, read_page, open_browser"] as [String: Any],
                    "query": ["type": "string", "description": "Search query"] as [String: Any],
                    "url": ["type": "string", "description": "URL to read or open"] as [String: Any]
                ] as [String: Any],
                "required": ["action"]
            ] as [String: Any]
        ] as [String: Any],
        [
            "type": "function",
            "name": "files_memory",
            "description": "File operations, external folder mounts, memory and todo. Actions: read_file (needs: path), write_file (needs: path, content), icloud_read (needs: container mount name, path), icloud_list (needs: container; optional: path), icloud_write (needs: container, path, content; mount must be read/write), memory_get (needs: key), memory_write (needs: key, value), todo (needs: action: list/add/complete/delete; optional: title, id). Mount names are configured by the user in Settings.",
            "parameters": [
                "type": "object",
                "properties": [
                    "action": ["type": "string", "description": "One of: read_file, write_file, icloud_read, icloud_list, icloud_write, memory_get, memory_write, todo"] as [String: Any],
                    "path": ["type": "string", "description": "File path"] as [String: Any],
                    "content": ["type": "string", "description": "File content to write"] as [String: Any],
                    "container": ["type": "string", "description": "Mount name configured by the user"] as [String: Any],
                    "key": ["type": "string", "description": "Memory key"] as [String: Any],
                    "value": ["type": "string", "description": "Memory value"] as [String: Any],
                    "title": ["type": "string", "description": "Todo title"] as [String: Any],
                    "id": ["type": "string", "description": "Todo ID"] as [String: Any]
                ] as [String: Any],
                "required": ["action"]
            ] as [String: Any]
        ] as [String: Any],
        [
            "type": "function",
            "name": "code_execute",
            "description": "Execute code on device. Actions: shell (needs: command), python (needs: code), ffmpeg (needs: command)",
            "parameters": [
                "type": "object",
                "properties": [
                    "action": ["type": "string", "description": "One of: shell, python, ffmpeg"] as [String: Any],
                    "command": ["type": "string", "description": "Shell or ffmpeg command"] as [String: Any],
                    "code": ["type": "string", "description": "Python code to execute"] as [String: Any]
                ] as [String: Any],
                "required": ["action"]
            ] as [String: Any]
        ] as [String: Any],
        [
            "type": "function",
            "name": "media_capture",
            "description": "Camera and photo. Actions: camera (take photo), photo_pick (pick from library), file_pick (pick any file)",
            "parameters": [
                "type": "object",
                "properties": [
                    "action": ["type": "string", "description": "One of: camera, photo_pick, file_pick"] as [String: Any]
                ] as [String: Any],
                "required": ["action"]
            ] as [String: Any]
        ] as [String: Any],
        [
            "type": "function",
            "name": "delegate_task",
            "description": "Delegate a complex multi-step task to a background agent that can use ALL tools. Use when the task requires multiple steps, combining info from different sources, or deep analysis.",
            "parameters": [
                "type": "object",
                "properties": [
                    "task": ["type": "string", "description": "Detailed task description for the agent"] as [String: Any]
                ] as [String: Any],
                "required": ["task"]
            ] as [String: Any]
        ] as [String: Any]
    ]

    // MARK: - Helpers

    private func sendJSON(_ object: [String: Any]) async throws {
        guard let socket else { throw OpenRockyRealtimeVoiceClientError.notConnected }
        let data = try JSONSerialization.data(withJSONObject: object)
        guard let text = String(data: data, encoding: .utf8) else { return }
        try await socket.send(.string(text))
    }

    /// Send JSON with null sanitization for GLM tool parameters.
    /// Replaces `"properties":null` → `"properties":{}` and `"required":null` → `"required":[]`
    /// because GLM strictly rejects null values in tool parameter schemas.
    private func sendSanitizedJSON(_ object: [String: Any]) async throws {
        guard let socket else { throw OpenRockyRealtimeVoiceClientError.notConnected }
        let data = try JSONSerialization.data(withJSONObject: object)
        guard var text = String(data: data, encoding: .utf8) else { return }
        text = text.replacingOccurrences(of: "\"properties\":null", with: "\"properties\":{}")
        text = text.replacingOccurrences(of: "\"required\":null", with: "\"required\":[]")
        try await socket.send(.string(text))
    }

    private func emit(_ event: OpenRockyRealtimeEvent) {
        eventSink?(event)
    }
}

enum GLMProtocolError: LocalizedError {
    case setupFailed(String)

    var errorDescription: String? {
        switch self {
        case .setupFailed(let msg): return "GLM: \(msg)"
        }
    }
}
