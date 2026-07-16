import Testing
@testable import ThemeKit

@Suite("ZellijAdapter")
struct ZellijAdapterTests {
    private let adapter = ZellijAdapter()

    private func macchiato() throws -> Theme {
        let store = try ThemeStore.bundled()
        return try #require(store.theme(id: "catppuccin-macchiato"))
    }

    @Test func rewritesTheThemeLineWithQuotedName() throws {
        let config = """
        default_shell "zsh"
        theme "some-old-theme"
        pane_frames true
        """
        let result = try adapter.render(theme: macchiato(), current: config)
        #expect(result == """
        default_shell "zsh"
        theme "catppuccin-macchiato"
        pane_frames true
        """)
    }

    @Test func ignoresCommentedThemeLines() throws {
        let config = """
        // theme "example-in-a-comment"
        theme "active"
        """
        let result = try adapter.render(theme: macchiato(), current: config)
        #expect(result == """
        // theme "example-in-a-comment"
        theme "catppuccin-macchiato"
        """)
    }

    @Test func throwsWhenConfigHasNoThemeLine() throws {
        #expect(throws: ConfigLineEditor.EditError.anchorNotFound("theme \"…\"")) {
            try adapter.render(theme: try macchiato(), current: "pane_frames true\n")
        }
    }
}
