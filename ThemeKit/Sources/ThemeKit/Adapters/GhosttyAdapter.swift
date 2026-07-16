/// Ghostty adapter — points Ghostty at a built-in theme by name.
///
/// Ghostty ships the Catppuccin flavors (and hundreds of others) as built-in
/// themes, so we don't regenerate colors from scratch here: we set the single
/// `theme = <name>` line, using the name the theme records under
/// `toolNames["ghostty"]`. That makes this the reference example for
/// `ConfigLineEditor`'s anchored replacement — one line changes, everything
/// else in the user's config is left untouched.
public struct GhosttyAdapter: ThemeAdapter {
    public let toolName = "ghostty"

    public init() {}

    public func render(theme: Theme, current: String?) throws -> String {
        // Ghostty needs a name to point at. If the theme doesn't record one for
        // us, that's a data problem in the theme JSON — fail loudly rather than
        // write a meaningless `theme = ` line.
        guard let themeName = theme.toolNames[toolName] else {
            throw AdapterError.missingToolName(tool: toolName, theme: theme.id)
        }

        let newLine = "theme = \(themeName)"
        let content = current ?? ""

        return try ConfigLineEditor.replacingLine(
            in: content,
            with: newLine,
            anchorLabel: "theme = …",
            where: Self.isThemeLine
        )
    }

    /// True when `line` is an active `theme = …` assignment.
    ///
    /// Ghostty config is `key = value`. We match a line whose key is exactly
    /// `theme`, tolerating leading/trailing whitespace, and we deliberately
    /// ignore commented-out lines (`# theme = …`) so a leftover comment can't
    /// make the anchor ambiguous.
    private static func isThemeLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.hasPrefix("#") else { return false }
        guard let equals = trimmed.firstIndex(of: "=") else { return false }
        let key = trimmed[..<equals].trimmingCharacters(in: .whitespaces)
        return key == "theme"
    }
}
