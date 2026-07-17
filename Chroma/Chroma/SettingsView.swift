//
//  SettingsView.swift
//  Chroma
//

import SwiftUI
import AppKit
import ThemeKit

/// Settings: which tools Chroma manages, and the post-apply hooks. Edits the
/// shared `ChromaSettings`, which persists each change to `UserDefaults`.
struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var settings = model.settings

        Form {
            Section("Menu Bar") {
                Toggle("Show menu bar icon", isOn: Binding(
                    get: { settings.showMenuBarIcon },
                    set: { on in
                        settings.showMenuBarIcon = on
                        // Reflect the mode immediately: drop/restore the Dock
                        // icon without waiting for a relaunch.
                        NSApp.setActivationPolicy(on ? .accessory : .regular)
                        // Launch-at-login only makes sense with the icon; clear
                        // it when the icon goes away.
                        if !on { try? LoginItem.setEnabled(false) }
                    }
                ))
                Toggle("Launch at login", isOn: Binding(
                    get: { LoginItem.isEnabled },
                    set: { try? LoginItem.setEnabled($0) }
                ))
                .disabled(!settings.showMenuBarIcon)

                Text("With the icon on, Chroma runs in the menu bar with no Dock icon and starts quietly at login — no window until you open one.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Managed Tools") {
                ForEach(ToolRegistry.all) { tool in
                    Toggle(isOn: Binding(
                        get: { settings.isEnabled(tool.id) },
                        set: { settings.setEnabled($0, for: tool.id) }
                    )) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(tool.displayName)
                            Text(tool.displayPath)
                                .font(.caption)
                                .monospaced()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Post-Apply Hooks") {
                TextField("Dotfile re-add command", text: $settings.reAddCommand)
                Text("Runs once per changed file. `{}` is replaced with the file’s path. Leave blank to disable.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Run each tool’s reload command", isOn: $settings.runReloadHooks)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 440)
    }
}
