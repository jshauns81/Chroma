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
    let themes: [Theme]
    /// `nil` only if no themes loaded (a packaging error, surfaced via `loadError`).
    var selectedID: Theme.ID?
    /// Non-nil when the bundled themes failed to load.
    let loadError: String?

    let settings = ChromaSettings()

    /// Progress/result of the most recent real apply, for the preview sheet.
    var applyPhase: ApplyPhase = .idle
    /// The last theme successfully applied this session (drives a "current" hint).
    private(set) var lastAppliedID: Theme.ID?

    init() {
        do {
            let store = try ThemeStore.bundled()
            self.themes = store.themes
            self.selectedID = store.themes.first?.id
            self.loadError = nil
        } catch {
            self.themes = []
            self.selectedID = nil
            self.loadError = String(describing: error)
        }
    }

    var selectedTheme: Theme? {
        guard let selectedID else { return nil }
        return themes.first { $0.id == selectedID }
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
        return ApplyEngine(tools: tools, dotfileReAddCommand: settings.reAddCommandComponents)
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
