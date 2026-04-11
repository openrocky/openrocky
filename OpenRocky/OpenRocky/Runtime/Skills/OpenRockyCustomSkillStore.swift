//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation
import Combine

@MainActor
final class OpenRockyCustomSkillStore: ObservableObject {
    static let shared = OpenRockyCustomSkillStore()

    @Published var skills: [OpenRockyCustomSkill] = []

    private let fileManager = FileManager.default

    private var baseDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("OpenRockySkills", isDirectory: true)
    }

    private static let builtInSkillsVersionKey = "OpenRockyBuiltInSkillsVersion"

    init() {
        ensureDirectoryExists()
        loadSkills()
        seedBuiltInSkillsIfNeeded()
    }

    // MARK: - Active skills prompt

    var enabledSkillsPrompt: String {
        let enabled = skills.filter(\.isEnabled)
        guard !enabled.isEmpty else { return "" }
        return enabled.map { skill in
            """
            ## Skill: \(skill.name)
            \(skill.description.isEmpty ? "" : "Description: \(skill.description)\n")\
            \(skill.triggerConditions.isEmpty ? "" : "Trigger: \(skill.triggerConditions)\n")
            \(skill.promptContent)
            """
        }.joined(separator: "\n\n")
    }

    // MARK: - CRUD

    func add(_ skill: OpenRockyCustomSkill) {
        rlog.info("Skill added: \(skill.name)", category: "Skills")
        skills.append(skill)
        saveSkill(skill)
    }

    func update(_ skill: OpenRockyCustomSkill) {
        guard let idx = skills.firstIndex(where: { $0.id == skill.id }) else { return }
        skills[idx] = skill
        saveSkill(skill)
    }

    func delete(id: String) {
        let name = skills.first { $0.id == id }?.name ?? id
        rlog.info("Skill deleted: \(name)", category: "Skills")
        skills.removeAll { $0.id == id }
        try? fileManager.removeItem(at: skillURL(for: id))
    }

    func toggle(_ skillID: String) {
        guard let idx = skills.firstIndex(where: { $0.id == skillID }) else { return }
        skills[idx].isEnabled.toggle()
        saveSkill(skills[idx])
    }

    // MARK: - Import / Export

    func importSkill(from localURL: URL) throws -> OpenRockyCustomSkill {
        rlog.info("Importing skill from: \(localURL.lastPathComponent)", category: "Skills")
        let content = try String(contentsOf: localURL, encoding: .utf8)
        var skill = try OpenRockyCustomSkill.fromMarkdown(content)
        skill = OpenRockyCustomSkill(
            id: UUID().uuidString,
            name: skill.name,
            description: skill.description,
            triggerConditions: skill.triggerConditions,
            promptContent: skill.promptContent,
            isEnabled: skill.isEnabled,
            sourceURL: localURL.absoluteString
        )
        add(skill)
        return skill
    }

    func importSkill(fromRemoteURL url: URL) async throws -> OpenRockyCustomSkill {
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let content = String(data: data, encoding: .utf8) else {
            throw ImportError.invalidEncoding
        }
        var skill = try OpenRockyCustomSkill.fromMarkdown(content)
        skill = OpenRockyCustomSkill(
            id: UUID().uuidString,
            name: skill.name,
            description: skill.description,
            triggerConditions: skill.triggerConditions,
            promptContent: skill.promptContent,
            isEnabled: skill.isEnabled,
            sourceURL: url.absoluteString
        )
        add(skill)
        return skill
    }

    /// Import all skills from a GitHub repo.
    /// Expects each skill in a subdirectory with a SKILL.md file.
    func importFromGitHubRepo(urlString: String) async throws -> [OpenRockyCustomSkill] {
        rlog.info("Importing skills from GitHub: \(urlString)", category: "Skills")
        let (owner, repo) = try Self.parseGitHubURL(urlString)
        let apiURL = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/contents")!

        var request = URLRequest(url: apiURL)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ImportError.githubAPIError
        }

        guard let items = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw ImportError.githubAPIError
        }

        let dirs = items.filter { ($0["type"] as? String) == "dir" && ($0["name"] as? String) != ".github" }
        var imported: [OpenRockyCustomSkill] = []

        for dir in dirs {
            guard let dirName = dir["name"] as? String else { continue }
            let skillURL = URL(string: "https://raw.githubusercontent.com/\(owner)/\(repo)/main/\(dirName)/SKILL.md")!

            do {
                let (skillData, _) = try await URLSession.shared.data(from: skillURL)
                guard let content = String(data: skillData, encoding: .utf8) else { continue }

                // Check if skill already exists by name
                var skill = try OpenRockyCustomSkill.fromMarkdown(content)
                if skills.contains(where: { $0.name == skill.name }) { continue }

                skill = OpenRockyCustomSkill(
                    id: UUID().uuidString,
                    name: skill.name,
                    description: skill.description,
                    triggerConditions: skill.triggerConditions,
                    promptContent: skill.promptContent,
                    isEnabled: skill.isEnabled,
                    sourceURL: "https://github.com/\(owner)/\(repo)/tree/main/\(dirName)"
                )
                add(skill)
                imported.append(skill)
            } catch {
                rlog.warning("Skill import skipped \(dirName): \(error.localizedDescription)", category: "Skills")
                continue
            }
        }

        return imported
    }

    private static func parseGitHubURL(_ urlString: String) throws -> (owner: String, repo: String) {
        // Handle: https://github.com/owner/repo or github.com/owner/repo
        let cleaned = urlString
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "github.com/", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        let parts = cleaned.split(separator: "/")
        guard parts.count >= 2 else {
            throw ImportError.invalidGitHubURL
        }
        return (String(parts[0]), String(parts[1]))
    }

    func exportSkill(_ skill: OpenRockyCustomSkill) -> URL {
        let tempDir = fileManager.temporaryDirectory
        let filename = skill.name.replacingOccurrences(of: " ", with: "-").lowercased()
        let exportURL = tempDir.appendingPathComponent("\(filename).md")
        try? skill.toMarkdown.write(to: exportURL, atomically: true, encoding: .utf8)
        return exportURL
    }

    // MARK: - Built-in Skills Seeding

    private func seedBuiltInSkillsIfNeeded() {
        let current = UserDefaults.standard.integer(forKey: Self.builtInSkillsVersionKey)
        guard current < OpenRockyBuiltInSkills.version else { return }

        for def in OpenRockyBuiltInSkills.all {
            // Skip if a skill with the same name already exists (user may have edited it)
            if skills.contains(where: { $0.name == def.name }) { continue }
            let skill = OpenRockyCustomSkill(
                id: UUID().uuidString,
                name: def.name,
                description: def.description,
                triggerConditions: def.trigger,
                promptContent: def.prompt,
                isEnabled: true,
                sourceURL: nil
            )
            add(skill)
        }

        UserDefaults.standard.set(OpenRockyBuiltInSkills.version, forKey: Self.builtInSkillsVersionKey)
    }

    // MARK: - Persistence

    private func ensureDirectoryExists() {
        try? fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
    }

    private func skillURL(for id: String) -> URL {
        baseDirectory.appendingPathComponent("\(id).md")
    }

    private func saveSkill(_ skill: OpenRockyCustomSkill) {
        let markdown = skill.toMarkdown
        try? markdown.write(to: skillURL(for: skill.id), atomically: true, encoding: .utf8)
    }

    private func loadSkills() {
        guard let files = try? fileManager.contentsOfDirectory(at: baseDirectory, includingPropertiesForKeys: nil) else { return }
        for file in files where file.pathExtension == "md" {
            let id = file.deletingPathExtension().lastPathComponent
            if let content = try? String(contentsOf: file, encoding: .utf8),
               let skill = try? OpenRockyCustomSkill.fromMarkdown(content, id: id) {
                skills.append(skill)
            }
        }
        rlog.info("Skills loaded: \(skills.count) total, \(skills.filter(\.isEnabled).count) enabled", category: "Skills")
    }

    /// Convert a skill name into a safe tool name suffix (lowercase, hyphens, no spaces).
    nonisolated static func sanitizeToolName(_ name: String) -> String {
        name.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
    }

    /// Find a skill by its sanitized tool name (e.g. "skill-weather-expert" → match skill named "Weather Expert").
    func skill(forToolName toolName: String) -> OpenRockyCustomSkill? {
        guard toolName.hasPrefix("skill-") else { return nil }
        let suffix = String(toolName.dropFirst(6))
        return skills.first { Self.sanitizeToolName($0.name) == suffix && $0.isEnabled }
    }

    enum ImportError: Error, LocalizedError {
        case invalidEncoding
        case githubAPIError
        case invalidGitHubURL

        var errorDescription: String? {
            switch self {
            case .invalidEncoding: return "Could not decode file content as UTF-8"
            case .githubAPIError: return "Failed to fetch repository contents from GitHub"
            case .invalidGitHubURL: return "Invalid GitHub URL. Expected: https://github.com/owner/repo"
            }
        }
    }
}
