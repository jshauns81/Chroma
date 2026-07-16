import Testing
@testable import ThemeKit

@Suite("SketchyBarAdapter")
struct SketchyBarAdapterTests {
    private let adapter = SketchyBarAdapter()

    private func macchiato() throws -> Theme {
        let store = try ThemeStore.bundled()
        return try #require(store.theme(id: "catppuccin-macchiato"))
    }

    @Test func generatesColorsFileInARGB() throws {
        let result = try adapter.render(theme: macchiato(), current: nil)
        // macchiato base #24273a and blue #8aadf4, opaque, in 0xAARRGGBB.
        #expect(result.contains("export BASE=0xff24273a"))
        #expect(result.contains("export BLUE=0xff8aadf4"))
    }

    @Test func leavesNoUnrenderedPlaceholders() throws {
        let result = try adapter.render(theme: macchiato(), current: nil)
        #expect(!result.contains("{{"))
        #expect(!result.contains("}}"))
    }
}
