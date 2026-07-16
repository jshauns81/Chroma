# Chroma

A native SwiftUI theme manager for macOS that re-themes an entire terminal stack
at once — by editing each tool's own config files and triggering its reload.
Switch from Catppuccin Macchiato to Nord in one click and watch Ghostty,
Starship, bat, SketchyBar, and Spotify all follow.

**SIP-safe by construction:** no injection, no private APIs, no accessibility
hacks. Chroma only writes well-formed config files and runs each tool's own
reload command — exactly what you'd do by hand, automated and kept consistent.

> Status: pre-1.0, actively developed. The logic layer (`ThemeKit`) is fully
> tested; the app is functional (browse, preview, apply). See [Roadmap](#roadmap).

---

## Why

A terminal rice spans a dozen tools, each with its own config format and its own
name for "blue." Switching themes by hand means editing every file and hoping you
kept them in sync. Chroma treats a theme as a single source of truth and projects
it onto every tool, so the whole system stays cohesive.

The core idea is **semantic color roles**. Every upstream palette — Catppuccin,
Nord, Everforest, whatever — is normalized into one fixed vocabulary:

| Group | Roles |
|-------|-------|
| Backgrounds (darkest → raised) | `crust` · `mantle` · `base` · `surface0` · `surface1` · `surface2` · `overlay` |
| Text | `textMuted` · `text` |
| Accents | `red` · `orange` · `yellow` · `green` · `cyan` · `blue` · `purple` · `pink` |

Adapters and templates reference **roles only**, never hardcoded hexes. Palettes
vary in depth — Nord has one background shade where Catppuccin has four — so every
`Palette` carries **fallback chains** (`surface2 → surface1 → surface0 → mantle → base`,
`cyan → blue`, `orange → yellow`, …). Only `base`, `text`, `red`, `yellow`,
`green`, and `blue` are required; everything else resolves through the chain, so a
shallow palette never leaves a tool half-themed.

## Design principles

- **Semantic roles, never hardcoded hexes.** One template renders Catppuccin,
  Nord, and Tokyo Night alike.
- **Fallback, don't fail.** Shallow palettes resolve every role via fallback
  chains, so adapters never care how deep the source palette was.
- **Respect the real config owner.** Chroma only ever writes files *it* owns
  (generated palette files), or rewrites a *single* well-anchored line in a file
  you own — it never clobbers your hand-authored config, fonts, or keybinds.
- **Hand-editable, diff-readable themes.** Themes are plain JSON with `#rrggbb`
  colors and a `source` pointer back to the canonical upstream, so `themectl
  sync` can refresh them instead of letting hand-copied hexes rot.

---

## Supported themes

11 themes across 8 families, each verified against its canonical upstream:

- **Catppuccin** — Latte, Frappé, Macchiato, Mocha
- **Nord**
- **Tokyo Night** — Storm
- **Everforest** — Dark Hard
- **Gruvbox** — Dark
- **Rosé Pine**
- **Dracula**
- **Kanagawa** — Wave

## Supported tools

| Tool | How Chroma themes it | Reload |
|------|----------------------|--------|
| **Ghostty** | Rewrites the `theme = <name>` line (native themes) | `SIGUSR2` |
| **Starship** | Generates the `[palettes.<name>]` table from roles, then flips the `palette =` line | none |
| **bat** | Generates a `.tmTheme` from roles (`~/.config/bat/themes/Chroma.tmTheme`), exports `BAT_THEME="Chroma"` | `bat cache --build` |
| **SketchyBar** | Generates `chroma-palette.sh` (`CHROMA_*` vars) that your `colors.sh` sources | `sketchybar --reload` |
| **Spicetify** | Generates a `color.ini` scheme (`~/.config/spicetify/Themes/Chroma/`) | `spicetify apply` |
| **Zellij** | Rewrites the `theme "<name>"` line (native themes) | none |

Adding a tool is one small adapter plus a registry entry — nothing else in the
system moves.

---

## Architecture

| Component | Role |
|-----------|------|
| **`ThemeKit`** (local SPM package) | All logic, terminal-testable: color model, theme loading, adapters, apply engine, sync/validate. |
| **`Chroma`** (app target) | UI only: main window + `MenuBarExtra` + Settings. |
| **`themectl`** (CLI) | Headless driver: `list`, `validate`, `sync`. |

Swift 6, strict concurrency, SwiftUI + the Observation framework.

### How applying works

1. **`ThemeAdapter`** — a pure transform `(Theme, current: String?) -> String`.
   No file I/O, so every adapter is string-in/string-out testable. Two shapes:
   - *Edit-a-line* via `ConfigLineEditor` (replace-or-throw; never guesses, never
     appends a duplicate) — Ghostty, Starship, Zellij.
   - *Generate-a-file* via `TemplateRenderer` (`{{role}}` → `#rrggbb`) — SketchyBar,
     bat, Spicetify.
2. **`ApplyEngine`** (an `actor`) orchestrates a theme across every tool:
   - `plan(for:)` is a **read-only dry-run** — it shows exactly what each file
     would become, writing nothing.
   - `apply(_:)` does **atomic writes** (temp-file + rename), backs up any file it
     overwrites to `<name>.bak`, skips no-ops, then runs post-apply hooks:
     an optional `chezmoi re-add` per changed file, and each tool's reload once.

### Safety

- **Backups.** Every overwrite leaves a `<name>.bak`.
- **Atomic writes.** A crash mid-write can never leave a half-written config.
- **chezmoi-aware.** If your dotfiles are managed by [chezmoi](https://chezmoi.io),
  a configurable post-apply hook (`chezmoi re-add {}`) keeps the source of truth
  in sync.
- **Unsandboxed by design.** A tool that edits arbitrary dotfiles and shells out
  to reload hooks cannot run under the App Sandbox — so Chroma ships with it off
  (Hardened Runtime stays on). It remains SIP-safe: no injection, no private APIs.

---

## Requirements

- macOS 26+
- Xcode 26+ (owns the toolchain and SDK; the app builds against the macOS SDK)
- The tools you want to theme, installed via Homebrew

## Building

Everything but the SwiftUI app builds and tests headless.

**ThemeKit (all logic):**

```sh
cd ThemeKit
swift build
swift test        # ~78 tests
```

**The app:**

```sh
xcodebuild -project Chroma/Chroma.xcodeproj -scheme Chroma \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath DerivedData build
```

…or just open `Chroma/Chroma.xcodeproj` in Xcode and run.

## `themectl` — the CLI

```sh
cd ThemeKit

# List bundled themes
swift run themectl list

# Validate every theme JSON (valid / malformed / missing-roles); non-zero exit on failure
swift run themectl validate

# Refresh palette colors from canonical upstreams (identity + tool names preserved)
swift run themectl sync --dry-run
swift run themectl sync nord dracula
```

---

## Per-tool setup

Most tools work the moment you apply. A few need a one-time bit of wiring because
Chroma refuses to overwrite a file you author by hand:

### SketchyBar

Chroma owns `~/.config/sketchybar/chroma-palette.sh` (exports `CHROMA_*` roles).
Source it from your own `colors.sh` and map the names you use:

```sh
source "$HOME/.config/sketchybar/chroma-palette.sh"
export MAUVE=$CHROMA_PURPLE
export TEAL=$CHROMA_CYAN
export PEACH=$CHROMA_ORANGE
# keep your own $FONT and derived tokens (BAR_COLOR, PILL_*, …)
```

### bat

Chroma generates `~/.config/bat/themes/Chroma.tmTheme` and sets `BAT_THEME="Chroma"`
in `~/.config/chroma/theme.zsh`. Source that file once from your shell:

```sh
# in ~/.zshrc
source "$HOME/.config/chroma/theme.zsh"
```

### Spicetify

Point Spicetify at the generated theme once:

```sh
spicetify config current_theme Chroma color_scheme chroma
spicetify backup apply   # only if Spotify isn't already backed up
```

---

## Themes are just JSON

A theme records its identity, a `source` pointer for `sync`, the role→hex palette,
and the name each tool uses:

```json
{
  "id": "nord",
  "name": "Nord",
  "family": "nord",
  "variant": "nord",
  "appearance": "dark",
  "source": { "url": "https://github.com/nordtheme/nord/blob/develop/src/nord.scss", "ref": "develop", "fetchedAt": "2026-07-15T00:00:00Z" },
  "palette": {
    "primaryAccent": "cyan",
    "colors": { "base": "#2e3440", "text": "#eceff4", "red": "#bf616a", "…": "…" }
  },
  "toolNames": { "ghostty": "Nord", "zellij": "nord", "bat": "Nord", "starship": "nord" }
}
```

Drop a new file in `ThemeKit/Sources/ThemeKit/Resources/Themes/`, run
`themectl validate`, and it appears in the app. Colors serialize as `#rrggbb`
so themes stay hand-editable and diff-readable.

---

## Roadmap

- [x] Color model, semantic roles, fallback chains
- [x] Theme loading + all 4 Catppuccin flavors
- [x] Adapter engine (`ConfigLineEditor`, `TemplateRenderer`, `ApplyEngine`)
- [x] `themectl sync` / `validate`
- [x] App UI: browse, dry-run preview, live apply
- [x] Full theme roster (Nord, Tokyo Night, Everforest, Gruvbox, Rosé Pine, Dracula, Kanagawa)
- [x] Generate-from-roles adapters for Starship palettes, bat `.tmTheme`, Spicetify
- [ ] Per-family `sync` mappers so non-Catppuccin themes stay upstream-updatable
- [ ] More tools (delta, btop, fzf, fastfetch, …) behind the adapter seam
- [ ] Theme authoring niceties

## License

MIT — see [`LICENSE`](LICENSE).
