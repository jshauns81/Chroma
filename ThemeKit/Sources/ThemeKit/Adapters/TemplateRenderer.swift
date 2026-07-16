import Foundation

/// Whole-file generation by substituting `{{role}}` placeholders with a
/// theme's colors.
///
/// Used by tools that have *no* built-in theme to point at, so Chroma must emit
/// their colors directly (Starship, Zellij, bat, SketchyBar — Milestone 3).
///
/// A placeholder is `{{` + a `ColorRole` raw name + `}}`, optionally with a
/// format after a colon: `{{base}}` or `{{ red }}` render as `#rrggbb`, while
/// `{{base:argb}}` renders as `0xAARRGGBB` (opaque) for tools like SketchyBar.
/// Colors resolve through the palette's fallback chain, so `{{surface2}}` still
/// yields a color even for a shallow palette. An unknown role name — or an
/// unknown format — is a hard error: templates are authored by hand, so a typo
/// should fail loudly rather than leave something broken in a generated config.
public enum TemplateRenderer {
    public enum RenderError: Error, Equatable {
        /// A `{{…}}` placeholder named something that isn't a valid `ColorRole`.
        case unknownRole(String)
        /// A `{{role:format}}` placeholder used a format we don't emit.
        case unknownFormat(String)
        /// A `{{` was opened but never closed with a matching `}}`.
        case unterminatedPlaceholder
    }

    /// Render `template`, replacing every `{{role}}` / `{{role:format}}` with
    /// the palette's color for that role in the requested format.
    ///
    /// - Throws: `RenderError.unknownRole` for an unrecognized role name;
    ///   `RenderError.unknownFormat` for an unrecognized format;
    ///   `RenderError.unterminatedPlaceholder` for an unclosed `{{`.
    public static func render(_ template: String, palette: Palette) throws -> String {
        // We build the result up in `output`, and walk through the input with
        // `remaining` — a *slice* of the template that shrinks as we consume it.
        // (A Substring is a cheap window onto the original String; no copying.)
        var output = ""
        var remaining = Substring(template)

        // Each loop handles exactly one `{{…}}` placeholder. When there are no
        // more "{{" left, the loop ends and we append whatever text remains.
        while let open = remaining.range(of: "{{") {
            // 1. Everything before the "{{" is ordinary text — copy it as-is.
            output += String(remaining[..<open.lowerBound])

            // 2. Look for the closing "}}" in the text after the "{{".
            let afterOpen = remaining[open.upperBound...]
            guard let close = afterOpen.range(of: "}}") else {
                throw RenderError.unterminatedPlaceholder
            }

            // 3. The text between the braces is `role` or `role:format`. Split
            //    on the first ":" and trim spaces, so "{{ base : argb }}" works.
            let token = String(afterOpen[..<close.lowerBound])
            let parts = token.split(separator: ":", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            let roleName = parts.first ?? ""
            let formatName = parts.count > 1 ? parts[1] : "hex"

            guard let role = ColorRole(rawValue: roleName) else {
                throw RenderError.unknownRole(roleName)
            }

            // 4. Swap the whole placeholder for the color in the right format.
            output += try format(palette[role], as: formatName)

            // 5. Continue scanning just past the "}}".
            remaining = afterOpen[close.upperBound...]
        }

        // Text after the last placeholder — or the entire input, if it had no
        // placeholders at all.
        output += String(remaining)
        return output
    }

    /// Render one color in the named format.
    /// `hex` → `#rrggbb`; `argb` → `0xAARRGGBB` (opaque), for SketchyBar.
    private static func format(_ color: HexColor, as name: String) throws -> String {
        switch name {
        case "hex":
            return color.hexString
        case "argb":
            return color.argb()
        default:
            throw RenderError.unknownFormat(name)
        }
    }
}
