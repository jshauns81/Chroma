import Testing
import Foundation
@testable import ThemeKit

@Suite("ApplyEngine")
struct ApplyEngineTests {
    private func macchiato() throws -> Theme {
        let store = try ThemeStore.bundled()
        return try #require(store.theme(id: "catppuccin-macchiato"))
    }

    /// A fresh, unique temp directory for one test's fixture files — never a
    /// real dotfile.
    private func tempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChromaTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Planning (read-only)

    @Test func plansModifyForExistingConfig() async throws {
        let url = try tempDir().appendingPathComponent("config")
        try "theme = Old\n".write(to: url, atomically: true, encoding: .utf8)

        let engine = ApplyEngine(tools: [ManagedTool(adapter: GhosttyAdapter(), url: url)])
        let changes = try await engine.plan(for: macchiato())

        let change = try #require(changes.first)
        #expect(changes.count == 1)
        #expect(change.willCreate == false)
        #expect(change.isNoop == false)
        #expect(change.newContent == "theme = Catppuccin Macchiato\n")
    }

    @Test func plansCreateWhenFileMissing() async throws {
        let url = try tempDir().appendingPathComponent("theme.zsh")  // never written

        let engine = ApplyEngine(tools: [ManagedTool(adapter: BatAdapter(), url: url)])
        let change = try #require(try await engine.plan(for: macchiato()).first)

        #expect(change.willCreate)
        #expect(change.newContent.contains("BAT_THEME=\"Chroma\""))
    }

    @Test func detectsNoopWhenAlreadyThemed() async throws {
        let url = try tempDir().appendingPathComponent("config")
        try "theme = Catppuccin Macchiato\n".write(to: url, atomically: true, encoding: .utf8)

        let engine = ApplyEngine(tools: [ManagedTool(adapter: GhosttyAdapter(), url: url)])
        let change = try #require(try await engine.plan(for: macchiato()).first)

        #expect(change.isNoop)
    }

    // MARK: - Applying (writes)

    @Test func applyCreatesMissingFileAndParentDirectory() async throws {
        // Nested dir that doesn't exist yet — apply must create it.
        let url = try tempDir().appendingPathComponent("chroma/theme.zsh")
        let engine = ApplyEngine(tools: [ManagedTool(adapter: BatAdapter(), url: url)])

        try await engine.apply(macchiato())

        let written = try String(contentsOf: url, encoding: .utf8)
        #expect(written.contains("BAT_THEME=\"Chroma\""))
    }

    @Test func applyBacksUpThenOverwritesExistingFile() async throws {
        let url = try tempDir().appendingPathComponent("config")
        try "theme = Old\n".write(to: url, atomically: true, encoding: .utf8)
        let engine = ApplyEngine(tools: [ManagedTool(adapter: GhosttyAdapter(), url: url)])

        try await engine.apply(macchiato())

        let written = try String(contentsOf: url, encoding: .utf8)
        #expect(written == "theme = Catppuccin Macchiato\n")

        // The old contents are preserved in a .bak alongside it.
        let backup = url.appendingPathExtension("bak")
        #expect(try String(contentsOf: backup, encoding: .utf8) == "theme = Old\n")
    }

    @Test func applySkipsNoopWithoutMakingBackup() async throws {
        let url = try tempDir().appendingPathComponent("config")
        try "theme = Catppuccin Macchiato\n".write(to: url, atomically: true, encoding: .utf8)
        let engine = ApplyEngine(tools: [ManagedTool(adapter: GhosttyAdapter(), url: url)])

        try await engine.apply(macchiato())

        let backup = url.appendingPathExtension("bak")
        #expect(FileManager.default.fileExists(atPath: backup.path) == false)
    }

    @Test func applyRecordsLastAppliedTheme() async throws {
        let url = try tempDir().appendingPathComponent("config")
        try "theme = Old\n".write(to: url, atomically: true, encoding: .utf8)
        let engine = ApplyEngine(tools: [ManagedTool(adapter: GhosttyAdapter(), url: url)])

        try await engine.apply(macchiato())

        let last = await engine.lastAppliedThemeID
        #expect(last == "catppuccin-macchiato")
    }
}
