//
//  DesignSystem.swift
//  Chroma
//
//  The foundation the V2 redesign hangs on: a `Palette` carried through the
//  SwiftUI environment, plus the semantic token mapping that turns the 17
//  `ColorRole`s into the handful of UI roles the chrome actually draws with
//  (window / chrome / track / raised / body / secondary / tertiary / separator
//  / accent). Every redesigned view reads colors through these accessors, never
//  a raw `ColorRole`, so "the window themes itself" is a single source swap.
//

import SwiftUI
import ThemeKit

// MARK: - Semantic tokens

/// The design-system token vocabulary, resolved for one theme's palette.
///
/// This is the 1:1 map the handoff's `--chroma-<role>` CSS vars describe:
/// each token names a *use* (window background, body text, …) and resolves to
/// a `ColorRole` through `Palette`'s existing subscript/fallbacks. Keeping the
/// mapping here — not scattered across views — is what lets a re-theme be a
/// single environment write.
extension Palette {
    /// Window background — the deepest surface. (`base`)
    var windowBackground: Color { self[.base].color }
    /// Toolbar and footer chrome, and card backgrounds. (`mantle`)
    var chromeBackground: Color { self[.mantle].color }
    /// Inset tracks: the segmented-control groove, sunken fields. (`crust`)
    var trackBackground: Color { self[.crust].color }
    /// Raised controls and the selected segment of a segmented control. (`surface0`)
    var raisedBackground: Color { self[.surface0].color }

    /// Primary body text. (`text`)
    var bodyText: Color { self[.text].color }
    /// Secondary/label text. (`textMuted`)
    var secondaryText: Color { self[.textMuted].color }
    /// Tertiary text: footnotes, placeholder glyphs, disabled affordances. (`overlay`)
    var tertiaryText: Color { self[.overlay].color }

    /// Hairline separators — body text at 12% opacity, matching the prototype.
    var separator: Color { self[.text].color.opacity(0.12) }

    /// The theme's leading accent (selection ring, prominent button fill).
    var accentColor: Color { accent.color }
    /// Text that sits *on* an accent fill — the darkest surface reads as ink.
    var onAccentText: Color { self[.crust].color }

    /// The eight named accent hues in the prototype's red→pink order, used for
    /// the accent-dot rows on cards and film chips and the splash bars.
    var accentSpectrum: [Color] {
        [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink]
            .map { self[$0].color }
    }
}

// MARK: - Environment

/// A resident default so the environment always resolves, even before a theme
/// is selected (a packaging error, or the split-second before the model loads).
/// Catppuccin Macchiato — the machine's resident rice — is the honest default.
extension Palette {
    static let chromaFallback = Palette(
        colors: [
            .base: HexColor(rgb: 0x24273a), .mantle: HexColor(rgb: 0x1e2030),
            .crust: HexColor(rgb: 0x181926), .surface0: HexColor(rgb: 0x363a4f),
            .surface1: HexColor(rgb: 0x494d64), .surface2: HexColor(rgb: 0x5b6078),
            .overlay: HexColor(rgb: 0x6e738d), .textMuted: HexColor(rgb: 0xa5adcb),
            .text: HexColor(rgb: 0xcad3f5), .red: HexColor(rgb: 0xed8796),
            .orange: HexColor(rgb: 0xf5a97f), .yellow: HexColor(rgb: 0xeed49f),
            .green: HexColor(rgb: 0xa6da95), .cyan: HexColor(rgb: 0x8bd5ca),
            .blue: HexColor(rgb: 0x8aadf4), .purple: HexColor(rgb: 0xc6a0f6),
            .pink: HexColor(rgb: 0xf5bde6),
        ],
        primaryAccent: .purple
    )
}

private struct ChromaPaletteKey: EnvironmentKey {
    static let defaultValue: Palette = .chromaFallback
}

extension EnvironmentValues {
    /// The palette the surrounding chrome themes itself from. The gallery root
    /// sets this to the *selected* theme's palette; individual `ThemeCard`s and
    /// `FilmChip`s override it with their *own* palette so each renders in the
    /// theme it represents.
    var chromaPalette: Palette {
        get { self[ChromaPaletteKey.self] }
        set { self[ChromaPaletteKey.self] = newValue }
    }
}

// MARK: - Shared metrics

/// The handoff's design tokens as named constants, so views cite an intent
/// rather than a magic number and the whole system stays in visual rhythm.
enum ChromaMetrics {
    // Radii
    static let chipRadius: CGFloat = 4
    static let controlRadius: CGFloat = 5
    static let segmentedTrackRadius: CGFloat = 6
    static let filmChipRadius: CGFloat = 7
    static let cardRadius: CGFloat = 8
    static let windowRadius: CGFloat = 10

    // Grid & spacing
    static let gridPadding: CGFloat = 18
    static let gridGap: CGFloat = 14
    static let toolbarGap: CGFloat = 12

    // Selection
    static let selectionRing: CGFloat = 2.5

    // Hairline separators
    static let hairline: CGFloat = 1
}
