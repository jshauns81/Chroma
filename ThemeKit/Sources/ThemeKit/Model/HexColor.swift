import SwiftUI

/// An opaque sRGB color stored as 24-bit RGB.
///
/// Alpha is deliberately not part of the model — themes define opaque palette
/// colors, and tools that want translucency (SketchyBar's `0xAARRGGBB`)
/// compose alpha at render time via `argb(alpha:)`.
public struct HexColor: Codable, Hashable, Sendable {
    public let rgb: UInt32

    public init(rgb: UInt32) {
        self.rgb = rgb & 0xFFFFFF
    }

    /// Accepts `#a6da95`, `a6da95`, and `0xffa6da95` (alpha prefix discarded).
    public init?(parsing string: String) {
        var hex = string.trimmingCharacters(in: .whitespaces).lowercased()
        if hex.hasPrefix("#") { hex.removeFirst() }
        if hex.hasPrefix("0x") { hex.removeFirst(2) }
        if hex.count == 8 { hex.removeFirst(2) }
        guard hex.count == 6, let value = UInt32(hex, radix: 16) else { return nil }
        self.init(rgb: value)
    }

    /// `"#a6da95"`
    public var hexString: String {
        String(format: "#%06x", rgb)
    }

    /// `"0xffa6da95"` — SketchyBar's AARRGGBB format.
    public func argb(alpha: UInt8 = 0xFF) -> String {
        String(format: "0x%02x%06x", alpha, rgb)
    }

    public var red: Double { Double((rgb >> 16) & 0xFF) / 255 }
    public var green: Double { Double((rgb >> 8) & 0xFF) / 255 }
    public var blue: Double { Double(rgb & 0xFF) / 255 }

    public var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue)
    }

    // Encode as "#rrggbb" in JSON rather than a raw integer, so theme files
    // stay hand-editable and diff-readable.
    public init(from decoder: Decoder) throws {
        let string = try decoder.singleValueContainer().decode(String.self)
        guard let parsed = HexColor(parsing: string) else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Invalid hex color: \(string)"
            ))
        }
        self = parsed
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(hexString)
    }
}
