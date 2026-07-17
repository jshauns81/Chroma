//
//  ToolRegistry.swift
//  Chroma
//

import ThemeKit

/// The app-side name for ThemeKit's canonical `ChromaTool`. The roster itself
/// now lives in ThemeKit (`ChromaTools.all`) so the app and `themectl apply`
/// share one source of truth and can't drift on *which* files they write —
/// which matters when both mutate live dotfiles. `ChromaTool` already carries
/// everything the UI used from the old struct: `id`, `displayName`, `adapter`,
/// `configURL`, `displayPath`, `reloadCommand`, `managedTool()`.
typealias ToolDescriptor = ChromaTool

/// The v1 tool roster, re-exported under the app's historical name.
enum ToolRegistry {
    static let all: [ToolDescriptor] = ChromaTools.all
}
