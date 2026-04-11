//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Combine
import Foundation
#if !targetEnvironment(simulator)
import ios_system
import files
import shell
import network_ios
import OpenRockyPython
#endif

struct OpenRockyShellCommandResult: Identifiable, Equatable, Sendable {
    let id = UUID()
    let command: String
    let outputFile: String
    let exitCode: Int32
    let output: String
}

struct OpenRockyShellProbeResult: Equatable, Sendable {
    let workspacePath: String
    let changedDirectory: Bool
    let miniRootStatus: Int32
    let commands: [OpenRockyShellCommandResult]

    var primaryOutput: String {
        commands.first(where: { $0.outputFile == "rocky-pwd.txt" })?.output ?? "Unavailable"
    }

    var listingPreview: String {
        commands.first(where: { $0.outputFile == "rocky-ls.txt" })?.output ?? "Unavailable"
    }
}

@MainActor
final class OpenRockyShellRuntime: ObservableObject {
    static let shared = OpenRockyShellRuntime()

    @Published private(set) var probe: OpenRockyShellProbeResult?
    @Published private(set) var errorText: String?
    @Published private(set) var pythonAvailable = false

    private var didBootstrap = false
    private(set) var workspacePath: String?

    func bootstrapIfNeeded() {
        guard !didBootstrap else { return }
        didBootstrap = true

        #if targetEnvironment(simulator)
        // On Simulator, ios_system is not available — set up workspace path only.
        let fileManager = FileManager.default
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let workspace = documents.appendingPathComponent("OpenRockyWorkspace", isDirectory: true)
        try? fileManager.createDirectory(at: workspace, withIntermediateDirectories: true)
        workspacePath = workspace.path
        rlog.info("Shell bootstrap skipped (Simulator). Workspace: \(workspace.path)", category: "Shell")
        #else
        do {
            let result = try Self.bootstrap()
            probe = result
            workspacePath = result.workspacePath
        } catch {
            rlog.error("Shell bootstrap failed: \(error.localizedDescription)", category: "Shell")
            errorText = error.localizedDescription
        }

        // Initialize Python interpreter
        pythonAvailable = OpenRockyPythonRuntime.shared.initialize()
        if pythonAvailable, let ver = OpenRockyPythonRuntime.shared.version() {
            rlog.info("Shell bootstrapped. Python: \(ver)", category: "Shell")
        } else {
            rlog.info("Shell bootstrapped. Python: not available", category: "Shell")
        }
        #endif
    }

    func execute(command: String) -> OpenRockyShellCommandResult {
        rlog.info("Shell exec: \(command.prefix(120))", category: "Shell")
        #if targetEnvironment(simulator)
        return OpenRockyShellCommandResult(
            command: command,
            outputFile: "",
            exitCode: -1,
            output: "(ios_system not available on Simulator)"
        )
        #else
        let outputFile = "rocky-cmd-\(UUID().uuidString.prefix(8)).txt"
        let redirected = "\(command) > \(outputFile) 2>&1"
        let exitCode = redirected.withCString { ios_system($0) }

        var output = "(no output)"
        if let ws = workspacePath {
            let url = URL(fileURLWithPath: ws).appendingPathComponent(outputFile)
            if let text = try? String(contentsOf: url, encoding: .utf8) {
                output = text.trimmingCharacters(in: .whitespacesAndNewlines)
                try? FileManager.default.removeItem(at: url)
            }
        }

        if exitCode != 0 {
            rlog.warning("Shell exit code \(exitCode): \(command.prefix(80))", category: "Shell")
        }

        return OpenRockyShellCommandResult(
            command: command,
            outputFile: outputFile,
            exitCode: exitCode,
            output: output.isEmpty ? "(no output)" : output
        )
        #endif
    }

    #if !targetEnvironment(simulator)
    private static func bootstrap() throws -> OpenRockyShellProbeResult {
        let fileManager = FileManager.default
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let workspace = documents.appendingPathComponent("OpenRockyWorkspace", isDirectory: true)
        try fileManager.createDirectory(at: workspace, withIntermediateDirectories: true)

        initializeEnvironment()
        let changedDirectory = fileManager.changeCurrentDirectoryPath(workspace.path)
        let miniRootStatus = ios_setMiniRoot(workspace.path)

        // Use FileManager instead of shell commands to avoid "ls not found" issues
        let pwdOutput = workspace.path
        let lsOutput: String = {
            let entries = (try? fileManager.contentsOfDirectory(atPath: workspace.path)) ?? []
            return entries.isEmpty ? "(empty)" : entries.joined(separator: "\n")
        }()

        let commands = [
            OpenRockyShellCommandResult(command: "pwd", outputFile: "rocky-pwd.txt", exitCode: 0, output: pwdOutput),
            OpenRockyShellCommandResult(command: "ls", outputFile: "rocky-ls.txt", exitCode: 0, output: lsOutput),
        ]

        return OpenRockyShellProbeResult(
            workspacePath: workspace.path,
            changedDirectory: changedDirectory,
            miniRootStatus: miniRootStatus,
            commands: commands
        )
    }
    #endif
}
