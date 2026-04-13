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
                    rlog.info("GLM: client VAD detected speech end, committing (rms=\(rms))", category: "Voice")
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
                if isFirstAudioChunk, let rawData = Data(base64Encoded: audioData) {
                    isFirstAudioChunk = false
                    // GLM prepends a fixed audio preamble tone to every response.
                    // Skip the first 28800 bytes (14400 samples = 600ms at 24kHz) to remove it.
                    let skipBytes = min(28800, rawData.count / 4) // Don't skip more than 25% of chunk
                    let trimmed = rawData.dropFirst(skipBytes)
                    rlog.info("GLM: audio.delta first chunk \(rawData.count)bytes, trimmed \(skipBytes)bytes", category: "Voice")
                    if trimmed.count > 0 {
                        emit(.assistantAudioChunk(trimmed.base64EncodedString()))
                    }
                } else {
                    emit(.assistantAudioChunk(audioData))
                }
            }

        case "response.audio.done":
            rlog.info("GLM: response.audio.done", category: "Voice")
            break

        case "response.function_call_arguments.done":
            let name = json["name"] as? String ?? ""
            let callID = json["call_id"] as? String ?? UUID().uuidString
            let arguments = json["arguments"] as? String ?? "{}"
            rlog.info("GLM tool call: \(name) callID=\(callID)", category: "Voice")
            emit(.toolCallRequested(name: name, arguments: arguments, callID: callID))

        case "response.done":
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

    // MARK: - Tool Conversion

    /// Convert OpenAI realtime tool definitions to GLM flat format.
    /// GLM docs show flat format: {type, name, description, parameters} without function wrapper.
    private func buildGLMTools() -> [[String: Any]] {
        var tools: [[String: Any]] = []

        for tool in realtimeTools {
            switch tool {
            case .function(let fn):
                let converted = convertJSONValueDict(fn.parameters)
                var properties: [String: Any]
                if let p = converted["properties"] as? [String: Any], !p.isEmpty {
                    properties = p
                } else {
                    // GLM server converts empty {} to null internally.
                    // Add a dummy property so properties is never empty.
                    properties = ["_placeholder": ["type": "string", "description": "unused"] as [String: Any]]
                }
                let required: [Any]
                if let r = converted["required"] as? [Any], !r.isEmpty {
                    required = r
                } else {
                    // GLM server converts empty [] to null internally.
                    // Use a non-empty placeholder.
                    required = ["_placeholder"]
                }

                tools.append([
                    "type": "function",
                    "name": fn.name,
                    "description": fn.description,
                    "parameters": [
                        "type": "object",
                        "properties": properties,
                        "required": required
                    ] as [String: Any]
                ])
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
