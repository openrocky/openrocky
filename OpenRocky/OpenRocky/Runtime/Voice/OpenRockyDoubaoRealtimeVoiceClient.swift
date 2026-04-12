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
final class OpenRockyDoubaoRealtimeVoiceClient: OpenRockyRealtimeVoiceClient {
    let modelID: String
    let features: OpenRockyRealtimeVoiceFeatures

    private let configuration: OpenRockyRealtimeProviderConfiguration
    private let soulInstructions: String
    private var socket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var eventSink: (@Sendable (OpenRockyRealtimeEvent) -> Void)?
    private var isReady = false
    private var sessionID: String = ""
    private var hasPendingFinal = false
    /// When true, audio from Doubao's own dialog model is played.
    /// When false (after we inject ChatTTSText), only our TTS audio plays.
    private var shouldPlayAudio = false

    /// Tracks whether Doubao's built-in dialog model is currently processing.
    /// When true, `speakText` calls are queued until the dialog cycle completes.
    private var isDialogModelActive = false
    /// Text queued for TTS while the dialog model was still active.
    private var pendingSpeakText: String?

    init(configuration: OpenRockyRealtimeProviderConfiguration, soulInstructions: String = "", realtimeTools: [OpenAIRealtimeSessionConfiguration.RealtimeTool] = []) {
        self.configuration = configuration.normalized()
        self.modelID = "doubao-e2e-voice"
        self.soulInstructions = soulInstructions
        features = OpenRockyRealtimeVoiceFeatures(
            supportsTextInput: true,
            supportsAssistantStreaming: false,  // Chat model handles response
            supportsToolCalls: true,            // Chat model handles tools
            supportsAudioOutput: true,
            needsMicSuspension: false           // Keep mic active — Doubao paces TTS based on incoming audio
        )
    }

    func connect(eventSink: @escaping @Sendable (OpenRockyRealtimeEvent) -> Void) async throws {
        guard let credential = configuration.credential, !credential.isEmpty else {
            throw OpenRockyRealtimeVoiceClientError.notConnected
        }

        self.eventSink = eventSink
        sessionID = UUID().uuidString

        let baseHost = configuration.customHost ?? "wss://openspeech.bytedance.com"
        let url = URL(string: "\(baseHost)/api/v3/realtime/dialogue")!
        var request = URLRequest(url: url)
        request.setValue(configuration.doubaoAppId ?? "", forHTTPHeaderField: "X-Api-App-ID")
        request.setValue(credential, forHTTPHeaderField: "X-Api-Access-Key")
        request.setValue("volc.speech.dialog", forHTTPHeaderField: "X-Api-Resource-Id")
        let appKey = configuration.doubaoAppKey.flatMap({ $0.isEmpty ? nil : $0 }) ?? "PlgvMymc7f3tQnJ6"
        request.setValue(appKey, forHTTPHeaderField: "X-Api-App-Key")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Api-Connect-Id")

        let socket = URLSession.shared.webSocketTask(with: request)
        self.socket = socket
        socket.resume()
        emit(.status("Connecting Doubao realtime voice..."))

        // StartConnection (event=1)
        try await sendBinaryRequest(event: 1, payload: "{}".data(using: .utf8)!, includeSessionID: false)
        let startResp = try await receiveOnce()
        if startResp.isError {
            throw DoubaoProtocolError.connectionFailed(startResp.errorMessage ?? "StartConnection failed")
        }
        emit(.status("Doubao connection established."))

        // StartSession (event=100)
        let sessionConfig = buildSessionConfig()
        if let debugJSON = try? JSONSerialization.data(withJSONObject: sessionConfig, options: .prettyPrinted),
           let debugStr = String(data: debugJSON, encoding: .utf8) {
            rlog.debug("Doubao session config:\n\(debugStr)", category: "Voice")
        }
        let sessionData = try JSONSerialization.data(withJSONObject: sessionConfig)
        try await sendBinaryRequest(event: 100, payload: sessionData, includeSessionID: true)
        let sessionResp = try await receiveOnce()
        if sessionResp.isError {
            throw DoubaoProtocolError.connectionFailed(sessionResp.errorMessage ?? "StartSession failed")
        }

        isReady = true
        rlog.info("Doubao realtime voice connected and ready", category: "Voice")
        emit(.sessionReady(model: modelID, features: features))
        emit(.status("Doubao realtime voice is ready."))

        // Start receive loop
        receiveTask?.cancel()
        receiveTask = Task { await self.receiveLoop() }

        // Say hello
        try await sendSayHello()
    }

    func disconnect() async {
        rlog.info("Doubao realtime disconnecting", category: "Voice")
        receiveTask?.cancel()
        receiveTask = nil

        // Try to send FinishSession and FinishConnection
        if socket != nil {
            try? await sendBinaryRequest(event: 102, payload: "{}".data(using: .utf8)!, includeSessionID: true)
            try? await sendBinaryRequest(event: 2, payload: "{}".data(using: .utf8)!, includeSessionID: false)
        }

        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        isReady = false
    }

    func sendText(_ text: String) async throws {
        guard socket != nil, isReady else { throw OpenRockyRealtimeVoiceClientError.notConnected }
        let payload: [String: Any] = ["content": text]
        let data = try JSONSerialization.data(withJSONObject: payload)
        try await sendBinaryRequest(event: 501, payload: data, includeSessionID: true)
        emit(.status("Text sent to Doubao."))
    }

    private var audioChunkCount: Int = 0
    private var totalAudioBytes: Int = 0

    func sendAudioChunk(base64Audio: String) async throws {
        guard socket != nil, isReady else {
            rlog.debug("Doubao sendAudioChunk skipped (socket=\(socket != nil), isReady=\(isReady))", category: "Audio")
            return
        }
        guard let audioData = Data(base64Encoded: base64Audio) else {
            rlog.warning("Doubao sendAudioChunk base64 decode failed, len=\(base64Audio.count)", category: "Audio")
            return
        }
        audioChunkCount += 1
        totalAudioBytes += audioData.count
        if audioChunkCount % 50 == 1 {
            rlog.debug("Doubao audio #\(audioChunkCount): \(audioData.count)B (total: \(totalAudioBytes)B)", category: "Audio")
        }
        try await sendAudioRequest(event: 200, audioData: audioData)
    }

    func finishAudioInput() async throws {
        // Server VAD handles this automatically
    }

    func sendToolOutput(callID: String, output: String) async throws {
        // Tool calls handled by chat model, not Doubao protocol
    }

    /// Send text to Doubao for TTS synthesis via SayHello (event 300).
    /// If the dialog model is still active, the text is queued and sent
    /// automatically once the dialog cycle finishes.
    func speakText(_ text: String) async throws {
        guard socket != nil, isReady else {
            rlog.warning("Doubao speakText: not ready", category: "Voice")
            return
        }
        guard !text.isEmpty else { return }

        if isDialogModelActive {
            rlog.debug("Doubao speakText: dialog active, queueing \(text.count) chars", category: "Voice")
            pendingSpeakText = text
            return
        }

        try await sendSpeakTextNow(text)
    }

    private func sendSpeakTextNow(_ text: String) async throws {
        rlog.info("Doubao speakText sending \(text.count) chars", category: "Voice")
        let payload: [String: Any] = ["content": text]
        let data = try JSONSerialization.data(withJSONObject: payload)
        try await sendBinaryRequest(event: 300, payload: data, includeSessionID: true)
        rlog.debug("Doubao speakText sent", category: "Voice")
    }

    private func flushPendingSpeakText() {
        guard let text = pendingSpeakText else { return }
        pendingSpeakText = nil
        rlog.debug("Doubao flushing queued speakText (\(text.count) chars)", category: "Voice")
        Task { [weak self] in
            try? await self?.sendSpeakTextNow(text)
        }
    }

    // MARK: - Session Configuration

    private func buildSessionConfig() -> [String: Any] {
        // Map display model ID to API model version
        let apiModel = "1.2.1.1" // O2.0

        return [
            "asr": [
                "extra": [
                    "end_smooth_window_ms": 2000,
                    "begin_smooth_window_ms": 300
                ]
            ],
            "tts": [
                "speaker": configuration.doubaoSpeaker ?? OpenRockyDoubaoSpeaker.vivi.rawValue,
                "audio_config": [
                    "channel": 1,
                    "format": "pcm",
                    "sample_rate": 24000
                ]
            ],
            "dialog": [
                "bot_name": configuration.characterName ?? "OpenRocky",
                "system_role": soulInstructions.isEmpty
                    ? "You are a helpful assistant. Keep replies short and natural."
                    : soulInstructions,
                "speaking_style": configuration.characterSpeakingStyle ?? "简洁明了，语速适中，语调自然。",
                "location": ["city": "北京"],
                "extra": [
                    "strict_audit": false,
                    "recv_timeout": 120,
                    "input_mod": "audio",
                    "model": apiModel
                ] as [String: Any]
            ] as [String: Any]
        ]
    }

    private func sendSayHello() async throws {
        let payload: [String: Any] = ["content": configuration.characterGreeting ?? "你好，有什么可以帮助你的？"]
        let data = try JSONSerialization.data(withJSONObject: payload)
        try await sendBinaryRequest(event: 300, payload: data, includeSessionID: true)
    }

    // MARK: - Binary Protocol

    private func generateHeader(messageType: UInt8 = 0x01, flags: UInt8 = 0x04, serialization: UInt8 = 0x01, compression: UInt8 = 0x00) -> Data {
        var header = Data(count: 4)
        header[0] = 0x11 // version=1, header_size=1
        header[1] = (messageType << 4) | flags
        header[2] = (serialization << 4) | compression
        header[3] = 0x00 // reserved
        return header
    }

    private func sendBinaryRequest(event: UInt32, payload: Data, includeSessionID: Bool) async throws {
        guard let socket else { throw OpenRockyRealtimeVoiceClientError.notConnected }

        var message = Data()
        // Header: CLIENT_FULL_REQUEST(1), MSG_WITH_EVENT(4), JSON(1), NO_COMPRESSION(0)
        message.append(generateHeader())
        // Event ID (4 bytes big-endian)
        message.append(contentsOf: withUnsafeBytes(of: event.bigEndian) { Array($0) })

        if includeSessionID {
            let sessionData = sessionID.data(using: .utf8)!
            let sessionLen = UInt32(sessionData.count).bigEndian
            message.append(contentsOf: withUnsafeBytes(of: sessionLen) { Array($0) })
            message.append(sessionData)
        }

        // Raw payload (no compression)
        let payloadLen = UInt32(payload.count).bigEndian
        message.append(contentsOf: withUnsafeBytes(of: payloadLen) { Array($0) })
        message.append(payload)

        try await socket.send(.data(message))
    }

    private func sendAudioRequest(event: UInt32, audioData: Data) async throws {
        guard let socket else { throw OpenRockyRealtimeVoiceClientError.notConnected }

        var message = Data()
        // Header: CLIENT_AUDIO_ONLY_REQUEST(2), MSG_WITH_EVENT(4), NO_SERIALIZATION(0), NO_COMPRESSION(0)
        message.append(generateHeader(messageType: 0x02, flags: 0x04, serialization: 0x00, compression: 0x00))
        // Event ID
        message.append(contentsOf: withUnsafeBytes(of: event.bigEndian) { Array($0) })
        // Session ID
        let sessionData = sessionID.data(using: .utf8)!
        let sessionLen = UInt32(sessionData.count).bigEndian
        message.append(contentsOf: withUnsafeBytes(of: sessionLen) { Array($0) })
        message.append(sessionData)
        // Raw audio (no compression)
        let payloadLen = UInt32(audioData.count).bigEndian
        message.append(contentsOf: withUnsafeBytes(of: payloadLen) { Array($0) })
        message.append(audioData)

        try await socket.send(.data(message))
    }

    // MARK: - Receive & Parse

    private struct ParsedResponse {
        var messageType: UInt8 = 0
        var flags: UInt8 = 0
        var serialization: UInt8 = 0
        var compression: UInt8 = 0
        var event: UInt32 = 0
        var sessionID: String = ""
        var payload: Data = Data()
        var errorCode: UInt32 = 0
        var isError: Bool = false
        var errorMessage: String?

        var jsonPayload: [String: Any]? {
            try? JSONSerialization.jsonObject(with: payload) as? [String: Any]
        }
    }

    private func receiveOnce() async throws -> ParsedResponse {
        guard let socket else { throw OpenRockyRealtimeVoiceClientError.notConnected }
        let message = try await socket.receive()
        switch message {
        case .data(let data):
            return parseResponse(data)
        case .string(let text):
            // Unexpected text frame
            var resp = ParsedResponse()
            resp.isError = true
            resp.errorMessage = "Unexpected text: \(text.prefix(200))"
            return resp
        @unknown default:
            return ParsedResponse()
        }
    }

    private func parseResponse(_ data: Data) -> ParsedResponse {
        guard data.count >= 4 else { return ParsedResponse() }

        var resp = ParsedResponse()
        let headerSize = Int(data[0] & 0x0F)
        resp.messageType = data[1] >> 4
        resp.flags = data[1] & 0x0F
        resp.serialization = data[2] >> 4
        resp.compression = data[2] & 0x0F

        let headerBytes = headerSize * 4
        guard data.count > headerBytes else { return resp }
        var payload = data.subdata(in: headerBytes..<data.count)

        let serverFullResponse: UInt8 = 0x09
        let serverAck: UInt8 = 0x0B
        let serverError: UInt8 = 0x0F

        if resp.messageType == serverFullResponse || resp.messageType == serverAck {
            var offset = 0
            // Check NEG_SEQUENCE flag (bit 1)
            if resp.flags & 0x02 > 0, payload.count >= offset + 4 {
                offset += 4
            }
            // Check MSG_WITH_EVENT flag (bit 2)
            if resp.flags & 0x04 > 0, payload.count >= offset + 4 {
                resp.event = readUInt32(payload, at: offset)
                offset += 4
            }

            guard payload.count >= offset + 4 else { return resp }
            let sessionLen = Int(readUInt32(payload, at: offset))
            offset += 4
            if sessionLen > 0, payload.count >= offset + sessionLen {
                resp.sessionID = String(data: payload.subdata(in: offset..<offset+sessionLen), encoding: .utf8) ?? ""
                offset += sessionLen
            }

            guard payload.count >= offset + 4 else { return resp }
            let payloadSize = Int(readUInt32(payload, at: offset))
            offset += 4
            if payloadSize > 0, payload.count >= offset + payloadSize {
                var payloadData = payload.subdata(in: offset..<offset+payloadSize)
                if resp.compression == 0x01 { // GZIP
                    payloadData = (try? gzipDecompress(payloadData)) ?? payloadData
                }
                resp.payload = payloadData
            }
        } else if resp.messageType == serverError {
            resp.isError = true
            if payload.count >= 4 {
                resp.errorCode = readUInt32(payload, at: 0)
                payload = payload.subdata(in: 4..<payload.count)
            }
            if payload.count >= 4 {
                let payloadSize = Int(readUInt32(payload, at: 0))
                var payloadData = payload.subdata(in: 4..<min(4+payloadSize, payload.count))
                if resp.compression == 0x01 {
                    payloadData = (try? gzipDecompress(payloadData)) ?? payloadData
                }
                resp.payload = payloadData
                if resp.serialization == 0x01, // JSON
                   let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] {
                    resp.errorMessage = json["message"] as? String ?? json["error"] as? String
                } else {
                    resp.errorMessage = String(data: payloadData, encoding: .utf8)
                }
            }
        }

        return resp
    }

    private func readUInt32(_ data: Data, at offset: Int) -> UInt32 {
        guard data.count >= offset + 4 else { return 0 }
        return UInt32(data[offset]) << 24
            | UInt32(data[offset+1]) << 16
            | UInt32(data[offset+2]) << 8
            | UInt32(data[offset+3])
    }

    // MARK: - Receive Loop

    private func receiveLoop() async {
        guard let socket else { return }
        rlog.info("Doubao receiveLoop started", category: "Voice")
        do {
            while !Task.isCancelled {
                let message = try await socket.receive()
                switch message {
                case .data(let data):
                    handleServerResponse(parseResponse(data))
                case .string(let text):
                    emit(.error("Doubao: unexpected text frame — \(text.prefix(200))"))
                @unknown default:
                    break
                }
            }
            rlog.info("Doubao receiveLoop ended (cancelled)", category: "Voice")
        } catch {
            rlog.error("Doubao receiveLoop error: \(error)", category: "Voice")
            if !Task.isCancelled {
                emit(.error("Voice connection lost. Please try again."))
            }
        }
    }

    private func handleServerResponse(_ resp: ParsedResponse) {
        let serverAck: UInt8 = 0x0B

        if resp.isError {
            let msg = resp.errorMessage ?? "unknown"
            rlog.error("Doubao server error (\(resp.errorCode)): \(msg)", category: "Voice")
            if msg.contains("IdleTimeout") || msg.contains("52000042") || resp.errorCode == 52000042 {
                emit(.error("Voice session timed out due to inactivity. Please start a new session."))
            } else {
                emit(.error("Doubao error (\(resp.errorCode)): \(msg)"))
            }
            return
        }

        // SERVER_ACK with binary audio data (float32 PCM from Doubao)
        // Only play audio from our ChatTTSText injection, not from dialog model
        if resp.messageType == serverAck {
            // serverAck fires per audio frame — skip logging to avoid noise
            if shouldPlayAudio, !resp.payload.isEmpty {
                let pcm16 = convertFloat32ToPCM16(resp.payload)
                let base64Audio = pcm16.base64EncodedString()
                emit(.assistantAudioChunk(base64Audio))
            }
            return
        }

        // SERVER_FULL_RESPONSE — handle by event ID
        let json = resp.jsonPayload
        rlog.debug("Doubao event=\(resp.event) type=\(resp.messageType) payload=\(resp.payload.count)B", category: "Voice")
        switch resp.event {
        case 450:
            // ASRInfo — speech detected, interrupt playback
            hasPendingFinal = false
            shouldPlayAudio = false
            isDialogModelActive = false
            pendingSpeakText = nil
            emit(.inputSpeechStarted)
            emit(.status("Listening..."))

        case 451:
            // ASRResponse — streaming speech recognition result
            if let results = json?["results"] as? [[String: Any]], let first = results.first {
                let text = first["text"] as? String ?? ""
                let isInterim = first["is_interim"] as? Bool ?? true
                if isInterim {
                    if !text.isEmpty { emit(.userTranscriptDelta(text)) }
                } else {
                    if !text.isEmpty { emit(.userTranscriptFinal(text)) }
                }
            }

        case 459:
            // ASREnded — user stopped speaking, ensure dialog-model TTS won't play
            shouldPlayAudio = false
            emit(.status("Processing..."))

        case 350:
            // TTSSentenceStart — check tts_type to decide whether to play audio
            if let j = json, let jsonData = try? JSONSerialization.data(withJSONObject: j, options: .prettyPrinted),
               let jsonStr = String(data: jsonData, encoding: .utf8) {
                rlog.debug("Doubao TTSSentenceStart: \(jsonStr.prefix(300))", category: "Voice")
            }
            let ttsType = json?["tts_type"] as? String ?? ""
            shouldPlayAudio = (ttsType == "chat_tts_text")
            // Emit text
            if shouldPlayAudio, let text = json?["text"] as? String, !text.isEmpty {
                emit(.assistantTranscriptDelta(text))
            }

        case 351:
            // TTSSentenceEnd
            if shouldPlayAudio {
                hasPendingFinal = true
            }

        case 359:
            // TTSEnded
            if shouldPlayAudio {
                finalizeTurnIfNeeded()
            } else {
                // Dialog model's TTS cycle completed — flush any queued speakText
                flushPendingSpeakText()
            }
            shouldPlayAudio = false

        case 154:
            // Usage report
            finalizeTurnIfNeeded()

        case 550:
            // ChatResponse from dialog model — ignore (chat model handles response)
            break

        case 553:
            // ChatStarted — dialog model begins, suppress its TTS
            isDialogModelActive = true
            shouldPlayAudio = false

        case 559:
            // ChatEnded — dialog model finished its text generation
            isDialogModelActive = false
            // If there's pending text and no TTS cycle followed from dialog model,
            // flush it now. If TTS cycle is active, flush will happen at event 359.
            if !shouldPlayAudio {
                flushPendingSpeakText()
            }

        case 50, 150, 152, 153:
            // Connection/session lifecycle
            break

        default:
            break
        }
    }

    private func finalizeTurnIfNeeded() {
        guard hasPendingFinal else { return }
        hasPendingFinal = false
        emit(.assistantTranscriptFinal(""))
        emit(.status("Ready for next input."))
    }

    // MARK: - Audio Conversion

    /// Doubao returns float32 PCM audio; the player expects int16 PCM.
    private func convertFloat32ToPCM16(_ data: Data) -> Data {
        let floatCount = data.count / 4
        var output = Data(count: floatCount * 2)
        data.withUnsafeBytes { src in
            output.withUnsafeMutableBytes { dst in
                let floats = src.bindMemory(to: Float32.self)
                let int16s = dst.bindMemory(to: Int16.self)
                for i in 0..<floatCount {
                    let clamped = min(max(floats[i], -1.0), 1.0)
                    int16s[i] = Int16(clamped * 32767)
                }
            }
        }
        return output
    }

    // MARK: - Decompression (server may respond with gzip)

    private func gzipDecompress(_ data: Data) throws -> Data {
        let nsData = data as NSData
        return (try? nsData.decompressed(using: .zlib) as Data) ?? data
    }

    // MARK: - Helpers

    private func emit(_ event: OpenRockyRealtimeEvent) {
        eventSink?(event)
    }
}

enum DoubaoProtocolError: LocalizedError {
    case connectionFailed(String)

    var errorDescription: String? {
        switch self {
        case .connectionFailed(let msg): return "Doubao: \(msg)"
        }
    }
}
