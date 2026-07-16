import Testing
@testable import ThemeKit

@Suite("GhosttyAdapter")
struct GhosttyAdapterTests {
    private let adapter = GhosttyAdapter()

    /// A real bundled theme, so the test exercises the same data the app ships.
    private func macchiato() throws -> Theme {
        let store = try ThemeStore.bundled()
        return try #require(store.theme(id: "catppuccin-macchiato"))
    }

    @Test func rewritesTheThemeLineUsingToolName() throws {
        let config = """
        font-family = SF Mono
        theme = Some Old Theme
        background-opacity = 0.95
        """
        let result = try adapter.render(theme: macchiato(), current: config)
        #expect(result == """
        font-family = SF Mono
        theme = Catppuccin Macchiato
        background-opacity = 0.95
        """)
    }

    @Test func ignoresCommentedThemeLines() throws {
        // A commented `# theme = …` must not be treated as the anchor, and must
        // survive untouched.
        let config = """
        # theme = Commented Out
        theme = Active
        """
        let result = try adapter.render(theme: macchiato(), current: config)
        #expect(result == """
        # theme = Commented Out
        theme = Catppuccin Macchiato
        """)
    }

    @Test func throwsWhenConfigHasNoThemeLine() throws {
        // Faithful to "never guess": with no anchor to replace, the adapter
        // surfaces the helper's error rather than appending a line.
        let config = "font-family = SF Mono\n"
        #expect(throws: ConfigLineEditor.EditError.anchorNotFound("theme = …")) {
            try adapter.render(theme: try macchiato(), current: config)
        }
    }
}
