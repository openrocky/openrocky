import Foundation
import OSLog
import UniformTypeIdentifiers

private let submissionLogger = Logger(subsystem: "LanguageModelChatUI", category: "Submission")

@MainActor func applyConversationModels(
    _ models: ConversationSession.Models,
    to session: ConversationSession
) {
    if let chat = models.chat {
        session.models.chat = chat
    }
    if let titleGeneration = models.titleGeneration {
        session.models.titleGeneration = titleGeneration
    }
}

func makeUserInput(from object: ChatInputContent, workspacePath: String? = nil) -> ConversationSession.UserInput {
    // Copy file attachments to workspace so agent tools can access them
    if let workspace = workspacePath {
        copyAttachmentsToWorkspace(object.attachments, workspacePath: workspace)
    }
    let attachmentSummary = object.attachments.map { attachment in
        "\(attachment.type.rawValue)(fileBytes=\(attachment.fileData.count),previewBytes=\(attachment.previewImageData.count),textChars=\(attachment.textContent.count))"
    }.joined(separator: ", ")
    submissionLogger.info(
        "makeUserInput textChars=\(object.text.count) attachments=\(object.attachments.count) [\(attachmentSummary)]"
    )

    return .init(
        text: object.text,
        attachments: object.attachments.map(makeContentPart)
    )
}

private func makeContentPart(from attachment: ChatInputAttachment) -> ContentPart {
    switch attachment.type {
    case .image:
        .image(.init(
            mediaType: mediaType(for: attachment, fallback: "image/jpeg"),
            data: attachment.fileData,
            previewData: attachment.previewImageData.isEmpty ? nil : attachment.previewImageData,
            name: attachment.name
        ))
    case .document:
        .file(.init(
            mediaType: mediaType(for: attachment, fallback: "text/plain"),
            data: Data(attachment.textContent.utf8),
            textContent: attachment.textContent,
            name: attachment.name
        ))
    case .audio:
        .audio(.init(
            mediaType: mediaType(for: attachment, fallback: "audio/m4a"),
            data: attachment.fileData,
            transcription: attachment.textContent.isEmpty ? nil : attachment.textContent,
            name: attachment.name
        ))
    }
}

private func mediaType(for attachment: ChatInputAttachment, fallback: String) -> String {
    let ext = URL(fileURLWithPath: attachment.storageFilename).pathExtension
    guard !ext.isEmpty else { return fallback }
    if let type = UTType(filenameExtension: ext), let mimeType = type.preferredMIMEType {
        return mimeType
    }
    return fallback
}

private func copyAttachmentsToWorkspace(_ attachments: [ChatInputAttachment], workspacePath: String) {
    let fm = FileManager.default
    let workspaceURL = URL(fileURLWithPath: workspacePath)

    for attachment in attachments {
        let name = attachment.name.isEmpty ? "attachment-\(attachment.id.uuidString)" : attachment.name
        let destURL = workspaceURL.appendingPathComponent(name)

        switch attachment.type {
        case .document:
            if !attachment.textContent.isEmpty {
                try? attachment.textContent.write(to: destURL, atomically: true, encoding: .utf8)
            } else if !attachment.fileData.isEmpty {
                try? attachment.fileData.write(to: destURL)
            }
        case .image:
            if !attachment.fileData.isEmpty {
                let imageURL = destURL.deletingPathExtension().appendingPathExtension("jpg")
                try? attachment.fileData.write(to: imageURL)
            }
        case .audio:
            if !attachment.fileData.isEmpty {
                let audioURL = destURL.deletingPathExtension().appendingPathExtension("m4a")
                try? attachment.fileData.write(to: audioURL)
            }
        }
    }
}
