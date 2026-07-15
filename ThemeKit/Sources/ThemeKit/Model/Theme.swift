import Foundation

/// A complete, loadable theme: identity, provenance, the semantic `Palette`,
/// and the per-tool names adapters map onto.
///
/// Decoded from one JSON file in `Resources/Themes/`. The palette carries the
/// actual colors; everything else here is metadata that drives listing,
/// `themectl sync`, and each adapter's config edit.
public struct Theme: Codable, Hashable, Sendable, Identifiable {
    /// Stable slug, matches the JSON filename stem (e.g. `catppuccin-mocha`).
    public let id: String
    /// Human-facing display name (e.g. `Catppuccin Mocha`).
    public let name: String
    /// Palette family this belongs to (e.g. `catppuccin`).
    public let family: String
    /// Variant within the family (e.g. `mocha`).
    public let variant: String
    public let appearance: Appearance
    public let source: Source
    public let palette: Palette
    /// Per-adapter identifiers, keyed by tool name (`ghostty`, `zellij`, …).
    /// The name a tool already knows a theme by, so an adapter can reference an
    /// existing built-in instead of always generating colors from scratch.
    public let toolNames: [String: String]

    public init(
        id: String, name: String, family: String, variant: String,
        appearance: Appearance, source: Source, palette: Palette,
        toolNames: [String: String]
    ) {
        self.id = id
        self.name = name
        self.family = family
        self.variant = variant
        self.appearance = appearance
        self.source = source
        self.palette = palette
        self.toolNames = toolNames
    }

    /// Whether the palette defines every required role. Provenance is metadata;
    /// only the palette can be structurally invalid.
    public func validate() throws {
        try palette.validate()
    }
}

extension Theme {
    /// Light vs. dark — lets the UI group themes and pick a sensible default
    /// against the system appearance.
    public enum Appearance: String, Codable, Sendable, CaseIterable {
        case light, dark
    }

    /// Where the palette came from, so `themectl sync` can refresh it from the
    /// canonical upstream.
    public struct Source: Codable, Hashable, Sendable {
        public let url: URL
        /// Git ref (branch, tag, or commit SHA) the colors were taken from.
        public let ref: String
        public let fetchedAt: Date

        public init(url: URL, ref: String, fetchedAt: Date) {
            self.url = url
            self.ref = ref
            self.fetchedAt = fetchedAt
        }
    }
}
