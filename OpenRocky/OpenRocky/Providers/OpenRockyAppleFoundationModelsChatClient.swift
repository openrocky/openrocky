//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-04-10
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation
import ChatClientKit

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, *)
final class OpenRockyAppleFoundationModelsChatClient: ChatClient, @unchecked Sendable {
    nonisolated let errorCollector: ErrorCollector

    nonisolated init() {
        errorCollector = .new()
    }

    /// Whether this device can potentially run Apple Foundation Models (iOS 26+ real device).
    /// Does NOT access the model runtime — safe to call during view rendering.
    /// Actual model readiness is checked at usage time in `streamingChat`.
    nonisolated static var isAvailable: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        if #available(iOS 26.0, *) {
            return true
        }
        return false
        #endif
    }

    /// Checks real model availability at runtime. Call this from async contexts only,
    /// never during view rendering. Returns false if models are not downloaded yet.
    nonisolated static func checkModelReady() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return SystemLanguageModel.default.isAvailable
        #endif
    }

    nonisolated func chat(body: ChatRequestBody) async throws -> ChatResponse {
        var chunks: [ChatResponseChunk] = []
        for try await chunk in try await streamingChat(body: body) {
            chunks.append(chunk)
        }
        return ChatResponse(chunks: chunks)
    }

    nonisolated func streamingChat(body: ChatRequestBody) async throws -> AnyAsyncSequence<ChatResponseChunk> {
        let prompt = Self.buildPrompt(from: body)
        let hasTools = body.tools?.isEmpty == false

        // Tools are passed at session init, not at respond time.
        let session: LanguageModelSession
        if hasTools {
            let tool = OpenRockyFMToolDispatcher()
            session = LanguageModelSession(tools: [tool])
        } else {
            session = LanguageModelSession()
        }

        let mapped = AsyncThrowingStream<ChatResponseChunk, Error> { continuation in
            Task {
                do {
                    if hasTools {
                        // Use native FM tool calling — the session handles the
                        // tool loop internally (call tool → feed result → repeat).
                        let response = try await session.respond(to: prompt)
                        continuation.yield(.text(response.content))
                    } else {
                        // No tools — stream the response for better UX
                        var previousText = ""
                        let stream = session.streamResponse(to: prompt)
                        for try await snapshot in stream {
                            let current = snapshot.content
                            if current.count > previousText.count {
                                let delta = String(current.dropFirst(previousText.count))
                                continuation.yield(.text(delta))
                                previousText = current
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
        return AnyAsyncSequence(mapped)
    }

    /// Build the prompt from the chat request body.
    private nonisolated static func buildPrompt(from body: ChatRequestBody) -> String {
        var parts: [String] = []

        for message in body.messages {
            switch message {
            case .system(let content, _), .developer(let content, _):
                parts.append("[System] \(flattenContent(content))")
            case .user(let content, _):
                switch content {
                case .text(let text):
                    parts.append("[User] \(text)")
                case .parts(let contentParts):
                    let text = contentParts.compactMap { part -> String? in
                        if case .text(let t) = part { return t }
                        return nil
                    }.joined(separator: " ")
                    if !text.isEmpty {
                        parts.append("[User] \(text)")
                    }
                }
            case .assistant(let content, _, _, _):
                if let content {
                    parts.append("[Assistant] \(flattenStringContent(content))")
                }
            case .tool(let content, _):
                parts.append("[Tool Result] \(flattenContent(content))")
            }
        }

        return parts.joined(separator: "\n\n")
    }

    private nonisolated static func flattenContent(_ content: ChatRequestBody.Message.MessageContent<String, [String]>) -> String {
        switch content {
        case .text(let text): text
        case .parts(let parts): parts.joined(separator: "\n")
        }
    }

    private nonisolated static func flattenStringContent(_ content: ChatRequestBody.Message.MessageContent<String, [String]>) -> String {
        switch content {
        case .text(let text): text
        case .parts(let parts): parts.joined(separator: "\n")
        }
    }
}

#else

// Stub for platforms where FoundationModels is not available (e.g. Simulator on older Xcode)
final class OpenRockyAppleFoundationModelsChatClient: ChatClient, @unchecked Sendable {
    nonisolated let errorCollector: ErrorCollector

    nonisolated init() {
        errorCollector = .new()
    }

    nonisolated static var isAvailable: Bool { false }
    nonisolated static func checkModelReady() -> Bool { false }

    nonisolated func chat(body: ChatRequestBody) async throws -> ChatResponse {
        throw OpenRockyAppleFoundationModelsError.notSupported
    }

    nonisolated func streamingChat(body: ChatRequestBody) async throws -> AnyAsyncSequence<ChatResponseChunk> {
        throw OpenRockyAppleFoundationModelsError.notSupported
    }
}

#endif

enum OpenRockyAppleFoundationModelsError: LocalizedError {
    case notSupported

    var errorDescription: String? {
        switch self {
        case .notSupported:
            "Apple Foundation Models is not available on this device."
        }
    }
}
