/// Zellij adapter — points Zellij at a built-in theme by name.
///
/// Structurally identical to `GhosttyAdapter`: Zellij ships the Catppuccin
/// themes built in, so we just rewrite the single line that selects the active
/// theme, using the name from `toolNames["zellij"]`. The only difference from
/// Ghostty is the config *syntax*: Zellij's config is KDL, where the line looks
/// like `theme "catppuccin-macchiato"` (a bareword key, a space, then a quoted
/// value) and comments start with `//`.
public struct ZellijAdapter: ThemeAdapter {
    public let toolName = "zellij"

    public init() {}

    public func render(theme: Theme, current: String?) throws -> String {
        guard let themeName = theme.toolNames[toolName] else {
            throw AdapterError.missingToolName(tool: toolName, theme: theme.id)
        }

        // KDL quotes the value, unlike Ghostty's `theme = <name>`.
        let newLine = "theme \"\(themeName)\""
        let content = current ?? ""

        return try ConfigLineEditor.replacingLine(
            in: content,
            with: newLine,
            anchorLabel: "theme \"…\"",
            where: Self.isThemeLine
        )
    }

    /// True when `line` is an active `theme "…"` KDL statement.
    ///
    /// We match a line whose first whitespace-separated token is exactly
    /// `theme`, and skip `//` comments so a commented example can't become an
    /// ambiguous second anchor.
    private static func isThemeLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.hasPrefix("//") else { return false }
        let firstToken = trimmed.split(separator: " ", maxSplits: 1).first
        return firstToken.map(String.init) == "theme"
    }
}
