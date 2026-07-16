# Chroma — Project Instructions

SwiftUI theme manager for macOS. Read `PLAN.md` first — it is the source of
truth for design principles, architecture, and milestones. Don't restate it
here; update it there when decisions change.

## Toolchain & conventions

- Swift 6.2, macOS 26, strict concurrency. SwiftUI + Observation framework.
- All logic lives in `ThemeKit` (local SPM package) so it's testable from the
  terminal without Xcode: `swift test` from `ThemeKit/`.
- `Chroma/` is the app target (UI only); build it with
  `xcodebuild -scheme Chroma build` when Xcode-only surfaces are involved.
- SIP-safe by construction — config-file edits and reload hooks only. Never
  propose injection, private APIs, or accessibility hacks.

## Dev workflow (VS Code + headless, decided 2026-07-14)

- **Editor is VS Code**, not Xcode. The Swift extension
  (`swiftlang.swift-vscode`, bundles sourcekit-lsp) gives live errors and
  completion. Claude Code runs in Ghostty or the VS Code extension — same
  `~/.claude`, same agent. Do NOT route work through Xcode's Coding
  Intelligence panel; it's a chat surface, not an agent.
- **Everything builds headless — no Xcode GUI needed.**
  - ThemeKit (all logic): `swift test` / `swift build` in `ThemeKit/`. This is
    the main loop, sub-second, and where ~90% of work happens.
  - The app: `xcodebuild -project Chroma/Chroma.xcodeproj -scheme Chroma
    -destination 'platform=macOS,arch=arm64'`. Note the project lives at
    `Chroma/Chroma.xcodeproj`, and it's a **macOS** app (never iOS).
  - App build output goes to a repo-local, gitignored `./DerivedData/` (via
    `-derivedDataPath DerivedData`), not the global `~/Library/...`.
- **Slash commands / hook** (all macOS-correct, all verified): `/build` (headless
  app build), `/test [pattern]` (`swift test` on ThemeKit, optional `--filter`).
  The `PostToolUse` hook `build-check.sh` routes ThemeKit edits → `swift build`,
  app edits → macOS `xcodebuild`, and feeds errors back for self-correction.
  `.vscode/tasks.json` wires `⌘⇧B` (build) and the test task.
- **Xcode is opened for one thing only: SwiftUI previews** (arriving at M6),
  plus Instruments/debugger if ever needed. Xcode must stay *installed* (it
  owns the toolchain + SDK that VS Code borrows), just not used as the editor.
- Shaun's actual dotfiles are managed by chezmoi — when testing adapters,
  work against fixture configs, never his live dotfiles, until ApplyEngine's
  backup/dry-run path (M4) exists.

## Context

- Shaun is new to macOS/Swift but experienced (avionics/homelab background).
  Explain macOS- and Swift-specific idioms as they come up — the goal is that
  he learns the platform, not just ships the app.
- Machine runs Catppuccin Macchiato today; Chroma exists to make that
  switchable. Semantic color roles everywhere — see PLAN.md.
