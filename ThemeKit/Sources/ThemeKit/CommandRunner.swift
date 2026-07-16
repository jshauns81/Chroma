import Foundation

/// The result of running an external command.
public struct CommandResult: Sendable, Equatable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String

    public init(exitCode: Int32, stdout: String, stderr: String) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }
}

/// Runs external commands (chezmoi, tool reloads).
///
/// This is a *protocol* — a contract — rather than a concrete type, so the
/// `ApplyEngine` depends on the idea of "something that can run a command,"
/// not on `Process` specifically. Production injects the real
/// `ProcessCommandRunner`; tests inject a fake that just records what would run.
/// That's dependency injection: it keeps the engine's logic testable without
/// ever shelling out to real tools on someone's machine.
public protocol CommandRunner: Sendable {
    /// Run `executable` (looked up on `PATH`) with `arguments`, awaiting exit.
    func run(_ executable: String, arguments: [String]) async throws -> CommandResult
}

/// The real runner: launches a child process via `/usr/bin/env` so the tool is
/// found on `PATH`. SIP-safe — it only runs the user's own CLIs (chezmoi,
/// sketchybar, …), no privilege escalation or injection.
public struct ProcessCommandRunner: CommandRunner {
    public init() {}

    public func run(_ executable: String, arguments: [String]) async throws -> CommandResult {
        let process = Process()
        // `/usr/bin/env <exe>` resolves the tool on PATH, matching how the user
        // would invoke it in their shell.
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [executable] + arguments

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        try process.run()
        process.waitUntilExit()

        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        return CommandResult(
            exitCode: process.terminationStatus,
            stdout: String(decoding: outData, as: UTF8.self),
            stderr: String(decoding: errData, as: UTF8.self)
        )
    }
}
