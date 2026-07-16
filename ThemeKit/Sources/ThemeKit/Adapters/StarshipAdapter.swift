/// Starship adapter — selects the active palette by name.
///
/// Starship's theming model (as Catppuccin documents it) is to define *all* the
/// palette tables in `starship.toml` — `[palettes.catppuccin_mocha]`,
/// `[palettes.catppuccin_macchiato]`, … — and switch between them with a single
/// top-level `palette = "…"` line. So, like Ghostty and Zellij, we only rewrite
/// that one line, using the name from `toolNames["starship"]`. The palette
/// tables themselves are the user's to define (Chroma doesn't generate them).
///
/// Config is TOML: `key = "value"` with `#` comments — the value is quoted, as
/// in Zellij, but the key/`=` shape matches Ghostty.
public struct StarshipAdapter: ThemeAdapter {
    public let toolName = "starship"

    public init() {}

    public func render(theme: Theme, current: String?) throws -> String {
        guard let paletteName = theme.toolNames[toolName] else {
            throw AdapterError.missingToolName(tool: toolName, theme: theme.id)
        }

        let newLine = "palette = \"\(paletteName)\""
        let content = current ?? ""

        return try ConfigLineEditor.replacingLine(
            in: content,
            with: newLine,
            anchorLabel: "palette = \"…\"",
            where: Self.isPaletteLine
        )
    }

    /// True when `line` is an active top-level `palette = "…"` assignment.
    private static func isPaletteLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.hasPrefix("#") else { return false }
        guard let equals = trimmed.firstIndex(of: "=") else { return false }
        return trimmed[..<equals].trimmingCharacters(in: .whitespaces) == "palette"
    }
}
