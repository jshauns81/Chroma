import Testing
import Foundation
@testable import ThemeKit

/// A fake `CommandRunner` that records what it was asked to run, and executes
/// nothing. An `actor` because the recorded list is mutated across `await`s.
actor RecordingRunner: CommandRunner {
    private(set) var commands: [[String]] = []

    func run(_ executable: String, arguments: [String]) async throws -> CommandResult {
        commands.append([executable] + arguments)
        return CommandResult(exitCode: 0, stdout: "", stderr: "")
    }
}

@Suite("ApplyEngine hooks")
struct ApplyEngineHooksTests {
    private func macchiato() throws -> Theme {
        let store = try ThemeStore.bundled()
        return try #require(store.theme(id: "catppuccin-macchiato"))
    }

    private func tempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChromaTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test func runsReAddPerFileAndReloadForChangedTool() async throws {
        let url = try tempDir().appendingPathComponent("config")
        try "theme = Old\n".write(to: url, atomically: true, encoding: .utf8)

        let runner = RecordingRunner()
        let engine = ApplyEngine(
            tools: [ManagedTool(adapter: GhosttyAdapter(), url: url, reloadCommand: ["ghostty", "reload"])],
            runner: runner,
            dotfileReAddCommand: ["chezmoi", "re-add", "{}"]
        )

        try await engine.apply(macchiato())

        let commands = await runner.commands
        #expect(commands.contains(["chezmoi", "re-add", url.path]))  // {} substituted
        #expect(commands.contains(["ghostty", "reload"]))
    }

    @Test func skipsAllHooksWhenNothingChanged() async throws {
        let url = try tempDir().appendingPathComponent("config")
        try "theme = Catppuccin Macchiato\n".write(to: url, atomically: true, encoding: .utf8)

        let runner = RecordingRunner()
        let engine = ApplyEngine(
            tools: [ManagedTool(adapter: GhosttyAdapter(), url: url, reloadCommand: ["ghostty", "reload"])],
            runner: runner,
            dotfileReAddCommand: ["chezmoi", "re-add", "{}"]
        )

        try await engine.apply(macchiato())

        let commands = await runner.commands
        #expect(commands.isEmpty)  // no-op apply touches nothing and runs no hooks
    }
}
