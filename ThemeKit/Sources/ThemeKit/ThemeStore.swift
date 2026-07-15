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
        guard let urls = Bundle.module.urls(
            forResourcesWithExtension: "json", subdirectory: "Themes"
        ), !urls.isEmpty else {
            throw LoadError.resourcesNotFound
        }
        let themes = try urls.map(loadTheme(at:))
        return ThemeStore(themes: themes)
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

    public enum LoadError: Error {
        case resourcesNotFound
        case decodeFailed(url: URL, underlying: Error)
    }
}
