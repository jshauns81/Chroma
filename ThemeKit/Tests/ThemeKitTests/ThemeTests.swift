import Foundation
import Testing
@testable import ThemeKit

@Suite("Theme decoding")
struct ThemeDecodingTests {
    /// A whole theme file, exercised end to end: metadata, ISO-8601 date,
    /// nested source, and the palette-as-object shape.
    private static let json = Data("""
    {
      "id": "catppuccin-macchiato",
      "name": "Catppuccin Macchiato",
      "family": "catppuccin",
      "variant": "macchiato",
      "appearance": "dark",
      "source": {
        "url": "https://github.com/catppuccin/palette/blob/main/palette.json",
        "ref": "main",
        "fetchedAt": "2026-07-12T00:00:00Z"
      },
      "palette": {
        "primaryAccent": "purple",
        "colors": {
          "base": "#24273a",
          "text": "#cad3f5",
          "red": "#ed8796",
          "yellow": "#eed49f",
          "green": "#a6da95",
          "blue": "#8aadf4",
          "purple": "#c6a0f6"
        }
      },
      "toolNames": { "ghostty": "Catppuccin Macchiato" }
    }
    """.utf8)

    private func decoded() throws -> Theme {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Theme.self, from: Self.json)
    }

    @Test func decodesMetadata() throws {
        let theme = try decoded()
        #expect(theme.id == "catppuccin-macchiato")
        #expect(theme.name == "Catppuccin Macchiato")
        #expect(theme.family == "catppuccin")
        #expect(theme.variant == "macchiato")
        #expect(theme.appearance == .dark)
        #expect(theme.toolNames["ghostty"] == "Catppuccin Macchiato")
    }

    @Test func decodesSourceWithISO8601Date() throws {
        let source = try decoded().source
        #expect(source.ref == "main")
        #expect(source.url.host == "github.com")
        let expected = ISO8601DateFormatter().date(from: "2026-07-12T00:00:00Z")
        #expect(source.fetchedAt == expected)
    }

    /// The palette must come back as a role-keyed object, not a positional
    /// array — this is exactly what synthesized `Codable` would have gotten
    /// wrong.
    @Test func decodesPaletteFromObject() throws {
        let palette = try decoded().palette
        #expect(palette.primaryAccent == .purple)
        #expect(palette[.base].rgb == 0x24273a)
        #expect(palette.accent.rgb == 0xc6a0f6)
    }

    @Test func rejectsUnknownColorRole() {
        let bad = Data("""
        { "primaryAccent": "purple", "colors": { "chartreuse": "#000000" } }
        """.utf8)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(Palette.self, from: bad)
        }
    }

    @Test func paletteRoundTripsThroughObjectForm() throws {
        let original = Palette(
            colors: [.base: HexColor(rgb: 0x24273a), .text: HexColor(rgb: 0xcad3f5)],
            primaryAccent: .text
        )
        let data = try JSONEncoder().encode(original)
        // Encodes as an object keyed by role name, not an array.
        let asString = String(decoding: data, as: UTF8.self)
        #expect(asString.contains("\"base\":\"#24273a\""))
        let restored = try JSONDecoder().decode(Palette.self, from: data)
        #expect(restored == original)
    }
}

@Suite("Bundled theme store")
struct ThemeStoreTests {
    @Test func loadsAllFourCatppuccinFlavors() throws {
        let store = try ThemeStore.bundled()
        let ids = Set(store.themes.map(\.id))
        #expect(ids == [
            "catppuccin-latte",
            "catppuccin-frappe",
            "catppuccin-macchiato",
            "catppuccin-mocha",
        ])
    }

    @Test func everyBundledPaletteValidates() throws {
        for theme in try ThemeStore.bundled().themes {
            try theme.validate()
        }
    }

    @Test func lookupByIDResolves() throws {
        let store = try ThemeStore.bundled()
        #expect(store.theme(id: "catppuccin-mocha")?.name == "Catppuccin Mocha")
        #expect(store.theme(id: "nope") == nil)
    }

    /// Latte is the only light flavor; the store sorts dark-first.
    @Test func sortsDarkBeforeLight() throws {
        let store = try ThemeStore.bundled()
        #expect(store.themes.last?.id == "catppuccin-latte")
        #expect(store.themes.dropLast().allSatisfy { $0.appearance == .dark })
    }
}
