import Testing
@testable import ThemeKit

/// Spec for the `TemplateRenderer.render` you're implementing. These will fail
/// (or throw) until the TODO in TemplateRenderer.swift is done — that's
/// expected. Run with ⌘U and make them all green.
@Suite("TemplateRenderer role substitution")
struct TemplateRendererTests {
    /// A shallow palette (Nord-like): forces fallbacks to be exercised too.
    private var palette: Palette {
        Palette(
            colors: [
                .base: HexColor(rgb: 0x2E3440),
                .text: HexColor(rgb: 0xECEFF4),
                .textMuted: HexColor(rgb: 0xD8DEE9),
                .red: HexColor(rgb: 0xBF616A),
                .yellow: HexColor(rgb: 0xEBCB8B),
                .green: HexColor(rgb: 0xA3BE8C),
                .cyan: HexColor(rgb: 0x88C0D0),
                .blue: HexColor(rgb: 0x81A1C1),
                .purple: HexColor(rgb: 0xB48EAD),
            ],
            primaryAccent: .cyan
        )
    }

    @Test func substitutesRolesWithHexStrings() throws {
        let template = "bg = {{base}}\nfg = {{text}}\naccent = {{blue}}"
        let result = try TemplateRenderer.render(template, palette: palette)
        #expect(result == "bg = #2e3440\nfg = #eceff4\naccent = #81a1c1")
    }

    @Test func leavesTextWithoutPlaceholdersUntouched() throws {
        let template = "# a comment\nplain = value"
        #expect(try TemplateRenderer.render(template, palette: palette) == template)
    }

    @Test func resolvesThroughFallbackChain() throws {
        // surface2 isn't defined; it should fall back to base (#2e3440).
        #expect(try TemplateRenderer.render("{{surface2}}", palette: palette) == "#2e3440")
    }

    @Test func toleratesWhitespaceInsidePlaceholder() throws {
        #expect(try TemplateRenderer.render("{{ red }}", palette: palette) == "#bf616a")
    }

    @Test func throwsOnUnknownRole() {
        #expect(throws: TemplateRenderer.RenderError.unknownRole("bleu")) {
            try TemplateRenderer.render("{{bleu}}", palette: palette)
        }
    }

    @Test func throwsOnUnterminatedPlaceholder() {
        #expect(throws: TemplateRenderer.RenderError.unterminatedPlaceholder) {
            try TemplateRenderer.render("color = {{blue", palette: palette)
        }
    }

    @Test func argbFormatEmitsAARRGGBB() throws {
        // base #2e3440, opaque → 0xff2e3440
        #expect(try TemplateRenderer.render("{{base:argb}}", palette: palette) == "0xff2e3440")
    }

    @Test func throwsOnUnknownFormat() {
        #expect(throws: TemplateRenderer.RenderError.unknownFormat("rgba")) {
            try TemplateRenderer.render("{{blue:rgba}}", palette: palette)
        }
    }
}
