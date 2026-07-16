import Testing
@testable import ThemeKit

@Suite("SpicetifyAdapter")
struct SpicetifyAdapterTests {
    private let adapter = SpicetifyAdapter()

    private func theme(_ id: String) throws -> Theme {
        let store = try ThemeStore.bundled()
        return try #require(store.theme(id: id))
    }

    @Test func emitsChromaSchemeHeader() throws {
        let result = try adapter.render(theme: theme("catppuccin-macchiato"), current: nil)
        #expect(result.contains("[chroma]"))
    }

    /// `main` resolves to base as bare hex — macchiato base is #24273a.
    @Test func mainIsBaseAsBareHex() throws {
        let result = try adapter.render(theme: theme("catppuccin-macchiato"), current: nil)
        #expect(result.contains("main                = 24273a"))
    }

    /// Accent keys lead with the theme's primaryAccent — macchiato's is
    /// `purple` (#c6a0f6).
    @Test func buttonActiveIsAccent() throws {
        let result = try adapter.render(theme: theme("catppuccin-macchiato"), current: nil)
        #expect(result.contains("button-active       = c6a0f6"))
    }

    /// `notification-error` maps to the red role — macchiato red is #ed8796.
    @Test func notificationErrorIsRed() throws {
        let result = try adapter.render(theme: theme("catppuccin-macchiato"), current: nil)
        #expect(result.contains("notification-error  = ed8796"))
    }

    /// Bare-hex invariant: no `#` anywhere. The header uses `;`, not `#`, so a
    /// stray `#` would only come from a leaked `HexColor.hexString`.
    @Test func containsNoHashCharacters() throws {
        let result = try adapter.render(theme: theme("catppuccin-macchiato"), current: nil)
        #expect(!result.contains("#"))
    }

    /// Shallow palettes (Nord/Dracula/Rosé Pine) must still resolve every key
    /// through the fallback chain and produce a complete scheme.
    @Test func rendersCompleteSchemeForShallowPalettes() throws {
        let keys = [
            "text", "subtext", "main", "main-elevated", "highlight",
            "highlight-elevated", "sidebar", "player", "card", "shadow",
            "selected-row", "button", "button-active", "button-disabled",
            "tab-active", "notification", "notification-error", "equalizer",
            "misc",
        ]
        for id in ["nord", "dracula", "rose-pine"] {
            let result = try adapter.render(theme: theme(id), current: nil)
            for key in keys {
                #expect(result.contains("\(key) "), "\(id) is missing key \(key)")
            }
        }
    }
}
