//
//  PreviewData.swift
//  Chroma
//
//  Sample data for Xcode's SwiftUI preview canvas — DEBUG-only, never compiled
//  into a release build. Rather than hand-author fixture palettes, it loads the
//  *real* bundled themes (`Bundle.module` resolves the same way inside the
//  canvas as at runtime), so every preview renders truthful colors.
//

#if DEBUG
import ThemeKit

@MainActor
enum PreviewData {
    /// The bundled roster, loaded once. Empty only if the canvas can't read the
    /// package resources — previews guard on `.first` rather than force-unwrap.
    static let themes: [Theme] = (try? ThemeStore.bundled().themes) ?? []

    /// A representative dark theme for single-view previews.
    static var theme: Theme? { themes.first { $0.appearance == .dark } ?? themes.first }

    /// A fully-loaded model (its `init` reads the real library), for previewing
    /// views that pull selection/plan state from the environment.
    static var model: AppModel { AppModel() }
}
#endif
