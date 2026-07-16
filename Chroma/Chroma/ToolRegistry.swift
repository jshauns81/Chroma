//
//  ToolRegistry.swift
//  Chroma
//

import Foundation
import ThemeKit

/// Static description of one v1 tool: the `ThemeAdapter` that knows how to
/// theme it, where its config lives (relative to `$HOME`), and how to reload
/// it afterwards.
///
/// This is the app-side counterpart to `ThemeKit`'s `ManagedTool`: it adds the
/// human-facing display name and a home-relative path, and can produce a
/// `ManagedTool` on demand. The paths follow each tool's documented default
/// location under `~/.config`.
struct ToolDescriptor: Identifiable, Sendable {
    /// Matches `adapter.toolName` and the per-tool settings key.
    let id: String
    let displayName: String
    let adapter: any ThemeAdapter
    /// Config path relative to the user's home directory.
    let relativePath: String
    /// Reload command as `[executable, args…]`, or `nil` if none.
    let reloadCommand: [String]?

    var configURL: URL {
        URL(fileURLWithPath: NSHomeDirectory()).appending(path: relativePath)
    }

    /// The path with `~` for display, e.g. `~/.config/ghostty/config`.
    var displayPath: String { "~/\(relativePath)" }

    func managedTool() -> ManagedTool {
        ManagedTool(adapter: adapter, url: configURL, reloadCommand: reloadCommand)
    }
}

/// The v1 tool roster (PLAN.md §"v1 tool scope"). Adding a tool later is one
/// entry here plus its adapter — nothing else in the app moves.
enum ToolRegistry {
    static let all: [ToolDescriptor] = [
        ToolDescriptor(
            id: "ghostty", displayName: "Ghostty", adapter: GhosttyAdapter(),
            relativePath: ".config/ghostty/config",
            // Ghostty runs one shared instance and only reloads on the
            // reload_config keybind or SIGUSR2 (Ghostty 1.2+). There's no
            // reload CLI subcommand. `-x` matches the process name exactly so
            // we signal only Ghostty — and it MUST be USR2: any other signal
            // crashes Ghostty.
            reloadCommand: ["pkill", "-USR2", "-x", "ghostty"]
        ),
        ToolDescriptor(
            id: "starship", displayName: "Starship", adapter: StarshipAdapter(),
            relativePath: ".config/starship.toml", reloadCommand: nil
        ),
        ToolDescriptor(
            id: "zellij", displayName: "Zellij", adapter: ZellijAdapter(),
            relativePath: ".config/zellij/config.kdl", reloadCommand: nil
        ),
        ToolDescriptor(
            id: "bat", displayName: "bat", adapter: BatThemeAdapter(),
            // Chroma generates a .tmTheme from the palette for EVERY theme (no
            // dependence on bat's built-ins); `bat cache --build` picks it up.
            relativePath: ".config/bat/themes/Chroma.tmTheme",
            reloadCommand: ["bat", "cache", "--build"]
        ),
        ToolDescriptor(
            id: "bat-env", displayName: "bat (BAT_THEME)", adapter: BatAdapter(),
            // One-time constant `export BAT_THEME="Chroma"`, sourced from .zshrc.
            relativePath: ".config/chroma/theme.zsh", reloadCommand: nil
        ),
        ToolDescriptor(
            id: "sketchybar", displayName: "SketchyBar", adapter: SketchyBarAdapter(),
            // Chroma owns THIS file, not the user's hand-authored colors.sh. The
            // user sources it and maps CHROMA_* onto their own names — so a
            // re-theme never touches their $FONT or derived tokens.
            relativePath: ".config/sketchybar/chroma-palette.sh",
            reloadCommand: ["sketchybar", "--reload"]
        ),
        ToolDescriptor(
            id: "spicetify", displayName: "Spicetify", adapter: SpicetifyAdapter(),
            // Chroma owns this generated theme; `spicetify apply` re-patches Spotify.
            relativePath: ".config/spicetify/Themes/Chroma/color.ini",
            reloadCommand: ["spicetify", "apply"]
        ),
    ]
}
