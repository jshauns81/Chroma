import Testing
@testable import ThemeKit

@Suite("BatAdapter")
struct BatAdapterTests {
    private let adapter = BatAdapter()

    private func macchiato() throws -> Theme {
        let store = try ThemeStore.bundled()
        return try #require(store.theme(id: "catppuccin-macchiato"))
    }

    @Test func exportsBatThemeName() throws {
        let result = try adapter.render(theme: macchiato(), current: nil)
        #expect(result.contains("export BAT_THEME=\"Catppuccin Macchiato\""))
    }
}
