//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation

struct OpenRockyCustomSkill: Codable, Identifiable, Equatable, Sendable {
    let id: String
    var name: String
    var description: String
    var triggerConditions: String
    var promptContent: String
    var isEnabled: Bool
    var sourceURL: String?

    // MARK: - Markdown Serialization

    var toMarkdown: String {
        """
        ---
        name: \(name)
        description: \(description)
        trigger: \(triggerConditions)
        enabled: \(isEnabled)
        ---

        \(promptContent)
        """
    }

    static func fromMarkdown(_ content: String, id: String? = nil) throws -> OpenRockyCustomSkill {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("---") else {
            throw SkillParseError.missingFrontmatter
        }

        let parts = trimmed.components(separatedBy: "---")
        guard parts.count >= 3 else {
            throw SkillParseError.invalidFormat
        }

        let frontmatter = parts[1]
        let body = parts.dropFirst(2).joined(separator: "---").trimmingCharacters(in: .whitespacesAndNewlines)

        var name = ""
        var description = ""
        var trigger = ""
        var enabled = true

        var isMultilineDesc = false
        for line in frontmatter.components(separatedBy: .newlines) {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.isEmpty { continue }

            // Handle YAML multiline continuation (indented lines after "description: >")
            if isMultilineDesc {
                if line.hasPrefix("  ") || line.hasPrefix("\t") {
                    description += (description.isEmpty ? "" : " ") + trimmedLine
                    continue
                } else {
                    isMultilineDesc = false
                }
            }

            if let value = trimmedLine.extractValue(for: "name:") {
                name = value
            } else if let value = trimmedLine.extractValue(for: "description:") {
                if value == ">" || value == "|" {
                    isMultilineDesc = true
                    description = ""
                } else {
                    description = value
                }
            } else if let value = trimmedLine.extractValue(for: "trigger:") {
                trigger = value
            } else if let value = trimmedLine.extractValue(for: "enabled:") {
                enabled = value.lowercased() == "true"
            }
            // Skip other fields (version, metadata, compatibility) gracefully
        }

        guard !name.isEmpty else {
            throw SkillParseError.missingName
        }

        return OpenRockyCustomSkill(
            id: id ?? UUID().uuidString,
            name: name,
            description: description,
            triggerConditions: trigger,
            promptContent: body,
            isEnabled: enabled,
            sourceURL: nil
        )
    }

    enum SkillParseError: Error, LocalizedError {
        case missingFrontmatter
        case invalidFormat
        case missingName

        var errorDescription: String? {
            switch self {
            case .missingFrontmatter: return "Missing YAML frontmatter (---)"
            case .invalidFormat: return "Invalid skill file format"
            case .missingName: return "Skill name is required"
            }
        }
    }
}

private extension String {
    func extractValue(for key: String) -> String? {
        let trimmed = trimmingCharacters(in: .whitespaces)
        guard trimmed.lowercased().hasPrefix(key.lowercased()) else { return nil }
        return String(trimmed.dropFirst(key.count)).trimmingCharacters(in: .whitespaces)
    }
}
