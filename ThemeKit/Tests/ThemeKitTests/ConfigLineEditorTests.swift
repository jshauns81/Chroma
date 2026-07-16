import Testing
@testable import ThemeKit

@Suite("ConfigLineEditor anchored replacement")
struct ConfigLineEditorTests {
    /// A predicate matching an active `key = …` line by its key.
    private func keyIs(_ key: String) -> (String) -> Bool {
        { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.hasPrefix("#"), let eq = trimmed.firstIndex(of: "=") else {
                return false
            }
            return trimmed[..<eq].trimmingCharacters(in: .whitespaces) == key
        }
    }

    @Test func replacesTheMatchingLineOnly() throws {
        let content = """
        font-size = 14
        theme = Old Theme
        cursor-style = block
        """
        let result = try ConfigLineEditor.replacingLine(
            in: content,
            with: "theme = New Theme",
            anchorLabel: "theme = …",
            where: keyIs("theme")
        )
        #expect(result == """
        font-size = 14
        theme = New Theme
        cursor-style = block
        """)
    }

    @Test func preservesTrailingNewline() throws {
        let content = "theme = Old\n"
        let result = try ConfigLineEditor.replacingLine(
            in: content, with: "theme = New", anchorLabel: "theme = …", where: keyIs("theme")
        )
        #expect(result == "theme = New\n")
    }

    @Test func throwsWhenAnchorMissing() {
        let content = "font-size = 14\ncursor-style = block"
        #expect(throws: ConfigLineEditor.EditError.anchorNotFound("theme = …")) {
            try ConfigLineEditor.replacingLine(
                in: content, with: "theme = New", anchorLabel: "theme = …", where: keyIs("theme")
            )
        }
    }

    @Test func throwsWhenAnchorAmbiguous() {
        let content = "theme = One\ntheme = Two"
        #expect(throws: ConfigLineEditor.EditError.ambiguousAnchor("theme = …", matches: 2)) {
            try ConfigLineEditor.replacingLine(
                in: content, with: "theme = New", anchorLabel: "theme = …", where: keyIs("theme")
            )
        }
    }
}
