/// The semantic vocabulary every upstream palette is normalized into.
///
/// Adapters and templates reference roles, never upstream color names —
/// that's what lets one `colors.sh` template render Catppuccin, Nord, and
/// Tokyo Night alike.
public enum ColorRole: String, Codable, CaseIterable, Sendable {
    // Background depth, darkest-to-raised: crust < mantle < base < surfaces.
    case base, mantle, crust
    case surface0, surface1, surface2
    case overlay

    case textMuted, text

    case red, orange, yellow, green, cyan, blue, purple, pink
}
