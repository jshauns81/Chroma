import Foundation

/// Refreshes a `Theme`'s palette from its canonical upstream source.
///
/// The transform is deliberately narrow: only the palette colors and
/// `source.fetchedAt` come from upstream. Identity (`id`/`name`/`variant`),
/// the chosen `primaryAccent`, and per-tool `toolNames` are Chroma's own
/// editorial metadata and are preserved verbatim — a re-sync should never
/// clobber a curated accent choice.
///
/// Like `ApplyEngine`, all side effects (the network fetch) are injected, so
/// the whole thing is exercised in tests against a fixture with no network.
public struct ThemeSyncer: Sendable {
    let fetcher: any ThemeFetcher
    /// Upstream mapper per palette `family`. v1 ships only Catppuccin; adding
    /// Nord later is one entry here plus one `UpstreamPaletteMapper`.
    let mappers: [String: any UpstreamPaletteMapper]

    public static let defaultMappers: [String: any UpstreamPaletteMapper] = [
        "catppuccin": CatppuccinMapper(),
    ]

    public init(
        fetcher: any ThemeFetcher = URLSessionThemeFetcher(),
        mappers: [String: any UpstreamPaletteMapper] = ThemeSyncer.defaultMappers
    ) {
        self.fetcher = fetcher
        self.mappers = mappers
    }

    /// Fetch `theme`'s upstream palette and return a copy with refreshed colors
    /// and `fetchedAt = now`. `now` is a parameter (not `Date()` inside) so the
    /// result is deterministic under test.
    public func synced(_ theme: Theme, now: Date) async throws -> Theme {
        guard let mapper = mappers[theme.family] else {
            throw ThemeSyncError.unsupportedFamily(theme.family)
        }

        let rawURL = try Self.rawURL(for: theme.source)
        let data = try await fetcher.data(from: rawURL)
        let colors = try mapper.colors(from: data, variant: theme.variant)

        let palette = Palette(colors: colors, primaryAccent: theme.palette.primaryAccent)
        let source = Theme.Source(url: theme.source.url, ref: theme.source.ref, fetchedAt: now)
        return Theme(
            id: theme.id, name: theme.name, family: theme.family,
            variant: theme.variant, appearance: theme.appearance,
            source: source, palette: palette, toolNames: theme.toolNames
        )
    }

    /// Rewrite a GitHub *blob* URL (what a human pastes) into the *raw* content
    /// URL a fetch actually needs, substituting `source.ref` for the branch in
    /// the path so pinning to a tag or SHA works. A URL that's already raw is
    /// returned untouched; anything else is rejected rather than guessed at.
    static func rawURL(for source: Theme.Source) throws -> URL {
        guard let components = URLComponents(url: source.url, resolvingAgainstBaseURL: false) else {
            throw ThemeSyncError.unfetchableSource(source.url)
        }

        switch components.host {
        case "raw.githubusercontent.com":
            return source.url

        case "github.com":
            // Expect /{owner}/{repo}/blob/{ref}/{path…}
            let parts = source.url.pathComponents.filter { $0 != "/" }
            guard parts.count >= 5, parts[2] == "blob" else {
                throw ThemeSyncError.unfetchableSource(source.url)
            }
            let path = parts[4...].joined(separator: "/")
            var raw = components
            raw.host = "raw.githubusercontent.com"
            raw.path = "/\(parts[0])/\(parts[1])/\(source.ref)/\(path)"
            guard let url = raw.url else {
                throw ThemeSyncError.unfetchableSource(source.url)
            }
            return url

        default:
            throw ThemeSyncError.unfetchableSource(source.url)
        }
    }
}
