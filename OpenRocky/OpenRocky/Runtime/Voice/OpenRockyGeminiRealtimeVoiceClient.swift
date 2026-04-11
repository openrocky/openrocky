//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation
@preconcurrency import SwiftOpenAI

@RealtimeActor
final class OpenRockyGeminiRealtimeVoiceClient: OpenRockyRealtimeVoiceClient {
    let modelID: String
    let features: OpenRockyRealtimeVoiceFeatures

    private let configuration: OpenRockyRealtimeProviderConfiguration
    private let soulInstructions: String
    private var socket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var eventSink: (@Sendable (OpenRockyRealtimeEvent) -> Void)?
    private var isReady = false

    init(configuration: OpenRockyRealtimeProviderConfiguration, soulInstructions: String) {
        self.configuration = configuration.normalized()
        self.modelID = "gemini-2.5-flash-native-audio-latest"
        self.soulInstructions = soulInstructions
        features = OpenRockyRealtimeVoiceFeatures(
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
        emit(.status("Connecting Gemini Live session..."))

        let baseHost = configuration.customHost ?? "wss://generativelanguage.googleapis.com"
        let urlString = "\(baseHost)/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent"
        guard let url = URL(string: urlString) else {
            throw OpenRockyRealtimeVoiceClientError.notConnected
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(credential)", forHTTPHeaderField: "Authorization")
        let socket = URLSession.shared.webSocketTask(with: request)
        self.socket = socket
        socket.resume()
        rlog.info("Gemini WebSocket connecting model=\(modelID)", category: "Voice")

        // Send setup message (must be first)
        try await sendSetup()

        // Wait for setupComplete
        let firstMessage = try await socket.receive()
        switch firstMessage {
        case .string(let text):
            rlog.debug("Gemini first response: \(text.prefix(300))", category: "Voice")
            if let data = text.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               json["setupComplete"] != nil {
                isReady = true
                rlog.info("Gemini session ready: model=\(modelID)", category: "Voice")
                emit(.sessionReady(model: modelID, features: features))
                emit(.status("Gemini Live session is ready."))
            } else {
                throw GeminiProtocolError.setupFailed("Unexpected response: \(text.prefix(300))")
            }
        case .data(let data):
            let text = String(data: data, encoding: .utf8) ?? ""
            rlog.debug("Gemini first response (data): \(text.prefix(300))", category: "Voice")
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               json["setupComplete"] != nil {
                isReady = true
                rlog.info("Gemini session ready: model=\(modelID)", category: "Voice")
                emit(.sessionReady(model: modelID, features: features))
                emit(.status("Gemini Live session is ready."))
            } else {
                throw GeminiProtocolError.setupFailed("Unexpected response: \(text.prefix(300))")
            }
        @unknown default:
            throw GeminiProtocolError.setupFailed("Unknown message type")
        }

        // Start receive loop
        receiveTask?.cancel()
        receiveTask = Task { await self.receiveLoop() }

        // Send greeting if configured
        if let greeting = configuration.characterGreeting, !greeting.isEmpty {
            try await sendClientContent(text: greeting)
        }
    }

    func disconnect() async {
        rlog.info("Gemini realtime disconnecting", category: "Voice")
        receiveTask?.cancel()
        receiveTask = nil
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        isReady = false
    }

    func sendText(_ text: String) async throws {
        guard socket != nil, isReady else { throw OpenRockyRealtimeVoiceClientError.notConnected }
        try await sendClientContent(text: text)
    }

    func sendAudioChunk(base64Audio: String) async throws {
        guard socket != nil, isReady else { return }
        let message: [String: Any] = [
            "realtimeInput": [
                "audio": [
                    "data": base64Audio,
                    "mimeType": "audio/pcm;rate=16000"
                ]
            ]
        ]
        try await sendJSON(message)
    }

    func finishAudioInput() async throws {
        // Server VAD handles this
    }

    func sendToolOutput(callID: String, output: String) async throws {
        guard socket != nil, isReady else { throw OpenRockyRealtimeVoiceClientError.notConnected }

        // Parse the output as JSON, or wrap as string
        let resultValue: Any
        if let data = output.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) {
            resultValue = parsed
        } else {
            resultValue = ["result": output]
        }

        // Extract tool name from callID context (not available here, use empty)
        let message: [String: Any] = [
            "toolResponse": [
                "functionResponses": [
                    [
                        "id": callID,
                        "name": pendingToolCalls[callID] ?? "",
                        "response": resultValue
                    ]
                ]
            ]
        ]
        pendingToolCalls.removeValue(forKey: callID)
        try await sendJSON(message)
    }

    func speakText(_ text: String) async throws {
        // Gemini handles TTS natively, no external injection needed
    }

    // MARK: - Internal State

    /// Track pending tool call IDs → names for the toolResponse
    private var pendingToolCalls: [String: String] = [:]

    // MARK: - Setup

    private func sendSetup() async throws {
        var personaPrefix = ""
        if let name = configuration.characterName, !name.isEmpty {
            personaPrefix += "Your name is \(name). "
        }
        if let style = configuration.characterSpeakingStyle, !style.isEmpty {
            personaPrefix += "Speaking style: \(style). "
        }

        let voice = configuration.geminiVoice ?? OpenRockyGeminiVoice.puck.rawValue

        let instructions = personaPrefix + soulInstructions + """

Voice-specific rules:
- Keep spoken replies short and natural. Do not read markdown formatting aloud.
- When you need to call tools, do NOT narrate the process. Just call the tool silently.
- After receiving tool results, directly tell the user the final answer.
- Be concise: give the answer in one or two sentences when possible.
"""

        let setup: [String: Any] = [
            "setup": [
                "model": "models/\(modelID)",
                "generationConfig": [
                    "responseModalities": ["AUDIO"],
                    "temperature": 0.7,
                    "speechConfig": [
                        "voiceConfig": [
                            "prebuiltVoiceConfig": [
                                "voiceName": voice
                            ]
                        ]
                    ]
                ] as [String: Any],
                "systemInstruction": [
                    "parts": [["text": instructions]]
                ],
                "tools": buildGeminiTools(),
                "realtimeInputConfig": [
                    "automaticActivityDetection": [
                        "disabled": false,
                        "startOfSpeechSensitivity": "START_SENSITIVITY_HIGH",
                        "endOfSpeechSensitivity": "END_SENSITIVITY_HIGH",
                        "prefixPaddingMs": 20,
                        "silenceDurationMs": 500
                    ] as [String: Any],
                    "activityHandling": "START_OF_ACTIVITY_INTERRUPTS"
                ] as [String: Any],
                "inputAudioTranscription": [:] as [String: Any],
                "outputAudioTranscription": [:] as [String: Any]
            ] as [String: Any]
        ]
        try await sendJSON(setup)
    }

    private func sendClientContent(text: String) async throws {
        let message: [String: Any] = [
            "clientContent": [
                "turns": [
                    [
                        "role": "user",
                        "parts": [["text": text]]
                    ]
                ],
                "turnComplete": true
            ] as [String: Any]
        ]
        try await sendJSON(message)
    }

    // MARK: - Receive Loop

    private func receiveLoop() async {
        guard let socket else { return }
        do {
            while !Task.isCancelled {
                let message = try await socket.receive()
                switch message {
                case .string(let text):
                    handleServerMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        handleServerMessage(text)
                    }
                @unknown default:
                    break
                }
            }
        } catch {
            if !Task.isCancelled {
                rlog.error("Gemini connection error: \(error)", category: "Voice")
                emit(.error("Voice connection lost. Please try again."))
            }
        }
    }

    private func handleServerMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        // Tool call from model
        if let toolCall = json["toolCall"] as? [String: Any],
           let functionCalls = toolCall["functionCalls"] as? [[String: Any]] {
            for call in functionCalls {
                let name = call["name"] as? String ?? ""
                let callID = call["id"] as? String ?? UUID().uuidString
                let args = call["args"] as? [String: Any] ?? [:]
                let argsJSON: String
                if let argsData = try? JSONSerialization.data(withJSONObject: args),
                   let argsStr = String(data: argsData, encoding: .utf8) {
                    argsJSON = argsStr
                } else {
                    argsJSON = "{}"
                }
                pendingToolCalls[callID] = name
                rlog.info("Gemini tool call: \(name) callID=\(callID)", category: "Voice")
                emit(.toolCallRequested(name: name, arguments: argsJSON, callID: callID))
            }
            return
        }

        // Tool call cancellation
        if json["toolCallCancellation"] != nil {
            rlog.warning("Gemini tool call cancelled", category: "Voice")
            return
        }

        // Server content (audio, text, transcription, interruption, turnComplete)
        if let serverContent = json["serverContent"] as? [String: Any] {
            // Interruption
            if serverContent["interrupted"] as? Bool == true {
                emit(.inputSpeechStarted)
                return
            }

            // Input transcription
            if let inputTx = serverContent["inputTranscription"] as? [String: Any],
               let txText = inputTx["text"] as? String, !txText.isEmpty {
                emit(.userTranscriptDelta(txText))
            }

            // Output transcription
            if let outputTx = serverContent["outputTranscription"] as? [String: Any],
               let txText = outputTx["text"] as? String, !txText.isEmpty {
                emit(.assistantTranscriptDelta(txText))
            }

            // Model turn (audio and/or text parts)
            if let modelTurn = serverContent["modelTurn"] as? [String: Any],
               let parts = modelTurn["parts"] as? [[String: Any]] {
                for part in parts {
                    if let inlineData = part["inlineData"] as? [String: Any],
                       let audioData = inlineData["data"] as? String {
                        emit(.assistantAudioChunk(audioData))
                    }
                    if let text = part["text"] as? String, !text.isEmpty {
                        emit(.assistantTranscriptDelta(text))
                    }
                }
            }

            // Turn complete
            if serverContent["turnComplete"] as? Bool == true {
                emit(.assistantTranscriptFinal(""))
                emit(.status("Ready for next input."))
            }

            return
        }

        // GoAway
        if json["goAway"] != nil {
            rlog.warning("Gemini GoAway received, session ending soon", category: "Voice")
            emit(.status("Gemini session ending soon..."))
            return
        }
    }

    // MARK: - Tool Conversion

    /// Convert OpenAI realtime tool definitions to Gemini functionDeclarations format.
    private func buildGeminiTools() -> [[String: Any]] {
        let openAITools = OpenRockyToolbox.realtimeToolDefinitions()
        var declarations: [[String: Any]] = []

        for tool in openAITools {
            switch tool {
            case .function(let fn):
                var decl: [String: Any] = [
                    "name": fn.name,
                    "description": fn.description
                ]
                let params = convertJSONValueDict(fn.parameters)
                if !params.isEmpty {
                    decl["parameters"] = convertSchemaToGemini(params)
                }
                declarations.append(decl)
            case .mcp:
                break
            }
        }

        return [["functionDeclarations": declarations]]
    }

    /// Convert OpenAIJSONValue dictionary to plain [String: Any].
    private func convertJSONValueDict(_ dict: [String: OpenAIJSONValue]) -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, value) in dict {
            result[key] = convertJSONValue(value)
        }
        return result
    }

    private func convertJSONValue(_ value: OpenAIJSONValue) -> Any {
        switch value {
        case .null: return NSNull()
        case .bool(let b): return b
        case .int(let i): return i
        case .double(let d): return d
        case .string(let s): return s
        case .array(let arr): return arr.map { convertJSONValue($0) }
        case .object(let obj): return convertJSONValueDict(obj)
        }
    }

    /// Convert OpenAI JSON Schema dict to Gemini format (uppercase types).
    private func convertSchemaToGemini(_ schema: [String: Any]) -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, value) in schema {
            if key == "type", let typeStr = value as? String {
                result["type"] = typeStr.uppercased()
            } else if let dict = value as? [String: Any] {
                result[key] = convertSchemaToGemini(dict)
            } else if let arr = value as? [[String: Any]] {
                result[key] = arr.map { convertSchemaToGemini($0) }
            } else {
                result[key] = value
            }
        }
        return result
    }

    // MARK: - Helpers

    private func sendJSON(_ object: [String: Any]) async throws {
        guard let socket else { throw OpenRockyRealtimeVoiceClientError.notConnected }
        let data = try JSONSerialization.data(withJSONObject: object)
        guard let text = String(data: data, encoding: .utf8) else { return }
        try await socket.send(.string(text))
    }

    private func emit(_ event: OpenRockyRealtimeEvent) {
        eventSink?(event)
    }
}

enum GeminiProtocolError: LocalizedError {
    case setupFailed(String)

    var errorDescription: String? {
        switch self {
        case .setupFailed(let msg): return "Gemini: \(msg)"
        }
    }
}
