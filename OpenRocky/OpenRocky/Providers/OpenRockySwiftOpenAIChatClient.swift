//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation
import ChatClientKit
@preconcurrency import SwiftOpenAI

final class OpenRockySwiftOpenAIChatClient: ChatClient, @unchecked Sendable {
    nonisolated let errorCollector: ErrorCollector
    nonisolated private let configuration: OpenRockyProviderConfiguration

    nonisolated init(configuration: OpenRockyProviderConfiguration) {
        self.configuration = configuration.normalized()
        errorCollector = .new()
    }

    nonisolated func chat(body: ChatRequestBody) async throws -> ChatResponse {
        var chunks: [ChatResponseChunk] = []
        for try await chunk in try await streamingChat(body: body) {
            chunks.append(chunk)
        }
        return ChatResponse(chunks: chunks)
    }

    nonisolated func streamingChat(body: ChatRequestBody) async throws -> AnyAsyncSequence<ChatResponseChunk> {
        let service = try makeService()
        let parameters = try makeParameters(from: body.mergingAdjacentAssistantMessages())
        let upstream = try await service.startStreamedChat(parameters: parameters)
        let config = configuration
        nonisolated(unsafe) var iterator = OpenRockyMappedChunkIterator(
            baseIterator: upstream.makeAsyncIterator(),
            onUsage: { prompt, completion, total in
                Task { @MainActor in
                    OpenRockyUsageService.shared.recordChat(
                        provider: config.provider.displayName,
                        model: config.modelID,
                        promptTokens: prompt,
                        completionTokens: completion,
                        totalTokens: total
                    )
                }
            }
        )
        let stream = AsyncThrowingStream<ChatResponseChunk, Error>(unfolding: {
            try await iterator.next()
        })
        return AnyAsyncSequence(stream)
    }

    private nonisolated func makeService() throws -> any OpenAIService {
        try OpenRockyOpenAIServiceFactory.makeService(configuration: configuration)
    }

    private nonisolated func makeParameters(from body: ChatRequestBody) throws -> ChatCompletionParameters {
        let messages = body.messages.compactMap(map(message:))
        guard messages.isEmpty == false else {
            throw OpenRockySwiftOpenAIClientError.emptyConversation
        }

        let tools = body.tools?.compactMap(mapTool(_:))

        return ChatCompletionParameters(
            messages: messages,
            model: .custom(body.model ?? configuration.modelID),
            reasoningEffort: .medium,
            tools: tools?.isEmpty == false ? tools : nil,
            temperature: body.temperature,
            streamOptions: .init(includeUsage: true)
        )
    }

    private nonisolated func map(message: ChatRequestBody.Message) -> ChatCompletionParameters.Message? {
        switch message {
        case let .assistant(content, toolCalls, reasoning, _):
            let assistantText = [flattenAssistantContent(content), reasoning]
                .compactMap { $0?.nilIfEmpty }
                .joined(separator: "\n\n")
            // Convert ChatRequestBody.Message.ToolCall → SwiftOpenAI.ToolCall via JSON round-trip
            // (fields are module-internal, so direct property access is unavailable)
            let mappedToolCalls: [ToolCall]? = toolCalls?.compactMap { tc in
                guard let data = try? JSONEncoder().encode(tc),
                      let decoded = try? JSONDecoder().decode(ToolCall.self, from: data) else { return nil }
                return decoded
            }
            return .init(
                role: .assistant,
                content: .text(assistantText.ifEmpty(" ")),
                toolCalls: mappedToolCalls?.isEmpty == false ? mappedToolCalls : nil
            )
        case let .developer(content, _):
            return .init(role: .system, content: .text(flattenDeveloperContent(content)))
        case let .system(content, _):
            return .init(role: .system, content: .text(flattenDeveloperContent(content)))
        case let .tool(content, toolCallID):
            return .init(role: .tool, content: .text(flattenDeveloperContent(content)), toolCallID: toolCallID)
        case let .user(content, _):
            switch content {
            case .text(let text):
                return .init(role: .user, content: .text(text))
            case .parts(let parts):
                let mappedParts = parts.compactMap(map(contentPart:))
                if mappedParts.isEmpty {
                    return .init(role: .user, content: .text(" "))
                }
                return .init(role: .user, content: .contentArray(mappedParts))
            }
        }
    }

    private nonisolated func flattenAssistantContent(_ content: ChatRequestBody.Message.MessageContent<String, [String]>?) -> String? {
        switch content {
        case .text(let text):
            text
        case .parts(let parts):
            parts.joined(separator: "\n")
        case nil:
            nil
        }
    }

    private nonisolated func flattenDeveloperContent(_ content: ChatRequestBody.Message.MessageContent<String, [String]>) -> String {
        switch content {
        case .text(let text):
            text
        case .parts(let parts):
            parts.joined(separator: "\n")
        }
    }

    private nonisolated func map(contentPart: ChatRequestBody.Message.ContentPart) -> ChatCompletionParameters.Message.ContentType.MessageContent? {
        switch contentPart {
        case .text(let text):
            .text(text)
        case let .imageURL(url, detail):
            .imageUrl(.init(url: url, detail: detail?.rawValue))
        case let .audioBase64(data, format):
            .inputAudio(.init(data: data, format: format))
        }
    }

    private nonisolated func mapTool(_ tool: ChatRequestBody.Tool) -> ChatCompletionParameters.Tool? {
        switch tool {
        case let .function(name, description, parameters, strict):
            let schema: JSONSchema?
            if let parameters {
                if let data = try? JSONEncoder().encode(parameters),
                   let decoded = try? JSONDecoder().decode(JSONSchema.self, from: data) {
                    schema = decoded
                } else {
                    schema = nil
                }
            } else {
                schema = nil
            }
            return .init(function: .init(
                name: name,
                strict: strict,
                description: description,
                parameters: schema
            ))
        }
    }

    fileprivate nonisolated static func map(
        chunk: ChatCompletionChunkObject,
        toolAccumulator: inout [Int: (id: String, name: String, arguments: String)]
    ) -> [ChatResponseChunk] {
        guard let choice = chunk.choices?.first else { return [] }

        var result: [ChatResponseChunk] = []

        if let delta = choice.delta {
            if let reasoning = delta.reasoningContent, !reasoning.isEmpty {
                result.append(.reasoning(reasoning))
            }
            if let text = delta.content, !text.isEmpty {
                result.append(.text(text))
            }
            if let toolCalls = delta.toolCalls {
                for tc in toolCalls {
                    let idx = tc.index ?? 0
                    var entry = toolAccumulator[idx] ?? (id: "", name: "", arguments: "")
                    if let id = tc.id, !id.isEmpty { entry.id = id }
                    if let name = tc.function.name, !name.isEmpty { entry.name = name }
                    entry.arguments += tc.function.arguments
                    toolAccumulator[idx] = entry
                }
            }
        }

        if case .string("tool_calls") = choice.finishReason {
            for (_, call) in toolAccumulator.sorted(by: { $0.key < $1.key }) {
                if let req = decodeToolRequest(id: call.id, name: call.name, arguments: call.arguments) {
                    result.append(.tool(req))
                }
            }
            toolAccumulator.removeAll()
        }

        return result
    }

    /// Create a ToolRequest via Codable since its init is module-internal.
    fileprivate nonisolated static func decodeToolRequest(id: String, name: String, arguments: String) -> ToolRequest? {
        struct Proxy: Encodable { let id: String; let name: String; let arguments: String }
        guard let data = try? JSONEncoder().encode(Proxy(id: id, name: name, arguments: arguments)) else { return nil }
        return try? JSONDecoder().decode(ToolRequest.self, from: data)
    }
}

private enum OpenRockySwiftOpenAIClientError: LocalizedError {
    case emptyConversation

    var errorDescription: String? {
        switch self {
        case .emptyConversation:
            "The conversation is empty."
        }
    }
}

private struct OpenRockyMappedChunkIterator {
    nonisolated(unsafe) var baseIterator: AsyncThrowingStream<ChatCompletionChunkObject, Error>.Iterator
    nonisolated(unsafe) var pending: [ChatResponseChunk] = []
    nonisolated(unsafe) var toolAccumulator: [Int: (id: String, name: String, arguments: String)] = [:]
    nonisolated(unsafe) var lastUsage: ChatUsage?
    nonisolated(unsafe) var onUsage: ((Int, Int, Int) -> Void)?

    nonisolated mutating func next() async throws -> ChatResponseChunk? {
        if !pending.isEmpty {
            return pending.removeFirst()
        }

        while let chunk = try await baseIterator.next() {
            if let usage = chunk.usage {
                lastUsage = usage
            }
            pending = OpenRockySwiftOpenAIChatClient.map(chunk: chunk, toolAccumulator: &toolAccumulator)
            if !pending.isEmpty {
                return pending.removeFirst()
            }
        }

        // Stream ended — flush any remaining accumulated tool calls
        for (_, call) in toolAccumulator.sorted(by: { $0.key < $1.key }) {
            if let req = OpenRockySwiftOpenAIChatClient.decodeToolRequest(id: call.id, name: call.name, arguments: call.arguments) {
                pending.append(.tool(req))
            }
        }
        toolAccumulator.removeAll()

        // Report usage to the usage service
        if let usage = lastUsage {
            let prompt = usage.promptTokens ?? 0
            let completion = usage.completionTokens ?? 0
            let total = usage.totalTokens ?? (prompt + completion)
            if total > 0 {
                onUsage?(prompt, completion, total)
            }
            lastUsage = nil
        }

        return pending.isEmpty ? nil : pending.removeFirst()
    }
}

private extension String {
    nonisolated func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }

    nonisolated var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
