//
//  ConversationSession+Compact.swift
//  LanguageModelChatUI
//
//  Compacts long conversation histories by summarizing older messages.
//  Similar to Claude Code's /compact — preserves recent messages verbatim
//  and replaces older ones with an AI-generated summary.
//

import ChatClientKit
import Foundation
import OSLog

private let compactLogger = Logger(subsystem: "LanguageModelChatUI", category: "Compact")

extension ConversationSession {
    /// Number of non-system messages before compaction is triggered.
    static let compactThreshold = 40

    /// Number of recent non-system messages to keep verbatim after compaction.
    private static let recentToKeep = 20

    /// Metadata key used to mark a message as a compacted summary.
    static let compactedSummaryKey = "compactedSummary"

    /// Compact conversation history if it exceeds the threshold.
    ///
    /// Older messages are summarized into a single system message using the
    /// chat model. The originals are deleted from storage so subsequent
    /// requests use the compact summary instead.
    func compactHistoryIfNeeded() async {
        guard let chatModel = models.chat else { return }

        let nonSystemMessages = messages.filter { $0.role != .system }
        guard nonSystemMessages.count > Self.compactThreshold else { return }

        // Messages to compact (everything except the most recent `recentToKeep`)
        let toCompact = Array(nonSystemMessages.dropLast(Self.recentToKeep))
        guard toCompact.count >= 10 else { return }

        compactLogger.info("compacting \(toCompact.count) messages, keeping \(Self.recentToKeep) recent")

        // Build a text representation of older messages for the summarizer.
        // Truncate individual messages to avoid exceeding the model's context.
        let conversationText = toCompact.map { msg in
            let role = msg.role.rawValue
            let text = String(msg.textContent.prefix(500))
            return "<message role=\"\(role)\">\(text)</message>"
        }.joined(separator: "\n")

        let prompt = """
        Summarize the following conversation history. \
        Preserve all key facts, user preferences, decisions made, tool results, \
        and important context needed to continue the conversation naturally. \
        Be concise but thorough. Output only the summary text.

        <conversation>
        \(conversationText)
        </conversation>
        """

        do {
            let response = try await chatModel.client.chat(body: .init(
                messages: [
                    .system(content: .text("You are a conversation summarizer. Output a concise summary preserving all important context.")),
                    .user(content: .text(prompt)),
                ]
            ))

            let summary = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !summary.isEmpty else {
                compactLogger.warning("compaction produced empty summary, skipping")
                return
            }

            // Remove any existing compacted summary messages first
            let existingSummaryIds = messages
                .filter { $0.metadata[Self.compactedSummaryKey] == "true" }
                .map(\.id)
            if !existingSummaryIds.isEmpty {
                storageProvider.delete(existingSummaryIds)
            }

            // Delete original messages that were compacted
            let idsToDelete = toCompact.map(\.id)
            storageProvider.delete(idsToDelete)

            // Determine insertion timestamp: just before the earliest remaining message
            let remainingNonSystem = nonSystemMessages.suffix(Self.recentToKeep)
            let insertDate = remainingNonSystem.first?.createdAt.addingTimeInterval(-1) ?? Date()

            // Create summary message
            let summaryMessage = storageProvider.createMessage(in: id, role: .system)
            summaryMessage.textContent = "[Conversation Summary]\n\(summary)"
            summaryMessage.metadata[Self.compactedSummaryKey] = "true"
            summaryMessage.metadata["compactedMessageCount"] = "\(toCompact.count)"
            summaryMessage.createdAt = insertDate

            storageProvider.save([summaryMessage])

            // Reload from database to get correct ordering
            refreshContentsFromDatabase(scrolling: false)

            compactLogger.info("compacted \(toCompact.count) messages into summary (\(summary.count) chars)")
        } catch {
            compactLogger.error("compaction failed: \(error.localizedDescription)")
        }
    }
}
