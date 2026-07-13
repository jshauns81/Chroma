import Testing
@testable import ThemeKit

@Suite("Palette role fallbacks")
struct PaletteTests {
    /// A shallow palette like Nord's: one background, no surface levels.
    private var shallow: Palette {
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

    @Test func exactRolesResolveDirectly() {
        #expect(shallow[.base].rgb == 0x2E3440)
        #expect(shallow[.cyan].rgb == 0x88C0D0)
    }

    @Test func missingSurfacesFallBackToBase() {
        #expect(shallow[.mantle].rgb == 0x2E3440)
        #expect(shallow[.crust].rgb == 0x2E3440)
        #expect(shallow[.surface0].rgb == 0x2E3440)
        #expect(shallow[.surface2].rgb == 0x2E3440)
    }

    @Test func missingAccentsFallBackToNeighbors() {
        #expect(shallow[.orange].rgb == 0xEBCB8B)  // → yellow
        #expect(shallow[.pink].rgb == 0xB48EAD)    // → purple
    }

    @Test func surfaceChainPrefersDeepestDefined() {
        var palette = shallow
        palette.colors[.surface0] = HexColor(rgb: 0x3B4252)
        #expect(palette[.surface2].rgb == 0x3B4252)  // surface2 → surface1 → surface0
        #expect(palette[.overlay].rgb == 0x3B4252)
    }

    @Test func primaryAccentResolves() {
        #expect(shallow.accent.rgb == 0x88C0D0)
    }

    @Test func validationPassesForCompletePalette() throws {
        try shallow.validate()
    }

    @Test func validationNamesMissingRequiredRoles() {
        var palette = shallow
        palette.colors[.red] = nil
        palette.colors[.base] = nil
        #expect(throws: Palette.ValidationError.missingRequiredRoles([.base, .red])) {
            try palette.validate()
        }
    }
}
