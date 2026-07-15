/// A theme's colors keyed by semantic role.
///
/// Upstream palettes vary in depth — Catppuccin defines three surface levels
/// and a crust; Nord and Dracula don't. The subscript guarantees a usable
/// color for every role via fallback chains, so adapters never need to know
/// how deep the source palette was.
public struct Palette: Codable, Hashable, Sendable {
    public var colors: [ColorRole: HexColor]
    public var primaryAccent: ColorRole

    public init(colors: [ColorRole: HexColor], primaryAccent: ColorRole) {
        self.colors = colors
        self.primaryAccent = primaryAccent
    }

    /// Fallback order per role, tried left to right after the role itself.
    /// `base` and `text` are required and have no fallback — `validate()`
    /// enforces their presence.
    private static let fallbacks: [ColorRole: [ColorRole]] = [
        .mantle: [.base],
        .crust: [.mantle, .base],
        .surface0: [.mantle, .base],
        .surface1: [.surface0, .mantle, .base],
        .surface2: [.surface1, .surface0, .mantle, .base],
        .overlay: [.surface2, .surface1, .surface0, .textMuted],
        .textMuted: [.text],
        .orange: [.yellow, .red],
        .cyan: [.blue, .green],
        .purple: [.pink, .blue],
        .pink: [.purple, .red],
    ]

    public subscript(role: ColorRole) -> HexColor {
        if let exact = colors[role] { return exact }
        for candidate in Palette.fallbacks[role, default: []] {
            if let found = colors[candidate] { return found }
        }
        // Required roles (base, text) and the core accents have no chain;
        // a palette missing them is malformed and should fail validate().
        return colors[.text] ?? HexColor(rgb: 0xFF00FF)
    }

    /// The resolved accent color the theme leads with.
    public var accent: HexColor { self[primaryAccent] }

    /// Roles every palette must define explicitly (no fallback allowed).
    public static let requiredRoles: [ColorRole] = [
        .base, .text, .red, .yellow, .green, .blue,
    ]

    public enum ValidationError: Error, Equatable {
        case missingRequiredRoles([ColorRole])
    }

    public func validate() throws {
        let missing = Palette.requiredRoles.filter { colors[$0] == nil }
        guard missing.isEmpty else {
            throw ValidationError.missingRequiredRoles(missing)
        }
    }
}

// MARK: - Codable

// Hand-written rather than synthesized: a `[ColorRole: HexColor]` dictionary
// only serializes as a JSON *object* keyed by role name if `ColorRole` adopts
// `CodingKeyRepresentable`. Decoding via an intermediate `[String: HexColor]`
// is more explicit and lets us reject unknown role names with a precise error
// instead of silently dropping them — theme files are hand-edited, so a typo'd
// role should fail loudly.
extension Palette {
    private enum CodingKeys: String, CodingKey {
        case colors, primaryAccent
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let named = try container.decode([String: HexColor].self, forKey: .colors)

        var resolved: [ColorRole: HexColor] = [:]
        for (name, color) in named {
            guard let role = ColorRole(rawValue: name) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .colors, in: container,
                    debugDescription: "Unknown color role '\(name)'"
                )
            }
            resolved[role] = color
        }

        self.colors = resolved
        self.primaryAccent = try container.decode(ColorRole.self, forKey: .primaryAccent)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let named = Dictionary(
            uniqueKeysWithValues: colors.map { ($0.key.rawValue, $0.value) }
        )
        try container.encode(named, forKey: .colors)
        try container.encode(primaryAccent, forKey: .primaryAccent)
    }
}
