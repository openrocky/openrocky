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
final class OpenRockyOpenAIRealtimeVoiceClient: OpenRockyRealtimeVoiceClient {
    let modelID: String
    let features: OpenRockyRealtimeVoiceFeatures

    private let configuration: OpenRockyProviderConfiguration?
    private let realtimeConfiguration: OpenRockyRealtimeProviderConfiguration
    private let injectedService: (any OpenAIService)?
    private var session: OpenAIRealtimeSession?
    private var receiverTask: Task<Void, Never>?
    private var eventSink: (@Sendable (OpenRockyRealtimeEvent) -> Void)?
    private var isReady = false

    private let soulInstructions: String

    init(configuration: OpenRockyProviderConfiguration, realtimeConfiguration: OpenRockyRealtimeProviderConfiguration, soulInstructions: String) {
        self.configuration = configuration.normalized()
        self.realtimeConfiguration = realtimeConfiguration
        self.injectedService = nil
        self.modelID = "gpt-realtime-mini"
        self.soulInstructions = soulInstructions
        features = OpenRockyRealtimeVoiceFeatures(
            supportsTextInput: true,
            supportsAssistantStreaming: true,
            supportsToolCalls: true,
            supportsAudioOutput: true,
            needsMicSuspension: true
        )
    }

    /// Initialize with a pre-built service (for OpenAI-compatible providers).
    init(service: any OpenAIService, modelID: String, features: OpenRockyRealtimeVoiceFeatures, realtimeConfiguration: OpenRockyRealtimeProviderConfiguration, soulInstructions: String) {
        self.configuration = nil
        self.injectedService = service
        self.realtimeConfiguration = realtimeConfiguration
        self.modelID = modelID
        self.soulInstructions = soulInstructions
        self.features = features
    }

    func connect(eventSink: @escaping @Sendable (OpenRockyRealtimeEvent) -> Void) async throws {
        self.eventSink = eventSink
        emit(.status("Connecting realtime session..."))

        let service: any OpenAIService
        if let injectedService {
            service = injectedService
        } else if let configuration {
            service = try OpenRockyOpenAIServiceFactory.makeService(configuration: configuration)
        } else {
            throw OpenRockyRealtimeVoiceClientError.notConnected
        }
        let config = sessionConfiguration()
        rlog.info("Connecting model=\(modelID) voice=\(config.voice ?? "nil")", category: "Voice")
        let session = try await service.realtimeSession(
            model: modelID,
            configuration: config
        )

        self.session = session
        rlog.info("OpenAI realtime session created", category: "Voice")
        receiverTask?.cancel()
        receiverTask = Task {
            for await message in session.receiver {
                await self.handle(message)
            }
        }
    }

    func disconnect() async {
        rlog.info("OpenAI realtime disconnecting", category: "Voice")
        receiverTask?.cancel()
        receiverTask = nil
        session?.disconnect()
        session = nil
        isReady = false
    }

    func sendText(_ text: String) async throws {
        guard let session else {
            throw OpenRockyRealtimeVoiceClientError.notConnected
        }
        await session.sendMessage(
            OpenAIRealtimeConversationItemCreate(
                item: .init(role: "user", text: text)
            )
        )
        await session.sendMessage(OpenAIRealtimeResponseCreate())
        emit(.status("Typed input sent into the live runtime."))
    }

    func sendAudioChunk(base64Audio: String) async throws {
        guard let session, isReady else { return }
        await session.sendMessage(OpenAIRealtimeInputAudioBufferAppend(audio: base64Audio))
    }

    func finishAudioInput() async throws {
    }

    func sendToolOutput(callID: String, output: String) async throws {
        guard let session else {
            throw OpenRockyRealtimeVoiceClientError.notConnected
        }
        await session.sendMessage(OpenRockyRealtimeFunctionCallOutput(callID: callID, output: output))
        await session.sendMessage(OpenAIRealtimeResponseCreate())
    }

    private func handle(_ message: OpenAIRealtimeMessage) async {
        switch message {
        case .responseAudioDelta, .responseTranscriptDelta:
            break
        default:
            rlog.debug("OpenAI event: \(message)", category: "Voice")
        }
        switch message {
        case .sessionCreated:
            emit(.status("Realtime session created."))
        case .sessionUpdated:
            isReady = true
            emit(.sessionReady(model: modelID, features: features))
            emit(.status("Realtime session is ready."))
            // Send greeting if configured
            if let greeting = realtimeConfiguration.characterGreeting, !greeting.isEmpty, let session = self.session {
                Task {
                    await session.sendMessage(
                        OpenAIRealtimeConversationItemCreate(item: .init(role: "user", text: greeting))
                    )
                    await session.sendMessage(OpenAIRealtimeResponseCreate())
                }
            }
        case .responseCreated:
            isReady = true
        case .inputAudioBufferSpeechStarted:
            emit(.inputSpeechStarted)
            emit(.status("Listening..."))
        case .inputAudioTranscriptionDelta(let text):
            emit(.userTranscriptDelta(text))
        case .inputAudioTranscriptionCompleted(let text):
            emit(.userTranscriptFinal(text))
        case .inputAudioBufferTranscript(let text):
            emit(.userTranscriptFinal(text))
        case .responseTranscriptDelta(let text):
            emit(.assistantTranscriptDelta(text))
        case .responseTranscriptDone(let text):
            emit(.assistantTranscriptFinal(text))
        case .responseTextDelta(let text):
            emit(.assistantTranscriptDelta(text))
        case .responseTextDone(let text):
            emit(.assistantTranscriptFinal(text))
        case .responseAudioDelta(let audio):
            emit(.assistantAudioChunk(audio))
        case .responseFunctionCallArgumentsDone(let name, let arguments, let callID):
            rlog.info("OpenAI tool call: \(name) callID=\(callID)", category: "Voice")
            emit(.toolCallRequested(name: name, arguments: arguments, callID: callID))
        case .error(let text):
            rlog.error("OpenAI realtime error: \(text ?? "unknown")", category: "Voice")
            emit(.error(text ?? "Realtime session failed."))
        case .responseDone(let status, let details):
            if status != "completed" {
                let detail = details.map(Self.statusDetailsText) ?? ""
                rlog.warning("OpenAI response incomplete: status=\(status) \(detail)", category: "Voice")
                emit(.status("Realtime response status: \(status) \(detail)".trimmingCharacters(in: .whitespaces)))
            }
        default:
            break
        }
    }

    private func sessionConfiguration() -> OpenAIRealtimeSessionConfiguration {
        var personaPrefix = ""
        if let name = realtimeConfiguration.characterName, !name.isEmpty {
            personaPrefix += "Your name is \(name). "
        }
        if let style = realtimeConfiguration.characterSpeakingStyle, !style.isEmpty {
            personaPrefix += "Speaking style: \(style). "
        }

        let voice = realtimeConfiguration.openaiVoice ?? OpenRockyOpenAIVoice.alloy.rawValue

        return OpenAIRealtimeSessionConfiguration(
            inputAudioFormat: .pcm16,
            inputAudioTranscription: .init(model: "gpt-4o-mini-transcribe"),
            instructions: personaPrefix + soulInstructions + """

Voice-specific rules:
- Keep spoken replies short and natural. Do not read markdown formatting aloud.
- When you need to call tools, do NOT narrate the process. Do NOT say things like "let me check" or "I'm looking up". Just call the tool silently.
- After receiving tool results, directly tell the user the final answer. Do not describe what tool you used or how you got the result.
- Be concise: give the answer in one or two sentences when possible.
""",
            maxResponseOutputTokens: .int(1024),
            modalities: [.audio, .text],
            outputAudioFormat: .pcm16,
            temperature: 0.6,
            tools: OpenRockyToolbox.realtimeToolDefinitions(),
            toolChoice: .auto,
            turnDetection: .init(type: .serverVAD(prefixPaddingMs: 400, silenceDurationMs: 900, threshold: 0.8)),
            voice: voice
        )
    }

    private func emit(_ event: OpenRockyRealtimeEvent) {
        eventSink?(event)
    }

    private static func statusDetailsText(_ details: [String: Any]) -> String {
        details
            .map { "\($0.key)=\($0.value)" }
            .sorted()
            .joined(separator: ", ")
    }
}

enum OpenRockyRealtimeVoiceClientError: LocalizedError {
    case notConnected
    case unsupportedOperation(String)

    var errorDescription: String? {
        switch self {
        case .notConnected:
            "Realtime voice session is not connected."
        case .unsupportedOperation(let message):
            message
        }
    }
}
