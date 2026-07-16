import Testing
import Foundation
@testable import ThemeKit

@Suite("ThemeValidator")
struct ThemeValidatorTests {
    /// A fresh, unique temp directory for one test's fixture files.
    private func tempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChromaTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test func bundledThemesAllValid() throws {
        let reports = try ThemeValidator.validateBundled()
        let allValid = reports.allSatisfy(\.isValid)
        #expect(!reports.isEmpty)
        #expect(allValid)
    }

    @Test func reportsValidForWellFormedFile() throws {
        let dir = try tempDir()
        let theme = try #require(try ThemeStore.bundled().theme(id: "catppuccin-mocha"))
        try ThemeStore.encode(theme)
            .write(to: dir.appendingPathComponent("catppuccin-mocha.json"))

        let report = try #require(try ThemeValidator.validate(directory: dir).first)
        #expect(report.outcome == .valid(themeID: "catppuccin-mocha"))
    }

    @Test func reportsMalformedForUndecodableJSON() throws {
        let dir = try tempDir()
        // Unknown role name — decodes as JSON but fails Palette's Codable.
        let badRole = """
        {
          "id": "x", "name": "X", "family": "x", "variant": "x",
          "appearance": "dark",
          "source": { "url": "https://example.com", "ref": "main",
                      "fetchedAt": "2026-07-12T00:00:00Z" },
          "palette": { "primaryAccent": "red",
                       "colors": { "chartreuse": "#112233" } },
          "toolNames": {}
        }
        """
        try badRole.write(to: dir.appendingPathComponent("bad.json"),
                          atomically: true, encoding: .utf8)

        let report = try #require(try ThemeValidator.validate(directory: dir).first)
        #expect(!report.isValid)
        guard case .malformed = report.outcome else {
            Issue.record("expected .malformed, got \(report.outcome)")
            return
        }
    }

    @Test func reportsMissingRolesWhenRequiredRoleAbsent() throws {
        let dir = try tempDir()
        // Structurally fine, but the palette omits `blue` (a required role).
        let missingBlue = """
        {
          "id": "partial", "name": "Partial", "family": "x", "variant": "x",
          "appearance": "dark",
          "source": { "url": "https://example.com", "ref": "main",
                      "fetchedAt": "2026-07-12T00:00:00Z" },
          "palette": {
            "primaryAccent": "red",
            "colors": {
              "base": "#000000", "text": "#ffffff",
              "red": "#ff0000", "yellow": "#ffff00", "green": "#00ff00"
            }
          },
          "toolNames": {}
        }
        """
        try missingBlue.write(to: dir.appendingPathComponent("partial.json"),
                              atomically: true, encoding: .utf8)

        let report = try #require(try ThemeValidator.validate(directory: dir).first)
        #expect(report.outcome == .missingRoles([.blue]))
    }
}
