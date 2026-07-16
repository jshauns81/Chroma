//
//  MenuBarContent.swift
//  Chroma
//

import SwiftUI
import AppKit
import ThemeKit

/// The menu-bar quick-switcher. Uses the default `.menu` style: an inline
/// `Picker` bound to the shared selection gives native checkmarks for free, so
/// switching here updates the main window too.
struct MenuBarContent: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        @Bindable var model = model

        Picker("Theme", selection: $model.selectedID) {
            ForEach(model.themes) { theme in
                Text(theme.name).tag(theme.id as Theme.ID?)
            }
        }
        .pickerStyle(.inline)

        Divider()

        Button("Open Chroma") {
            openWindow(id: ChromaWindow.main)
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        Button("Quit Chroma") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
