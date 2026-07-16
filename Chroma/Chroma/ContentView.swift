//
//  ContentView.swift
//  Chroma
//

import SwiftUI
import ThemeKit

/// The main window: a sidebar of themes (grouped light/dark) beside the detail
/// pane. Selection lives in `AppModel`, so the menu-bar extra and this window
/// stay in sync.
struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        NavigationSplitView {
            sidebar(themes: model.themes, selection: $model.selectedID)
                .navigationTitle("Chroma")
                .navigationSplitViewColumnWidth(min: 220, ideal: 240)
        } detail: {
            detail
        }
    }

    private func sidebar(themes: [Theme], selection: Binding<Theme.ID?>) -> some View {
        List(selection: selection) {
            ForEach(Theme.Appearance.allCases, id: \.self) { appearance in
                let group = themes.filter { $0.appearance == appearance }
                if !group.isEmpty {
                    Section(appearance.rawValue.capitalized) {
                        ForEach(group) { theme in
                            ThemeRow(theme: theme)
                                .tag(theme.id)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let error = model.loadError {
            ContentUnavailableView(
                "Couldn’t Load Themes",
                systemImage: "exclamationmark.triangle",
                description: Text(error)
            )
        } else if let theme = model.selectedTheme {
            ThemeDetailView(theme: theme)
        } else {
            ContentUnavailableView(
                "Select a Theme",
                systemImage: "paintpalette",
                description: Text("Pick a theme from the sidebar to preview it.")
            )
        }
    }
}

/// One sidebar row: the theme's leading accent as a chip, its name, and the
/// family · variant beneath.
private struct ThemeRow: View {
    let theme: Theme

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 4)
                .fill(theme.palette.accent.color)
                .frame(width: 16, height: 16)
                .overlay {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(.quaternary, lineWidth: 1)
                }
            VStack(alignment: .leading, spacing: 1) {
                Text(theme.name)
                Text("\(theme.family.capitalized) · \(theme.variant.capitalized)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
