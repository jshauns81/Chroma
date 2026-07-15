# Chroma — Plan & Roadmap

A SwiftUI theme manager for macOS that re-themes an entire terminal stack at
once — by editing each tool's native config files. SIP-safe by construction:
no injection, no private APIs, just well-formed config edits and reload hooks.

## Design principles

- **Semantic roles, never hardcoded hexes.** Every upstream palette
  (Catppuccin, Nord, Everforest, Tokyo Night…) is normalized into a fixed
  vocabulary of `ColorRole`s (base/mantle/crust, surface0–2, overlay,
  textMuted/text, 8 accents). Adapters and templates reference roles only.
- **Fallback, don't fail.** Palettes vary in depth — Nord has one background,
  Catppuccin has four. `Palette`'s fallback chains guarantee a usable color
  for every role, so adapters never care how deep the source palette was.
- **Hand-editable, diff-readable theme files.** Colors serialize as `#rrggbb`
  strings. Theme JSON records provenance (`source {url, ref}`) so `themectl
  sync` can refresh from canonical upstreams.
- **Respect the real config owner.** chezmoi manages the actual dotfiles, so
  applying a theme runs a user-configurable post-apply hook
  (`chezmoi re-add {}`) to keep the source of truth in sync.

## Architecture

| Component | Role |
|-----------|------|
| `ThemeKit` (local SPM package) | All logic, terminal-testable: color model, `Theme` loading, adapters, apply engine. |
| `Chroma` (app target) | UI only: main window + `MenuBarExtra` + Settings. |
| `themectl` (CLI) | Headless driver: `list`, `sync`, `validate`. |

Swift 6.2, macOS 26, strict concurrency.

### Adapter design (decided)

- One `ThemeAdapter` protocol; each tool gets a small conforming type.
- Two shared helpers:
  - `ConfigLineEditor` — anchored single-line replacement in an existing
    config; throws if the anchor is missing (never guesses).
  - `TemplateRenderer` — `{{role}}` substitution for whole generated files.
- `ApplyEngine` (actor) orchestrates applying a theme across all adapters.
- Special case: `BAT_THEME` in `.zshrc` overrides bat's config file, so
  Chroma generates `~/.config/chroma/theme.zsh`, sourced from `.zshrc`.

### v1 tool scope

Ghostty, Starship, Zellij, bat, SketchyBar. The full roster (13 tools) is
deferred behind the adapter seam — adding a tool later means adding one
adapter, nothing else moves.

## Milestones

### M0 — Scaffold ✅ *(commit efa4ba4)*
`HexColor` / `ColorRole` / `Palette` with fallback chains, 13 tests green,
`themectl list` stub, `catppuccin-macchiato.json` seeded.

### M1 — Theme loading & Catppuccin flavors ✅
- All 4 Catppuccin JSONs (latte, frappé, mocha, macchiato) bundled.
- `Theme` type (`id`, `name`, `family`, `variant`, `appearance`, `source`,
  `palette`, `toolNames`) with hand-written `Palette` `Codable` so the
  `colors` object decodes by role name (synthesized would want an array).
- `ThemeStore.bundled()` loads `Resources/Themes/` via `Bundle.module`,
  sorts dark-first; real `themectl list`.
- 22 tests green (full-theme decode, ISO-8601 source date, loader finds all
  four, every palette validates, unknown-role rejection).

### M2 — Adapter engine ⬅ next
`ThemeAdapter` protocol, `ConfigLineEditor`, `TemplateRenderer`; Ghostty as
the reference adapter, end to end against a fixture config.

### M3 — Remaining v1 adapters
Starship, Zellij, bat (incl. `theme.zsh` generation), SketchyBar
(`0xAARRGGBB` via `HexColor.argb`).

### M4 — ApplyEngine & safe writes
`ApplyEngine` actor; atomic writes with backup; dry-run diff output;
post-apply hooks (chezmoi re-add, tool reload commands).

### M5 — `themectl sync` & `validate`
- `validate` — structural + required-role checks on theme JSONs.
- `sync` — refresh theme JSONs from their canonical upstream sources.

### M6 — Chroma app UI
Browse/preview themes with live swatches; apply; `MenuBarExtra` quick-switch;
Settings (hooks, per-tool enable/disable).

### M7 — More palettes & polish
Nord, Everforest, Tokyo Night; theme authoring niceties.

## Open decisions (non-blocking)

- Publish workflow: a small `shaunsync` gate script (`--check` scan,
  staged-only `--commit`, gated `--push`, pre-push hook) vs plain git aliases.
