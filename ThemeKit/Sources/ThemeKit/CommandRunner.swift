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
        // `/usr/bin/env <exe>` resolves the tool on PATH.
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [executable] + arguments

        // A GUI app launched by Finder/launchd inherits a *minimal* PATH
        // (/usr/bin:/bin:/usr/sbin:/sbin) that omits Homebrew — so `env
        // sketchybar` / `env chezmoi` die with "No such file or directory" while
        // the same command works in a terminal. Prepend the usual user tool
        // locations so hooks resolve the way they do in the user's shell.
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = Self.augmentedPATH(environment["PATH"])
        process.environment = environment

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

    /// `inherited` PATH with the common user/Homebrew bin dirs a GUI app is
    /// missing prepended (de-duped, order preserved). Static and pure so it's
    /// unit-testable without spawning a process.
    static func augmentedPATH(_ inherited: String?) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let extras = [
            "/opt/homebrew/bin", "/opt/homebrew/sbin",   // Apple Silicon Homebrew
            "/usr/local/bin", "/usr/local/sbin",         // Intel Homebrew / misc
            "\(home)/.local/bin",                        // pipx, chezmoi, user scripts
        ]
        let existing = (inherited ?? "/usr/bin:/bin:/usr/sbin:/sbin")
            .split(separator: ":").map(String.init)
        var seen = Set<String>()
        return (extras + existing).filter { seen.insert($0).inserted }.joined(separator: ":")
    }
}
