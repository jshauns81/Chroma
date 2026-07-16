//
//  SettingsView.swift
//  Chroma
//

import SwiftUI

/// Settings: which tools Chroma manages, and the post-apply hooks. Edits the
/// shared `ChromaSettings`, which persists each change to `UserDefaults`.
struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var settings = model.settings

        Form {
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
