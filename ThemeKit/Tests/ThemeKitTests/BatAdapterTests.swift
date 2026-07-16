import Testing
@testable import ThemeKit

@Suite("BatAdapter")
struct BatAdapterTests {
    private let adapter = BatAdapter()

    private func macchiato() throws -> Theme {
        let store = try ThemeStore.bundled()
        return try #require(store.theme(id: "catppuccin-macchiato"))
    }

    /// BAT_THEME is now the constant "Chroma" for every theme — bat renders the
    /// generated Chroma.tmTheme, not an upstream built-in.
    @Test func exportsConstantChromaThemeName() throws {
        let result = try adapter.render(theme: macchiato(), current: nil)
        #expect(result.contains("export BAT_THEME=\"Chroma\""))
        // Same regardless of theme.
        let store = try ThemeStore.bundled()
        let nord = try #require(store.theme(id: "nord"))
        #expect(try adapter.render(theme: nord, current: nil).contains("export BAT_THEME=\"Chroma\""))
    }
}

@Suite("BatThemeAdapter")
struct BatThemeAdapterTests {
    private let adapter = BatThemeAdapter()

    private func theme(_ id: String) throws -> Theme {
        let store = try ThemeStore.bundled()
        return try #require(store.theme(id: id))
    }

    @Test func generatesValidTmThemePlist() throws {
        let result = try adapter.render(theme: theme("catppuccin-macchiato"), current: nil)
        #expect(result.contains("<plist version=\"1.0\">"))
        #expect(result.contains("<key>name</key>"))
        #expect(result.contains("<string>Chroma</string>"))
        // Global bg = base (macchiato #24273a), fg = text (#cad3f5).
        #expect(result.contains("<key>background</key><string>#24273a</string>"))
        #expect(result.contains("<key>foreground</key><string>#cad3f5</string>"))
    }

    @Test func leavesNoUnrenderedPlaceholders() throws {
        // Every family — including shallow palettes (Nord/Dracula) — must fully
        // resolve through the fallback chain, leaving no template markers.
        for id in ["nord", "dracula", "rose-pine", "kanagawa-wave"] {
            let result = try adapter.render(theme: theme(id), current: nil)
            #expect(!result.contains("{{"), "unrendered placeholder in \(id)")
            #expect(!result.contains("}}"), "unrendered placeholder in \(id)")
        }
    }
}
