import Foundation

/// The set of themes Chroma knows about, loaded from disk.
///
/// v1 loads the bundled themes shipped inside `ThemeKit`; later milestones can
/// add user-authored themes from `~/.config/chroma/themes`. Kept as a value
/// type so it's trivially `Sendable` and snapshot-friendly for the UI.
public struct ThemeStore: Sendable {
    /// Themes sorted for stable display: dark before light, then by name.
    public let themes: [Theme]

    public init(themes: [Theme]) {
        self.themes = themes.sorted {
            if $0.appearance != $1.appearance {
                return $0.appearance == .dark  // dark first
            }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    public func theme(id: String) -> Theme? {
        themes.first { $0.id == id }
    }

    /// Loads every `*.json` theme bundled in `ThemeKit`'s `Resources/Themes/`.
    ///
    /// `Bundle.module` is SwiftPM's generated accessor for a target's copied
    /// resources — it works the same under `swift test` from the terminal and
    /// inside the app, which is why all logic lives here rather than in the app
    /// target.
    public static func bundled() throws -> ThemeStore {
        let themes = try bundledThemeURLs().map(loadTheme(at:))
        return ThemeStore(themes: themes)
    }

    /// Loads every `*.json` theme from an arbitrary directory on disk.
    ///
    /// This is the maintainer-facing entry point (`themectl` pointed at the
    /// repo's `Resources/Themes/`), as opposed to `bundled()`'s read-only
    /// copy inside the built product.
    public static func load(fromDirectory directory: URL) throws -> ThemeStore {
        let themes = try themeURLs(in: directory).map(loadTheme(at:))
        return ThemeStore(themes: themes)
    }

    /// URLs of the theme JSONs shipped inside `ThemeKit`.
    static func bundledThemeURLs() throws -> [URL] {
        guard let urls = Bundle.module.urls(
            forResourcesWithExtension: "json", subdirectory: "Themes"
        ), !urls.isEmpty else {
            throw LoadError.resourcesNotFound
        }
        return urls.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// The `*.json` files in `directory`, sorted by filename for stable output.
    static func themeURLs(in directory: URL) throws -> [URL] {
        let urls = try FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "json" }
        guard !urls.isEmpty else { throw LoadError.resourcesNotFound }
        return urls.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// Decodes one theme file, wrapping any failure with the offending URL so a
    /// malformed file is identifiable instead of an anonymous decode error.
    static func loadTheme(at url: URL) throws -> Theme {
        let decoder = JSONDecoder()
        // `fetchedAt` is an ISO-8601 timestamp; the default strategy expects a
        // numeric interval, so it must be set explicitly.
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(Theme.self, from: Data(contentsOf: url))
        } catch {
            throw LoadError.decodeFailed(url: url, underlying: error)
        }
    }

    /// Serialize a theme back to the on-disk JSON shape.
    ///
    /// `.sortedKeys` is what makes `themectl sync` diff-friendly: without it a
    /// `[ColorRole: HexColor]` dictionary serializes in arbitrary order, so an
    /// otherwise-identical re-sync would produce noise. Sorting trades a
    /// one-time reordering of the hand-authored files for stable diffs forever
    /// after. `.withoutEscapingSlashes` keeps the `source.url` readable.
    public static func encode(_ theme: Theme) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        var data = try encoder.encode(theme)
        data.append(0x0A)  // trailing newline, like the hand-authored files
        return data
    }

    public enum LoadError: Error {
        case resourcesNotFound
        case decodeFailed(url: URL, underlying: Error)
    }
}
