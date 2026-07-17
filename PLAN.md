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

### M2 — Adapter engine ✅
- `ThemeAdapter` is a **pure transform** `(Theme, current: String?) -> String`;
  no file I/O — that lives in M4's `ApplyEngine`, which keeps adapters
  string-in/string-out testable.
- `ConfigLineEditor` — replace-or-throw: never guesses, throws on a missing
  *or* ambiguous anchor. Insert-when-missing is adapter policy, not the
  editor's.
- `TemplateRenderer` — `{{role}}` → `#rrggbb`, resolved through the palette
  fallback chain; unknown role / unclosed `{{` are hard errors.
- `GhosttyAdapter` (reference) rewrites the `theme = <name>` line from
  `toolNames["ghostty"]`, ignoring commented lines. 13 new tests green (35 total).

### M3 — Remaining v1 adapters ✅
All five v1 adapters land in two shapes:
- **Edit-a-line** (`ConfigLineEditor`): `ZellijAdapter` (`theme "…"`, KDL),
  `StarshipAdapter` (`palette = "…"`, TOML; assumes palette tables already
  defined), both twins of `GhosttyAdapter`.
- **Generate-a-file**: `SketchyBarAdapter` renders a **Chroma-owned**
  `chroma-palette.sh` via `TemplateRenderer` — placeholders gained
  `{{role:format}}` (`hex` default, `argb` → `0xAARRGGBB`). Exports are
  `CHROMA_`-namespaced; the user sources the file from their own hand-authored
  `colors.sh` and maps `CHROMA_*` onto their names (keeping `$FONT` + derived
  tokens). Chroma never owns `colors.sh` — see the 2026-07-15 fix note below.
  `BatAdapter` emits a tiny `theme.zsh` exporting `BAT_THEME` (name only, no
  colors).
- 45 tests across 11 suites.

### M4 — ApplyEngine & safe writes ✅
- `ManagedTool` (adapter ⊕ config URL ⊕ optional reload command) and
  `PlannedChange` (create/modify/noop). `ApplyEngine.plan(for:)` is the
  read-only dry-run.
- `ApplyEngine` is an `actor` (mutable `lastAppliedThemeID` + serialized
  writes/hooks earn it). `apply(_:)`: atomic writes (temp-file + rename),
  parent-dir creation, `<name>.bak` backups, no-op skipping — then post-apply
  hooks (chezmoi re-add per changed file with `{}` path substitution; per-tool
  reload once if changed).
- Hooks run through an injected `CommandRunner` protocol (real
  `ProcessCommandRunner` via `/usr/bin/env`; tests inject a recording fake — no
  real shell-outs). 54 tests across 13 suites, temp dirs only.

### M5 — `themectl sync` & `validate` ✅
- `ThemeValidator` — reports each theme JSON as **valid** / **malformed**
  (didn't decode: bad JSON, unknown role, unparseable hex) / **missing roles**
  (decoded but a `requiredRole` is absent). A bad file is a result, not a
  throw, so one broken file doesn't hide its neighbours. `themectl validate
  [--themes-dir]` prints a `✓/✗` line per file and exits non-zero on any fail.
- `sync` refreshes only the palette colors + `source.fetchedAt` from upstream;
  identity, `primaryAccent`, and `toolNames` are Chroma's editorial metadata
  and are preserved. Network is behind an injected `ThemeFetcher` (real
  `URLSessionThemeFetcher`; tests inject a fixture — no network in CI).
  `UpstreamPaletteMapper` per `family` owns the name→role table
  (`CatppuccinMapper`: `peach→orange`, `teal→cyan`, `overlay0→overlay`,
  `subtext0→textMuted`, …); the GitHub *blob* URL is rewritten to *raw* honoring
  `source.ref`. `themectl sync --themes-dir [ids…] [--dry-run]` writes
  key-sorted JSON for stable diffs. Verified end-to-end: syncing the live
  Catppuccin upstream reports all four themes unchanged. 64 tests, 15 suites.

### M6 — Chroma app UI ✅
- One shared `@Observable @MainActor AppModel` across all scenes (main window,
  `MenuBarExtra`, `Settings`), injected via `.environment`. Loads
  `ThemeStore.bundled()`; `selectedID` keeps the menu-bar switcher and window
  in sync.
- **Browse + live swatches**: `NavigationSplitView` — sidebar grouped
  light/dark, detail shows identity/provenance, an accent bar, and a
  role-grouped `SwatchGrid` (backgrounds/text/accents) read through the palette
  subscript so fallbacks render exactly as an adapter would emit them.
- **`ToolRegistry`** — app-side descriptors (display name, `~/.config` path,
  reload cmd) that vend `ThemeKit.ManagedTool`s. **`ChromaSettings`**
  (`@Observable`, `UserDefaults`-backed) drives per-tool enable/disable + the
  `chezmoi re-add {}` hook + reload toggle.
- **Apply → dry-run preview**: `AppModel.plan(for:)` computes a *per-tool*
  plan (not `ApplyEngine.plan`'s all-or-nothing) so one unplannable tool
  (config unreadable under the App Sandbox, or an edit-a-line adapter missing
  its anchor) becomes a `.failed` row instead of aborting. `PlanPreviewView`
  shows create/modify/noop/failed with the generated output.
- **Write path (live):** App Sandbox turned **off** (`ENABLE_APP_SANDBOX = NO`,
  via Xcode build settings — a personal ricing tool that edits arbitrary
  dotfiles and shells out to reload hooks can't be sandboxed; verified the
  built binary carries no `com.apple.security.app-sandbox` entitlement). The
  preview's **Apply** button drives `ApplyEngine.apply` for real:
  `AppModel.makeEngine()` builds `ManagedTool`s from `enabledTools` +
  `ChromaSettings` (reload commands stripped when the toggle is off; re-add
  hook from the settings field), and `apply(_:)` reports success/failure into
  `applyPhase` for the footer banner. All safety is M4's: atomic temp-file +
  rename, `<name>.bak` backups, chezmoi re-add, no-op skip. `~/.config` backed
  up to `~/.config.bak` before first live use.

### Fix — SketchyBar adapter clobber *(2026-07-15)*
First live apply overwrote the user's hand-authored `colors.sh` wholesale,
dropping `$FONT`, derived tokens (`BAR_COLOR`/`PILL_*`/`HOVER_BORDER`/
`POPUP_COLOR`) and upstream names, and the `chezmoi re-add` hook then poisoned
the dotfiles source. Fix: `SketchyBarAdapter` now owns a **separate**
`chroma-palette.sh` exporting `CHROMA_`-namespaced roles (mirrors `BatAdapter`'s
"own a generated file, never the user's" pattern); `ToolRegistry` path updated;
regression test asserts every export is `CHROMA_`-prefixed. **One-time user
step:** edit `colors.sh` to `source chroma-palette.sh` and map the names.

### Fix — reload/chezmoi hooks silently failed from the GUI app *(2026-07-15)*
`ProcessCommandRunner` ran hooks via `/usr/bin/env <tool>`, relying on `PATH`.
But a GUI app launched by Finder/launchd inherits a *minimal* `PATH`
(`/usr/bin:/bin:/usr/sbin:/sbin`) with no Homebrew — so `sketchybar --reload`
and `chezmoi re-add` died with "No such file or directory" while `pkill`
(Ghostty's reload, a system binary) worked. Net effect: files wrote correctly
and Ghostty reloaded, but SketchyBar never visibly changed. Fix:
`ProcessCommandRunner.augmentedPATH(_:)` prepends `/opt/homebrew/{bin,sbin}`,
`/usr/local/{bin,sbin}`, `~/.local/bin` to the child's `PATH` (de-duped). 3
unit tests. **Requires an app rebuild to take effect** (the running binary
predates the fix).

### M7 — Full theme roster *(in progress 2026-07-15)*
Added 7 families (11 themes total) from canonical upstreams, each hex verified
against source: **Nord**, **Tokyo Night Storm**, **Everforest Dark Hard**,
**Gruvbox Dark**, **Rosé Pine**, **Dracula**, **Kanagawa Wave**. All validate
(`themectl validate`). Per-tool coverage (ground-truthed against installed
tools):
- **Ghostty** — all 7 native (verified via `ghostty +list-themes`).
- **SketchyBar** — all 7 (Chroma generates `chroma-palette.sh`).
- **Starship** — all 7: `StarshipAdapter` now **generates the
  `[palettes.<name>]` table** (Catppuccin-keyed, mapped from roles) and appends
  it if absent, so any theme drives the existing prompt with zero module edits.
  Idempotent. 70 tests.
- **bat** — all 7 (all 11): `BatThemeAdapter` **generates a `Chroma.tmTheme`
  from roles** for every theme (no dependence on bat's built-ins), `BatAdapter`
  exports the constant `BAT_THEME="Chroma"`, and `bat cache --build` is the
  reload hook. Verified end-to-end: `plutil -lint` OK, `bat cache --build`
  accepts it, `bat --list-themes` shows `Chroma`. Two `ToolRegistry` entries
  (`bat` = the .tmTheme, `bat-env` = theme.zsh). 72 tests.
- **Zellij** — names set where a built-in exists; Rosé Pine has none. Moot for
  now (Zellij uninstalled, removed from the rice 2026-07).

**Remaining M7:** `themectl sync` mappers per new family (Nord/TokyoNight/… so
non-Catppuccin JSONs stay upstream-updatable like Catppuccin does — the JSONs
are hand-verified against canonical sources for now). One-time user setup for
bat: `.zshrc` must source `~/.config/chroma/theme.zsh` (already migrated) — the
`Chroma.tmTheme` dir is auto-created by ApplyEngine.

### M8 — V2 redesign: gallery + stage hybrid *(2026-07-16)*
Rebuilt the app UI from the `design_handoff_v2_redesign` package (sidebar/detail
→ browse-first gallery whose chrome re-themes live from the selection). New files
alongside the old (`ContentView`/`ThemeDetailView`/`SwatchGrid` kept but no longer
wired — safe to delete once eyeballed). All logic reuses existing `Theme`/
`Palette`/`ColorRole`/`AppModel`/`ToolPlan`; the only ThemeKit change is
additive.
- **Foundation** (`DesignSystem.swift`): `EnvironmentValues.chromaPalette` +
  semantic token accessors on `Palette` (window/chrome/track/raised/body/
  secondary/tertiary/separator/accent) + `ChromaMetrics`. Chrome themes itself by
  a single env write; cards/chips override with their own palette.
- **`TerminalPreview`** (hero): mocked-but-truthful SketchyBar + Ghostty + Zellij
  + `bat src/palette.rs` stack, every color a role of the previewed theme. Three
  variants — full, bare (Peek), mini (cards, first 3 code lines).
- **Gallery** (`GalleryView`): toolbar (icon/title, All/Light/Dark filter, gear
  via `SettingsLink`, Import, prominent Apply) / `LazyVGrid` of `ThemeCard`s +
  dashed Import card / footer with the debounced **trust line**. ← → / Space /
  Esc keyboard nav.
- **Peek + Compare** (`PeekView`): full-bleed bare preview, translucent top bar,
  half/half current-vs-selected split with divider + corner labels.
- **Import** (`ImportSheet` + persistence): two-step URL-fetch/JSON-drop →
  fallback-review flow. Reads **Chroma-format** theme/palette JSON (upstream
  formats stay `themectl sync`'s job). Persists to
  `~/Library/Application Support/Chroma/Themes`; `AppModel` merges imported +
  bundled at launch. ThemeKit add: `Palette.resolvedSource(for:)` /
  `definedRoles` / `fallbackRoles`.
- **Menu bar** (`MenuBarContent`): `.menuBarExtraStyle(.window)` popover, 3-col
  `FilmChip` grid over the shared selection.
- **Splash** (`SplashView`) + the approved "Accent Bar" **AppIcon** dropped into
  the asset catalog. Once per session, last-applied palette.

Status: builds headless (`xcodebuild` green), 78 ThemeKit tests pass, app
launches without crash. **Not yet visually verified** — screen capture is
TCC-blocked from the headless/terminal context; needs an eyeball pass in Xcode
previews or a manual run.

### `themectl apply` + SketchyBar switcher *(2026-07-16)*
Added a headless apply path so the terminal itself can switch themes:
- **ThemeKit**: the tool roster is now canonical in `ChromaTool`/`ChromaTools.all`
  (the app's `ToolDescriptor` is a typealias over it — one source of truth, no
  app/CLI drift). `ChromaPaths` centralises `~/.config/chroma/current`, the
  imported-themes dir, and the config dir. `ThemeStore.chromaLibrary()` merges
  bundled + imported (app and CLI now list/apply the same set). `ApplyEngine`
  gained an opt-in `currentThemeStateURL` — every apply (app **or** CLI) records
  the live theme id.
- **themectl**: `apply <id> [--no-reload] [--rebind] [--dry-run]` (reuses
  `ApplyEngine`; `--rebind` opt-in for chezmoi re-add, off by default per the
  2026-07-15 incident) and `current`. `list --porcelain` emits
  `id⇥name⇥appearance⇥#accent` for scripts. Installed to `~/.local/bin/themectl`
  (+ its `ThemeKit_ThemeKit.bundle` beside it — SPM resource bundle).
- **SketchyBar**: `plugins/chroma.sh` + a `chroma` paintbrush item in
  `sketchybarrc` (backed up as `*.chroma.bak`), added to `POPUP_ITEMS` in
  `lib.sh`. The pill shows the active theme, tinted its accent; the popup lists
  every theme (accent dot + name, ✓ on the live one); a row's click runs
  `themectl apply`, which re-themes the whole stack incl. the bar. Verified live
  (apply nord no-op moved the ✓ correctly).
- **Note**: the SketchyBar files are chezmoi-managed — reconcile the source
  (`chezmoi re-add` / edit source) when settled. CLI currently applies with all
  tools + reload on (no per-tool toggles like the app's Settings — a follow-up).
- **Fixes (same day, after first live test)**: three bugs surfaced switching
  themes from the bar, all fixed:
  1. *Checkmark race* — `ApplyEngine` wrote the current-theme marker *after*
     running reloads, so `sketchybar --reload` read it before it updated and the
     ✓/label lagged a switch. Now the marker is written **before** reloads
     (affects app + CLI).
  2. *Rosé Pine (and any theme without a Zellij built-in) aborted the whole
     apply* — `themectl apply` now **skips tools that can't render** the theme
     (reports them on stderr) instead of failing, matching the app's per-tool
     leniency. Zellij is uninstalled anyway.
  3. *Flaky dropdown* — `popup.drawing=toggle` desynced against the click-away
     watcher. `chroma.sh` now opens **deterministically** (`=on`) and no longer
     shells out per event; the pill's label/accent are set at build time.

### M9 — UI polish: unified toolbar, menu-bar agent, live dropdown switcher *(2026-07-16)*

Interactive polish pass on the M8 gallery (all uncommitted):

- **Unified title bar** (`ChromaApp` + `GalleryView`): the fake in-VStack header
  became a **real `NSToolbar`**. `.windowStyle(.hiddenTitleBar)` +
  `.windowToolbarStyle(.unified(showsTitle: false))` + `.toolbar { toolbarContent }`
  (placements `.navigation` logo / `.principal` filter / `.primaryAction`
  buttons). AppKit now owns the strip and centers the traffic lights — dropped
  the earlier manual `trafficLightInset` + `.ignoresSafeArea(.top)` hack (both
  removed). Bar background themed live via
  `.toolbarBackground(palette.chromeBackground, for: .windowToolbar)`.
- **macOS 26 Liquid Glass opt-out**: a real toolbar wraps its items in the
  system's shared glass on Tahoe. Suppressed per group with Apple's sanctioned
  `.sharedBackgroundVisibility(.hidden)` so the custom bordered-Import /
  accent-Apply styling reads as designed; toolbar `Label`s go icon-only by
  default, so Apply forces text back with `.labelStyle(.titleAndIcon)`.
- **Chrome appearance follows the selection**: `.preferredColorScheme` driven by
  the selected theme's `appearance`. System toolbar controls (segmented filter,
  bordered Import) take their ink from the window's `NSAppearance`, not the
  palette — this flips them to dark text on light themes. *Palette carries
  color; colorScheme carries appearance — two separate axes.*
- **Peek** (`PeekView`): removed the redundant Apply (the toolbar's Apply stays
  visible over the Peek overlay). **Compare fixed** — it was permanently
  disabled because `lastAppliedTheme` was nil until an in-session apply.
  `AppModel.init` now **seeds `lastAppliedID` from `~/.config/chroma/current`**
  (trimmed, guarded against unknown ids), so Compare *and* the "current" badges
  are live from launch and agree with the SketchyBar switcher's marker.
- **Menu-bar dropdown is now a real switcher** (`MenuBarContent`): a `FilmChip`
  click **applies live** (was select-only). Fixed the "grid never rendered from
  the start" bug — a `ScrollView` has no intrinsic height, so inside the
  self-sizing `.window` popover it collapsed to zero; `.frame(height: 360)` gives
  it room. Menu-bar icon is a monochrome **template `MenuBarGlyph`** (bars drawn
  into an `NSImage`, `isTemplate`), auto-tinting for light/dark bars.
- **Menu-bar agent, opt-in** (the big one): Chroma is a normal window app by
  default and *becomes* a menu-bar utility via Settings.
  - `ChromaSettings.showMenuBarIcon` (default **off**) + a `nonisolated static
    showsMenuBarIconAtLaunch` the `AppDelegate` reads before any view exists.
  - `AppDelegate`: activation policy `.accessory` (no Dock icon / no cmd-tab)
    when the icon is on, else `.regular`; `applicationShouldTerminateAfterLast
    WindowClosed` = *normal app quits on close, utility persists*; reopen returns
    true.
  - `MenuBarExtra(isInserted: $settings.showMenuBarIcon)` shows/hides live;
    `.defaultLaunchBehavior(showMenuBarIcon ? .suppressed : .automatic)` — quiet
    launch to the bar vs normal window-at-launch.
  - **Launch at login** via `SMAppService.mainApp` (`LoginItem` wrapper) —
    modern, SIP-safe, no helper bundle. Settings "Menu Bar" section: two toggles,
    launch-at-login **gated** on the icon + live activation-policy switch.
  - *Caveat:* `SMAppService` only registers a signed app the system can find by
    bundle id — works from `/Applications`, no-ops from `DerivedData`. Test login
    behavior against an installed copy.
- **Xcode previews**: added `PreviewData` (DEBUG-only, loads the real bundled
  themes) + `#Preview`s on the leaf views (`ThemeCard`, `GalleryFooter`,
  `TerminalPreview`). Window chrome (title bar, toolbar) can't be previewed — the
  canvas hosts a *view*, not the `App` scene, so `.windowStyle`/`.toolbar` never
  run there.

**M9 follow-ups (offered, not done):** (a) mirror the native switcher in the
**SketchyBar** dropdown (separate shell + `themectl` popup, next); (b) reopen
from Finder in agent mode may not pop a window (SwiftUI + `.suppressed` is
inconsistent — a window-bridge would harden it); (c) menu-bar apply failures are
**silent** (success shows via the seal; a `.failed` has nowhere to surface — a
dropdown status footer would fix it); (d) `MenuBarGlyph` is a generic bars mark —
could refine toward the true Chroma logo.

## Open decisions (non-blocking)

- Publish workflow: a small `shaunsync` gate script (`--check` scan,
  staged-only `--commit`, gated `--push`, pre-push hook) vs plain git aliases.
