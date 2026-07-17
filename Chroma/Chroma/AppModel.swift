//
//  AppModel.swift
//  Chroma
//

import Foundation
import Observation
import ThemeKit

/// The app's single source of truth: the loaded themes, the current selection,
/// and shared settings. `@MainActor` because it drives the UI; `@Observable`
/// so SwiftUI re-renders when `selectedID` or the theme list changes.
@MainActor
@Observable
final class AppModel {
    /// Bundled themes plus any the user has imported. Mutable so a fresh import
    /// appears in the grid without relaunching.
    private(set) var themes: [Theme]
    /// `nil` only if no themes loaded (a packaging error, surfaced via `loadError`).
    var selectedID: Theme.ID?
    /// Non-nil when the bundled themes failed to load.
    let loadError: String?

    let settings = ChromaSettings()

    /// Progress/result of the most recent real apply, for the preview sheet.
    var applyPhase: ApplyPhase = .idle
    /// The last theme successfully applied this session (drives a "current" hint).
    private(set) var lastAppliedID: Theme.ID?

    // MARK: V2 gallery state

    /// Appearance filter driving the gallery's All/Light/Dark segmented control.
    /// `nil` = All.
    var filter: Theme.Appearance? {
        didSet { if filteredThemes.first(where: { $0.id == selectedID }) == nil {
            selectedID = filteredThemes.first?.id
        } }
    }
    /// Whether the full-bleed Peek overlay is covering the gallery.
    var isPeeking = false
    /// Whether Peek is showing the current-vs-selected compare split.
    var isComparing = false
    /// Brand splash shows once per app session; set true after it plays.
    var didShowSplash = false

    /// Sheet presentation, held on the model so any surface — gallery toolbar,
    /// Peek top bar, menu-bar extra — can raise the same Apply/Import flow.
    var showingPlan = false
    var showingImport = false

    /// A dry-run plan for the current selection, kept fresh (debounced) so the
    /// footer trust line can read counts without `plan(for:)` hitting disk on
    /// every render. Refreshed via `schedulePlanRefresh()`.
    private(set) var currentPlan: [ToolPlan] = []
    private var planRefreshTask: Task<Void, Never>?

    init() {
        do {
            // Bundled roster + any imported themes, merged and sorted — the
            // same library `themectl` sees (`ThemeStore.chromaLibrary()`).
            let store = try ThemeStore.chromaLibrary()
            self.themes = store.themes
            self.selectedID = store.themes.first?.id
            self.loadError = nil
        } catch {
            self.themes = []
            self.selectedID = nil
            self.loadError = String(describing: error)
        }

        // Seed "current" from the on-disk marker (`~/.config/chroma/current`,
        // written on every apply by the app and themectl, id + trailing newline)
        // so the current badge and Peek's Compare are live from launch — not just
        // after applying something this session. Ignore an id we don't recognize.
        if let id = try? String(contentsOf: ChromaPaths.currentThemeState, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines),
           themes.contains(where: { $0.id == id }) {
            self.lastAppliedID = id
        }
    }

    /// Persist an imported theme to Application Support and add it to the live
    /// list, selecting it. Throws only on a write failure.
    func importTheme(_ theme: Theme) throws {
        let dir = ChromaPaths.importedThemesDirectory
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try ThemeStore.encode(theme)
        try data.write(to: dir.appending(path: "\(theme.id).json"), options: .atomic)

        // Reload the whole library so the new theme merges + re-sorts exactly
        // as a fresh launch would.
        themes = (try? ThemeStore.chromaLibrary().themes) ?? themes
        selectedID = theme.id
    }

    var selectedTheme: Theme? {
        guard let selectedID else { return nil }
        return themes.first { $0.id == selectedID }
    }

    /// The last-applied theme, if it's still loaded — drives the "current"
    /// badge, the Compare base layer, and the splash palette.
    var lastAppliedTheme: Theme? {
        guard let lastAppliedID else { return nil }
        return themes.first { $0.id == lastAppliedID }
    }

    /// Themes visible under the current appearance `filter` (All when `nil`).
    var filteredThemes: [Theme] {
        guard let filter else { return themes }
        return themes.filter { $0.appearance == filter }
    }

    /// The palette the app chrome themes itself from: the selection, falling
    /// back to the resident default before anything is selected.
    var chromePalette: Palette { selectedTheme?.palette ?? .chromaFallback }

    /// Move the selection by `delta` through the *filtered* grid, wrapping.
    /// Backs the ← → keyboard navigation in both the gallery and Peek.
    func selectDelta(_ delta: Int) {
        let list = filteredThemes
        guard !list.isEmpty else { return }
        let current = list.firstIndex { $0.id == selectedID } ?? 0
        let next = ((current + delta) % list.count + list.count) % list.count
        selectedID = list[next].id
    }

    /// Recompute `currentPlan` for the selection after a short debounce, so the
    /// trust line stays accurate without reading configs on every keystroke of
    /// arrow-key navigation. Safe to call on every selection change.
    func schedulePlanRefresh() {
        planRefreshTask?.cancel()
        guard let theme = selectedTheme else {
            currentPlan = []
            return
        }
        planRefreshTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled, let self else { return }
            // `plan(for:)` reads small config files; fine on the main actor once
            // debounced. The sleep coalesces rapid selection changes.
            self.currentPlan = self.plan(for: theme)
        }
    }

    var enabledTools: [ToolDescriptor] {
        ToolRegistry.all.filter { settings.isEnabled($0.id) }
    }

    /// A dry-run preview of applying `theme`, computed one tool at a time.
    ///
    /// Deliberately *not* `ApplyEngine.plan`, which is all-or-nothing: here a
    /// single tool that can't be planned (its config unreadable under the App
    /// Sandbox, or missing the anchor line an edit-a-line adapter needs) becomes
    /// a `.failed` row rather than aborting the whole preview. Reads only; this
    /// method never writes.
    func plan(for theme: Theme) -> [ToolPlan] {
        enabledTools.map { tool in
            let current = try? String(contentsOf: tool.configURL, encoding: .utf8)
            do {
                let new = try tool.adapter.render(theme: theme, current: current)
                let outcome: ToolPlan.Outcome
                if let current {
                    outcome = (current == new) ? .noop : .modify(old: current, new: new)
                } else {
                    outcome = .create(new)
                }
                return ToolPlan(tool: tool, outcome: outcome)
            } catch {
                return ToolPlan(tool: tool, outcome: .failed(Self.describe(error)))
            }
        }
    }

    /// Build an `ApplyEngine` from the enabled tools and current settings.
    ///
    /// Reload commands are stripped when the "run reload hooks" toggle is off;
    /// the dotfile re-add hook comes straight from the settings field (`nil`
    /// when blank, which disables it).
    private func makeEngine() -> ApplyEngine {
        let tools = enabledTools.map { descriptor in
            ManagedTool(
                adapter: descriptor.adapter,
                url: descriptor.configURL,
                reloadCommand: settings.runReloadHooks ? descriptor.reloadCommand : nil
            )
        }
        return ApplyEngine(
            tools: tools,
            dotfileReAddCommand: settings.reAddCommandComponents,
            // Record the live theme so `themectl current` and the SketchyBar
            // switcher stay accurate whether the app or the CLI applied.
            currentThemeStateURL: ChromaPaths.currentThemeState
        )
    }

    /// Really apply `theme` to disk via `ApplyEngine` (atomic writes, `.bak`
    /// backups, then re-add + reload hooks). Records the outcome in
    /// `applyPhase`. Never throws — failures land in `.failed` for the UI.
    func apply(_ theme: Theme) async {
        applyPhase = .applying
        do {
            let changes = try await makeEngine().apply(theme)
            lastAppliedID = theme.id
            let changed = changes.filter { !$0.isNoop }
            if changed.isEmpty {
                applyPhase = .succeeded("No changes needed — your configs already match \(theme.name).")
            } else {
                let names = changed.map { $0.url.lastPathComponent }.joined(separator: ", ")
                applyPhase = .succeeded(
                    "Applied \(theme.name): updated \(changed.count) file(s) — \(names). Overwritten files were backed up as <name>.bak."
                )
            }
        } catch {
            applyPhase = .failed(Self.describe(error))
        }
    }

    func resetApplyPhase() { applyPhase = .idle }

    private static func describe(_ error: Error) -> String {
        if let adapterError = error as? AdapterError {
            return String(describing: adapterError)
        }
        return error.localizedDescription
    }
}

/// Progress and result of a real apply, surfaced in the preview sheet.
enum ApplyPhase: Equatable {
    case idle
    case applying
    case succeeded(String)
    case failed(String)
}

/// What applying a theme *would* do to one tool's config — the app-side,
/// per-tool analogue of `ThemeKit`'s `PlannedChange`, plus a `.failed` case for
/// tools that couldn't be planned.
struct ToolPlan: Identifiable {
    let tool: ToolDescriptor
    let outcome: Outcome

    var id: String { tool.id }

    enum Outcome {
        case create(String)
        case modify(old: String, new: String)
        case noop
        case failed(String)
    }

    var newContent: String? {
        switch outcome {
        case .create(let new), .modify(_, let new): return new
        case .noop, .failed: return nil
        }
    }

    var verb: String {
        switch outcome {
        case .create: return "create"
        case .modify: return "modify"
        case .noop: return "unchanged"
        case .failed: return "can’t plan"
        }
    }

    var symbolName: String {
        switch outcome {
        case .create: return "plus.circle.fill"
        case .modify: return "pencil.circle.fill"
        case .noop: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }
}
