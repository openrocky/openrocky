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

        // Start receive loop before sending session.update
        receiveTask?.cancel()
        receiveTask = Task { await self.receiveLoop() }

        // Send session.update to configure the session
        try await sendSessionUpdate()

        // Wait briefly for session.created / session.updated
        // The receive loop handles these events asynchronously
        try await Task.sleep(nanoseconds: 500_000_000)

        if !isReady {
            // Give it a bit more time
            try await Task.sleep(nanoseconds: 1_500_000_000)
        }

        if !isReady {
            rlog.warning("GLM session not confirmed ready yet, proceeding anyway", category: "Voice")
            isReady = true
            emit(.sessionReady(model: modelID, features: features))
        }

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

    func sendAudioChunk(base64Audio: String) async throws {
        guard socket != nil, isReady else { return }

        // GLM expects WAV audio in input_audio_buffer.append
        // The incoming audio is PCM16 24kHz from the mic; we need to send it as-is
        // (GLM also accepts raw PCM in practice)
        let message: [String: Any] = [
            "type": "input_audio_buffer.append",
            "audio": base64Audio
        ]
        try await sendJSON(message)
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
            "model": modelID,
            "voice": voice,
            "modalities": ["audio", "text"],
            "input_audio_format": "pcm16",
            "output_audio_format": "pcm",
            "instructions": instructions,
            "turn_detection": [
                "type": "server_vad",
                "prefix_padding_ms": 400,
                "silence_duration_ms": 900,
                "threshold": 0.8
            ] as [String: Any]
        ]

        if !tools.isEmpty {
            sessionConfig["tools"] = tools
            sessionConfig["tool_choice"] = "auto"
        }

        let message: [String: Any] = [
            "type": "session.update",
            "session": sessionConfig
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
                rlog.error("GLM connection error: \(error)", category: "Voice")
                emit(.error("Voice connection lost. Please try again."))
            }
        }
    }

    private func handleServerMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        let eventType = json["type"] as? String ?? ""

        switch eventType {
        case "session.created", "session.updated":
            if !isReady {
                isReady = true
                rlog.info("GLM session ready: \(eventType)", category: "Voice")
                emit(.sessionReady(model: modelID, features: features))
            }

        case "input_audio_buffer.speech_started":
            emit(.inputSpeechStarted)
            emit(.status("Listening..."))

        case "input_audio_buffer.speech_stopped":
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
            if let transcript = json["transcript"] as? String {
                emit(.assistantTranscriptFinal(transcript))
            }

        case "response.audio.delta":
            if let audioData = json["delta"] as? String, !audioData.isEmpty {
                emit(.assistantAudioChunk(audioData))
            }

        case "response.audio.done":
            // Audio stream for this response is complete
            break

        case "response.function_call_arguments.done":
            let name = json["name"] as? String ?? ""
            let callID = json["call_id"] as? String ?? UUID().uuidString
            let arguments = json["arguments"] as? String ?? "{}"
            rlog.info("GLM tool call: \(name) callID=\(callID)", category: "Voice")
            emit(.toolCallRequested(name: name, arguments: arguments, callID: callID))

        case "response.done":
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
            rlog.debug("GLM unhandled event: \(eventType)", category: "Voice")
        }
    }

    // MARK: - Tool Conversion

    /// Convert OpenAI realtime tool definitions to GLM format.
    /// GLM uses the same format as OpenAI for function definitions.
    private func buildGLMTools() -> [[String: Any]] {
        var tools: [[String: Any]] = []

        for tool in realtimeTools {
            switch tool {
            case .function(let fn):
                let params = convertJSONValueDict(fn.parameters)
                var toolDef: [String: Any] = [
                    "type": "function",
                    "name": fn.name,
                    "description": fn.description
                ]
                if !params.isEmpty {
                    toolDef["parameters"] = params
                }
                tools.append(toolDef)
            case .mcp:
                break
            }
        }

        return tools
    }

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

enum GLMProtocolError: LocalizedError {
    case setupFailed(String)

    var errorDescription: String? {
        switch self {
        case .setupFailed(let msg): return "GLM: \(msg)"
        }
    }
}
