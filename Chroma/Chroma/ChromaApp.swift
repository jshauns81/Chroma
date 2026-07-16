//
//  ChromaApp.swift
//  Chroma
//

import SwiftUI

/// Window identifiers, so the menu-bar extra can reopen the main window.
enum ChromaWindow {
    static let main = "main"
}

@main
struct ChromaApp: App {
    /// One shared model for every scene: the main window, the menu-bar extra,
    /// and Settings all read and edit the same instance.
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup(id: ChromaWindow.main) {
            ContentView()
                .environment(model)
        }

        MenuBarExtra("Chroma", systemImage: "paintpalette") {
            MenuBarContent()
                .environment(model)
        }

        Settings {
            SettingsView()
                .environment(model)
        }
    }
}
