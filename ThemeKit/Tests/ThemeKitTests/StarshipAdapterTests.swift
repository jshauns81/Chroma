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

    private func nord() throws -> Theme {
        let store = try ThemeStore.bundled()
        return try #require(store.theme(id: "nord"))
    }

    /// A non-Catppuccin theme has no palette table in the user's config, so the
    /// adapter must generate one (Catppuccin-keyed, from roles) *and* switch to
    /// it — otherwise `palette = "nord"` would point at a table that doesn't
    /// exist and Starship would render unstyled.
    @Test func generatesMissingPaletteTableThenSelectsIt() throws {
        let config = """
        palette = "catppuccin_macchiato"

        [palettes.catppuccin_macchiato]
        rosewater = "#f4dbd6"
        """
        let result = try adapter.render(theme: nord(), current: config)
        #expect(result.contains("palette = \"nord\""))
        #expect(result.contains("[palettes.nord]"))
        // mauve is keyed to the purple role; Nord's purple is #b48ead.
        #expect(result.contains("mauve = \"#b48ead\""))
        // The user's existing table is left intact.
        #expect(result.contains("[palettes.catppuccin_macchiato]"))
    }

    /// Re-applying the same theme must not append the table twice.
    @Test func paletteTableGenerationIsIdempotent() throws {
        let config = """
        palette = "catppuccin_macchiato"

        [palettes.catppuccin_macchiato]
        rosewater = "#f4dbd6"
        """
        let once = try adapter.render(theme: nord(), current: config)
        let twice = try adapter.render(theme: nord(), current: once)
        #expect(twice == once)
        let headers = twice.components(separatedBy: "[palettes.nord]").count - 1
        #expect(headers == 1)
    }
}
