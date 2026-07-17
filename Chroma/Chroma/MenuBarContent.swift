//
//  MenuBarContent.swift
//  Chroma
//
//  The menu-bar quick-switcher, upgraded to a `.window`-style popover: a
//  3-column wall of FilmChip thumbnails (each in its own palette) over the
//  same shared selection the main window uses, so switching here re-themes the
//  gallery too — and clicking a chip applies the palette live on the terminal.
//

import SwiftUI
import AppKit
import ThemeKit

struct MenuBarContent: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(model.themes) { theme in
                        FilmChip(theme: theme)
                    }
                }
                .padding(12)
            }
            // A ScrollView has no intrinsic height. Inside the menu-bar
            // `.window` popover — which sizes itself to its content — that made
            // the grid collapse to zero (the "dropdown never shows themes" bug
            // that's been here from the start). A fixed height gives it room to
            // lay the chips out and scroll.
            .frame(height: 360)

            Divider()

            VStack(spacing: 0) {
                menuRow("Open Chroma", systemImage: "macwindow") {
                    openWindow(id: ChromaWindow.main)
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
                menuRow("Quit Chroma", systemImage: "power") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(6)
        }
        .frame(width: 332)
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
    }

    private func menuRow(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
    }
}

/// An 86×54 thumbnail of one theme, rendered in its own palette: a mantle bar
/// with two tab pills, a row of accent dots, and two "text line" bars — the
/// gallery card distilled to a chip. Selected gets an accent ring; the current
/// theme gets a seal.
private struct FilmChip: View {
    @Environment(AppModel.self) private var model
    let theme: Theme

    private var palette: Palette { theme.palette }
    private var isSelected: Bool { model.selectedID == theme.id }
    private var isCurrent: Bool { model.lastAppliedID == theme.id }

    var body: some View {
        VStack(spacing: 4) {
            thumbnail
            HStack(spacing: 3) {
                Text(theme.name)
                    .font(.caption2)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .lineLimit(1)
                if isCurrent {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.green)
                }
            }
            .foregroundStyle(.primary)
        }
        .contentShape(Rectangle())
        // The menu-bar dropdown is a quick-*switcher*, not a browser: a click
        // selects AND applies live (writes configs with .bak backups, runs
        // reload hooks). The current seal moves here on success.
        .onTapGesture {
            model.selectedID = theme.id
            Task { await model.apply(theme) }
        }
        .help("Apply \(theme.name)")
    }

    private var thumbnail: some View {
        VStack(spacing: 0) {
            // Top bar with two tab pills.
            HStack(spacing: 3) {
                pill(palette.accent.color)
                pill(palette[.surface0].color)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
            .frame(maxWidth: .infinity)
            .background(palette[.mantle].color)

            // Body: accent dots + two text-line bars.
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 2) {
                    ForEach(Array(palette.accentSpectrum.enumerated()), id: \.offset) { _, color in
                        Circle().fill(color).frame(width: 4, height: 4)
                    }
                }
                textBar(width: 46)
                textBar(width: 32)
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 86, height: 54)
        .background(palette[.base].color)
        .clipShape(RoundedRectangle(cornerRadius: ChromaMetrics.filmChipRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: ChromaMetrics.filmChipRadius, style: .continuous)
                .strokeBorder(
                    isSelected ? palette.accentColor : palette.separator,
                    lineWidth: isSelected ? ChromaMetrics.selectionRing : ChromaMetrics.hairline
                )
        }
    }

    private func pill(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(color)
            .frame(width: 16, height: 5)
    }

    private func textBar(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
            .fill(palette[.overlay].color)
            .frame(width: width, height: 3)
    }
}
