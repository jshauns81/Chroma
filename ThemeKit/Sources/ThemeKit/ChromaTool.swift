import Foundation

/// One tool Chroma manages, as a static description: the `ThemeAdapter` that
/// themes it, where its config lives (relative to `$HOME`), and how to reload it.
///
/// This is the single source of truth for the tool roster, shared by the app
/// (which wraps it as `ToolDescriptor`) and `themectl apply`. Keeping it in
/// ThemeKit is what stops the GUI and the CLI from drifting into applying
/// different files — a real risk given both write live dotfiles.
public struct ChromaTool: Identifiable, Sendable {
    /// Matches `adapter.toolName` and the per-tool settings key.
    public let id: String
    public let displayName: String
    public let adapter: any ThemeAdapter
    /// Config path relative to the user's home directory.
    public let relativePath: String
    /// Reload command as `[executable, args…]`, or `nil` if none.
    public let reloadCommand: [String]?

    public init(
        id: String, displayName: String, adapter: any ThemeAdapter,
        relativePath: String, reloadCommand: [String]?
    ) {
        self.id = id
        self.displayName = displayName
        self.adapter = adapter
        self.relativePath = relativePath
        self.reloadCommand = reloadCommand
    }

    public var configURL: URL {
        URL(fileURLWithPath: NSHomeDirectory()).appending(path: relativePath)
    }

    /// The path with `~` for display, e.g. `~/.config/ghostty/config`.
    public var displayPath: String { "~/\(relativePath)" }

    /// Build a `ManagedTool` for the apply engine. Pass `runReload: false` to
    /// strip the reload hook (e.g. `themectl apply --no-reload`).
    public func managedTool(runReload: Bool = true) -> ManagedTool {
        ManagedTool(adapter: adapter, url: configURL, reloadCommand: runReload ? reloadCommand : nil)
    }
}

/// The v1 tool roster (PLAN.md §"v1 tool scope"). Adding a tool later is one
/// entry here plus its adapter — nothing else moves.
public enum ChromaTools {
    public static let all: [ChromaTool] = [
        ChromaTool(
            id: "ghostty", displayName: "Ghostty", adapter: GhosttyAdapter(),
            relativePath: ".config/ghostty/config",
            // Ghostty runs one shared instance and only reloads on the
            // reload_config keybind or SIGUSR2 (Ghostty 1.2+). There's no
            // reload CLI subcommand. `-x` matches the process name exactly so
            // we signal only Ghostty — and it MUST be USR2: any other signal
            // crashes Ghostty.
            reloadCommand: ["pkill", "-USR2", "-x", "ghostty"]
        ),
        ChromaTool(
            id: "starship", displayName: "Starship", adapter: StarshipAdapter(),
            relativePath: ".config/starship.toml", reloadCommand: nil
        ),
        ChromaTool(
            id: "zellij", displayName: "Zellij", adapter: ZellijAdapter(),
            relativePath: ".config/zellij/config.kdl", reloadCommand: nil
        ),
        ChromaTool(
            id: "bat", displayName: "bat", adapter: BatThemeAdapter(),
            // Chroma generates a .tmTheme from the palette for EVERY theme (no
            // dependence on bat's built-ins); `bat cache --build` picks it up.
            relativePath: ".config/bat/themes/Chroma.tmTheme",
            reloadCommand: ["bat", "cache", "--build"]
        ),
        ChromaTool(
            id: "bat-env", displayName: "bat (BAT_THEME)", adapter: BatAdapter(),
            // One-time constant `export BAT_THEME="Chroma"`, sourced from .zshrc.
            relativePath: ".config/chroma/theme.zsh", reloadCommand: nil
        ),
        ChromaTool(
            id: "sketchybar", displayName: "SketchyBar", adapter: SketchyBarAdapter(),
            // Chroma owns THIS file, not the user's hand-authored colors.sh. The
            // user sources it and maps CHROMA_* onto their own names — so a
            // re-theme never touches their $FONT or derived tokens.
            relativePath: ".config/sketchybar/chroma-palette.sh",
            reloadCommand: ["sketchybar", "--reload"]
        ),
        ChromaTool(
            id: "spicetify", displayName: "Spicetify", adapter: SpicetifyAdapter(),
            // Chroma owns this generated theme; `spicetify apply` re-patches Spotify.
            relativePath: ".config/spicetify/Themes/Chroma/color.ini",
            reloadCommand: ["spicetify", "apply"]
        ),
    ]
}

/// Well-known filesystem locations Chroma reads and writes, shared by the app
/// and `themectl` so both agree on where state lives.
public enum ChromaPaths {
    /// `~/.config/chroma` — Chroma's own config directory (holds `theme.zsh`,
    /// the current-theme marker, …).
    public static var configDirectory: URL {
        URL(fileURLWithPath: NSHomeDirectory()).appending(path: ".config/chroma", directoryHint: .isDirectory)
    }

    /// `~/.config/chroma/current` — the id of the theme applied most recently,
    /// written on every apply. Lets external tools (the SketchyBar switcher)
    /// show and check-mark what's live.
    public static var currentThemeState: URL {
        configDirectory.appending(path: "current")
    }

    /// `~/Library/Application Support/Chroma/Themes` — where the app persists
    /// imported themes. Loaded alongside the bundled roster.
    public static var importedThemesDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appending(path: "Chroma/Themes", directoryHint: .isDirectory)
    }
}
