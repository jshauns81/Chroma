import Testing
@testable import ThemeKit

@Suite("StarshipAdapter")
struct StarshipAdapterTests {
    private let adapter = StarshipAdapter()

    private func macchiato() throws -> Theme {
        let store = try ThemeStore.bundled()
        return try #require(store.theme(id: "catppuccin-macchiato"))
    }

    @Test func rewritesTheActivePaletteLine() throws {
        let config = """
        add_newline = false
        palette = "catppuccin_mocha"

        [palettes.catppuccin_macchiato]
        rosewater = "#f4dbd6"
        """
        let result = try adapter.render(theme: macchiato(), current: config)
        #expect(result == """
        add_newline = false
        palette = "catppuccin_macchiato"

        [palettes.catppuccin_macchiato]
        rosewater = "#f4dbd6"
        """)
    }

    @Test func throwsWhenNoPaletteLine() throws {
        #expect(throws: ConfigLineEditor.EditError.anchorNotFound("palette = \"…\"")) {
            try adapter.render(theme: try macchiato(), current: "add_newline = false\n")
        }
    }
}
