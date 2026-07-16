//
//  ChromaSettings.swift
//  Chroma
//

import Foundation
import Observation

/// User-adjustable settings: which tools Chroma manages and how it runs its
/// post-apply hooks.
///
/// An `@Observable` reference type (not a value struct) because it's shared
/// live across the main window, the menu-bar extra, and the Settings scene —
/// they all read and edit the *same* instance. Each property persists itself
/// to `UserDefaults` on change via `didSet`, so settings survive relaunch
/// without an explicit save step.
@MainActor
@Observable
final class ChromaSettings {
    /// Tools the user has switched *off*. Stored as the disabled set (rather
    /// than enabled) so a newly added tool defaults to on without a migration.
    var disabledToolIDs: Set<String> {
        didSet { defaults.set(Array(disabledToolIDs), forKey: Key.disabledTools) }
    }

    /// The dotfile-sync hook run per changed file, `{}` standing in for the
    /// path (e.g. `chezmoi re-add {}`). Empty disables it.
    var reAddCommand: String {
        didSet { defaults.set(reAddCommand, forKey: Key.reAddCommand) }
    }

    /// Whether to run each tool's reload command after its config changes.
    var runReloadHooks: Bool {
        didSet { defaults.set(runReloadHooks, forKey: Key.runReloadHooks) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.disabledToolIDs = Set(defaults.stringArray(forKey: Key.disabledTools) ?? [])
        self.reAddCommand = defaults.string(forKey: Key.reAddCommand) ?? "chezmoi re-add {}"
        self.runReloadHooks = defaults.object(forKey: Key.runReloadHooks) as? Bool ?? true
    }

    func isEnabled(_ toolID: String) -> Bool {
        !disabledToolIDs.contains(toolID)
    }

    func setEnabled(_ enabled: Bool, for toolID: String) {
        if enabled {
            disabledToolIDs.remove(toolID)
        } else {
            disabledToolIDs.insert(toolID)
        }
    }

    /// The re-add command split into `[executable, args…]`, or `nil` when the
    /// field is blank — matching `ApplyEngine`'s `dotfileReAddCommand` shape.
    var reAddCommandComponents: [String]? {
        let parts = reAddCommand.split(separator: " ").map(String.init)
        return parts.isEmpty ? nil : parts
    }

    private enum Key {
        static let disabledTools = "disabledToolIDs"
        static let reAddCommand = "reAddCommand"
        static let runReloadHooks = "runReloadHooks"
    }
}
