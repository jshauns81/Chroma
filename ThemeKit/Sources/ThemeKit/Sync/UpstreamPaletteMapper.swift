import Foundation

/// Translates a *family's* upstream palette payload into Chroma color roles.
///
/// Every upstream project ships colors under its own names (Catppuccin's
/// `mauve`/`peach`/`teal`, Nord's `nord0`…`nord15`). A mapper owns that
/// family-specific naming so the rest of the sync path stays palette-agnostic:
/// give it the raw bytes and the variant, get back `ColorRole → HexColor`.
public protocol UpstreamPaletteMapper: Sendable {
    func colors(from data: Data, variant: String) throws -> [ColorRole: HexColor]
}

/// Maps the canonical `catppuccin/palette` `palette.json` onto Chroma roles.
///
/// The payload is `{ "version": "…", "latte": {…}, "frappe": {…}, … }`; each
/// flavor has a `colors` object of `{ name: { hex, rgb, … } }`. We take only
/// `hex`. The name→role table is deliberately partial — Catppuccin defines 26
/// colors, Chroma models 17 roles — and picking *which* upstream color fills
/// each role is the actual editorial decision here (e.g. `peach → orange`,
/// `teal → cyan`, `overlay0 → overlay`, `subtext0 → textMuted`).
public struct CatppuccinMapper: UpstreamPaletteMapper {
    public init() {}

    /// Upstream Catppuccin color name → Chroma role. Reproduces exactly the
    /// hex values already in the bundled Catppuccin JSONs, so syncing an
    /// unchanged upstream is a no-op diff.
    static let roleForUpstreamName: [String: ColorRole] = [
        "base": .base,
        "mantle": .mantle,
        "crust": .crust,
        "surface0": .surface0,
        "surface1": .surface1,
        "surface2": .surface2,
        "overlay0": .overlay,
        "subtext0": .textMuted,
        "text": .text,
        "red": .red,
        "peach": .orange,
        "yellow": .yellow,
        "green": .green,
        "teal": .cyan,
        "blue": .blue,
        "mauve": .purple,
        "pink": .pink,
    ]

    private struct Swatch: Decodable { let hex: String }
    private struct Flavor: Decodable { let colors: [String: Swatch] }

    public func colors(from data: Data, variant: String) throws -> [ColorRole: HexColor] {
        let flavor = try decodeFlavor(named: variant, from: data)

        var resolved: [ColorRole: HexColor] = [:]
        for (upstreamName, role) in Self.roleForUpstreamName {
            guard let swatch = flavor.colors[upstreamName] else {
                throw ThemeSyncError.missingUpstreamColor(name: upstreamName)
            }
            guard let color = HexColor(parsing: swatch.hex) else {
                throw ThemeSyncError.invalidUpstreamColor(name: upstreamName, value: swatch.hex)
            }
            resolved[role] = color
        }
        return resolved
    }

    /// Pull out one flavor, tolerating the top-level `version` string key.
    ///
    /// Decoding the whole payload as `[String: Flavor]` would choke on that
    /// non-object `version` value, so we walk the keyed container by hand and
    /// only decode the flavor we were asked for.
    private func decodeFlavor(named variant: String, from data: Data) throws -> Flavor {
        let container = try JSONDecoder().decode(FlavorContainer.self, from: data)
        guard let flavor = container.flavors[variant] else {
            throw ThemeSyncError.variantNotFound(variant)
        }
        return flavor
    }

    private struct FlavorContainer: Decodable {
        let flavors: [String: Flavor]

        private struct DynamicKey: CodingKey {
            var stringValue: String
            var intValue: Int? { nil }
            init(stringValue: String) { self.stringValue = stringValue }
            init?(intValue: Int) { nil }
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: DynamicKey.self)
            var flavors: [String: Flavor] = [:]
            for key in container.allKeys {
                // Non-flavor keys (`version`) simply don't decode as a Flavor.
                if let flavor = try? container.decode(Flavor.self, forKey: key) {
                    flavors[key.stringValue] = flavor
                }
            }
            self.flavors = flavors
        }
    }
}
