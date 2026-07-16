import Testing
import Foundation
@testable import ThemeKit

@Suite("ThemeSyncer")
struct ThemeSyncerTests {
    /// Records the URL it was asked to fetch and always returns a fixed payload,
    /// so the syncer is exercised end-to-end without touching the network.
    private actor StubFetcher: ThemeFetcher {
        let payload: Data
        private(set) var lastURL: URL?

        init(_ payload: Data) { self.payload = payload }

        func data(from url: URL) async throws -> Data {
            lastURL = url
            return payload
        }
    }

    /// A minimal `catppuccin/palette` payload: the top-level `version` string
    /// plus a `mocha` flavor carrying the exact upstream hexes the bundled
    /// mocha theme was authored from.
    private static let mochaUpstream = Data("""
    {
      "version": "1.8.0",
      "mocha": {
        "colors": {
          "base":     { "hex": "#1e1e2e" },
          "mantle":   { "hex": "#181825" },
          "crust":    { "hex": "#11111b" },
          "surface0": { "hex": "#313244" },
          "surface1": { "hex": "#45475a" },
          "surface2": { "hex": "#585b70" },
          "overlay0": { "hex": "#6c7086" },
          "subtext0": { "hex": "#a6adc8" },
          "text":     { "hex": "#cdd6f4" },
          "red":      { "hex": "#f38ba8" },
          "peach":    { "hex": "#fab387" },
          "yellow":   { "hex": "#f9e2af" },
          "green":    { "hex": "#a6e3a1" },
          "teal":     { "hex": "#94e2d5" },
          "blue":     { "hex": "#89b4fa" },
          "mauve":    { "hex": "#cba6f7" },
          "pink":     { "hex": "#f5c2e7" }
        }
      }
    }
    """.utf8)

    private func mocha() throws -> Theme {
        try #require(try ThemeStore.bundled().theme(id: "catppuccin-mocha"))
    }

    private let epoch = Date(timeIntervalSince1970: 0)

    @Test func reproducesBundledPaletteFromUpstream() async throws {
        let theme = try mocha()
        let syncer = ThemeSyncer(fetcher: StubFetcher(Self.mochaUpstream))

        let synced = try await syncer.synced(theme, now: epoch)

        // The role mapping round-trips: syncing an unchanged upstream yields
        // exactly the bundled palette.
        #expect(synced.palette.colors == theme.palette.colors)
    }

    @Test func preservesEditorialMetadataAndStampsFetchedAt() async throws {
        let theme = try mocha()
        let syncer = ThemeSyncer(fetcher: StubFetcher(Self.mochaUpstream))

        let synced = try await syncer.synced(theme, now: epoch)

        #expect(synced.palette.primaryAccent == theme.palette.primaryAccent)
        #expect(synced.toolNames == theme.toolNames)
        #expect(synced.name == theme.name)
        #expect(synced.source.url == theme.source.url)
        #expect(synced.source.ref == theme.source.ref)
        #expect(synced.source.fetchedAt == epoch)
    }

    @Test func fetchesTheRawGitHubContentURL() async throws {
        let fetcher = StubFetcher(Self.mochaUpstream)
        _ = try await ThemeSyncer(fetcher: fetcher).synced(mocha(), now: epoch)

        let requested = await fetcher.lastURL
        #expect(requested?.absoluteString ==
                "https://raw.githubusercontent.com/catppuccin/palette/main/palette.json")
    }

    @Test func rawURLRewritesBlobAndHonorsRef() throws {
        let source = Theme.Source(
            url: URL(string: "https://github.com/catppuccin/palette/blob/main/palette.json")!,
            ref: "v1.8.0",
            fetchedAt: epoch
        )
        let raw = try ThemeSyncer.rawURL(for: source)
        #expect(raw.absoluteString ==
                "https://raw.githubusercontent.com/catppuccin/palette/v1.8.0/palette.json")
    }

    @Test func unsupportedFamilyThrows() async throws {
        let theme = Theme(
            id: "nord", name: "Nord", family: "nord", variant: "nord",
            appearance: .dark,
            source: .init(url: URL(string: "https://example.com")!, ref: "main", fetchedAt: epoch),
            palette: Palette(colors: [.base: HexColor(rgb: 0), .text: HexColor(rgb: 0xFFFFFF)],
                             primaryAccent: .blue),
            toolNames: [:]
        )
        let syncer = ThemeSyncer(fetcher: StubFetcher(Self.mochaUpstream))

        await #expect(throws: ThemeSyncError.unsupportedFamily("nord")) {
            try await syncer.synced(theme, now: epoch)
        }
    }

    @Test func variantMissingFromUpstreamThrows() async throws {
        // The fixture only carries `mocha`; a frappé theme has no match.
        let frappe = try #require(try ThemeStore.bundled().theme(id: "catppuccin-frappe"))
        let syncer = ThemeSyncer(fetcher: StubFetcher(Self.mochaUpstream))

        await #expect(throws: ThemeSyncError.variantNotFound("frappe")) {
            try await syncer.synced(frappe, now: epoch)
        }
    }
}
