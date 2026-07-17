//
//  ChromaApp.swift
//  Chroma
//

import SwiftUI
import AppKit

/// Window identifiers, so the menu-bar extra can reopen the main window.
enum ChromaWindow {
    static let main = "main"
}

/// Bridges AppKit-level run behavior to the `showMenuBarIcon` preference:
///
/// - **Menu-bar mode** (`.accessory`): no Dock icon, no cmd-tab entry; Chroma
///   lives in the menu bar and the app survives closing its window.
/// - **Normal mode** (`.regular`): ordinary Dock app that quits when the last
///   window closes.
///
/// The policy is read straight from `UserDefaults` at launch (before any view,
/// so before any `ChromaSettings` instance) and re-read live at close/reopen.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(ChromaSettings.showsMenuBarIconAtLaunch ? .accessory : .regular)
    }

    /// Normal window apps quit on last-window-close; the menu-bar utility keeps
    /// running (its whole point is to outlive the window). Read live so toggling
    /// the setting takes effect without relaunch.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        !ChromaSettings.showsMenuBarIconAtLaunch
    }

    /// Clicking the app (Dock, Finder, Spotlight) while it's already running
    /// should bring a window back — including from the windowless menu-bar mode.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        true
    }
}

/// The menu-bar mark: a monochrome "barcode" echoing the app icon, drawn as a
/// *template* image so AppKit tints it to match a light or dark menu bar. No
/// asset needed — the shape is the identity.
enum MenuBarGlyph {
    static let image: NSImage = {
        let size = NSSize(width: 18, height: 16)
        let image = NSImage(size: size, flipped: false) { rect in
            // Varying-height bars, echoing Chroma's equalizer/barcode logo.
            let heights: [CGFloat] = [0.55, 0.9, 0.4, 1.0, 0.65, 0.85, 0.5]
            let gap: CGFloat = 1.4
            let barWidth = (rect.width - gap * CGFloat(heights.count - 1)) / CGFloat(heights.count)
            for (i, fraction) in heights.enumerated() {
                let barHeight = rect.height * fraction
                let barRect = NSRect(
                    x: CGFloat(i) * (barWidth + gap),
                    y: (rect.height - barHeight) / 2,
                    width: barWidth,
                    height: barHeight
                )
                NSColor.black.setFill()  // color is ignored for template images
                NSBezierPath(roundedRect: barRect, xRadius: barWidth / 2, yRadius: barWidth / 2).fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }()
}

@main
struct ChromaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    /// One shared model for every scene: the main window, the menu-bar extra,
    /// and Settings all read and edit the same instance.
    @State private var model = AppModel()

    var body: some Scene {
        @Bindable var settings = model.settings

        WindowGroup(id: ChromaWindow.main) {
            GalleryView()
                .environment(model)
        }
        .defaultSize(width: 1200, height: 840)
        // Hidden title + unified toolbar: AppKit owns the header strip and
        // vertically centers the traffic lights in it for us.
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        // In menu-bar mode, launch quietly to the bar — no window. As a normal
        // app, open the gallery at launch like any window app.
        .defaultLaunchBehavior(settings.showMenuBarIcon ? .suppressed : .automatic)

        MenuBarExtra(isInserted: $settings.showMenuBarIcon) {
            MenuBarContent()
                .environment(model)
        } label: {
            Image(nsImage: MenuBarGlyph.image)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(model)
        }
    }
}
