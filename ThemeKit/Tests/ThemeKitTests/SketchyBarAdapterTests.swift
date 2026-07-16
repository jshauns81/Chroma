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
        #expect(result.contains("export CHROMA_BASE=0xff24273a"))
        #expect(result.contains("export CHROMA_BLUE=0xff8aadf4"))
    }

    @Test func leavesNoUnrenderedPlaceholders() throws {
        let result = try adapter.render(theme: macchiato(), current: nil)
        #expect(!result.contains("{{"))
        #expect(!result.contains("}}"))
    }

    /// Regression guard: Chroma owns a separate file and must never emit
    /// unnamespaced vars that would collide with the user's hand-authored
    /// colors.sh (the 2026-07-15 clobber bug). Every export is CHROMA_-prefixed.
    @Test func everyExportIsNamespaced() throws {
        let result = try adapter.render(theme: macchiato(), current: nil)
        for line in result.split(separator: "\n") where line.hasPrefix("export ") {
            #expect(line.hasPrefix("export CHROMA_"), "un-namespaced export: \(line)")
        }
    }
}
