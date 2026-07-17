//
//  GalleryView.swift
//  Chroma
//
//  The V2 main window: a browse-first theme gallery whose chrome re-themes live
//  from the selected palette. Replaces the old sidebar/detail `ContentView`.
//  Column layout: toolbar / scrolling grid of ThemeCards / footer with the
//  persistent trust line. Selection lives in `AppModel`, so the menu-bar extra
//  and this window stay in sync — and selecting instantly re-themes everything.
//

import SwiftUI
import AppKit
import ThemeKit

struct GalleryView: View {
    @Environment(AppModel.self) private var model

    @FocusState private var keyboardFocused: Bool

    private var palette: Palette { model.chromePalette }

    /// Light/dark for the window chrome, following the selection. System toolbar
    /// controls (the segmented filter, the bordered Import button) take their
    /// ink from the window's appearance, not our palette — so this is what makes
    /// them flip to dark text when a light theme is selected.
    private var chromeColorScheme: ColorScheme {
        (model.selectedTheme?.appearance ?? .dark) == .light ? .light : .dark
    }

    var body: some View {
        @Bindable var model = model

        return ZStack {
            if let error = model.loadError {
                loadFailure(error)
            } else {
                VStack(spacing: 0) {
                    grid
                    GalleryFooter()
                }
            }

            if model.isPeeking {
                PeekView()
                    .transition(.opacity)
                    .zIndex(1)
            }

            if !model.didShowSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
        .frame(minWidth: 960, minHeight: 640)
        .background(palette.windowBackground)
        // Real unified toolbar: AppKit owns the header strip and centers the
        // traffic lights for us. Paint its background from the live palette so
        // the bar re-themes with the selection like the rest of the chrome.
        .toolbar { toolbarContent }
        .toolbarBackground(palette.chromeBackground, for: .windowToolbar)
        .toolbarBackground(.visible, for: .windowToolbar)
        // Flip the whole window (and its system toolbar controls) light/dark to
        // match the selected theme, so system-drawn text stays legible.
        .preferredColorScheme(chromeColorScheme)
        .environment(\.chromaPalette, palette)
        .animation(.easeInOut(duration: 0.18), value: model.selectedID)
        .animation(.easeInOut(duration: 0.2), value: model.isPeeking)
        // Window-wide keyboard nav. `.onKeyPress` fires only while this view
        // holds focus, so typing in a sheet/field is never hijacked.
        .focusable()
        .focusEffectDisabled()
        .focused($keyboardFocused)
        .onKeyPress(.leftArrow) { model.selectDelta(-1); return .handled }
        .onKeyPress(.rightArrow) { model.selectDelta(1); return .handled }
        .onKeyPress(.space) { model.isPeeking.toggle(); return .handled }
        .onKeyPress(.escape) {
            guard model.isPeeking else { return .ignored }
            model.isPeeking = false
            return .handled
        }
        .onAppear {
            keyboardFocused = true
            model.schedulePlanRefresh()
        }
        .onChange(of: model.selectedID) { model.schedulePlanRefresh() }
        // Re-assert focus when a sheet dismisses so arrow-key nav resumes.
        .onChange(of: model.showingImport) { if !model.showingImport { keyboardFocused = true } }
        .onChange(of: model.showingPlan) { if !model.showingPlan { keyboardFocused = true } }
        .sheet(isPresented: $model.showingImport) {
            ImportSheet(isPresented: $model.showingImport)
        }
        .sheet(isPresented: $model.showingPlan) {
            if let theme = model.selectedTheme {
                PlanPreviewView(theme: theme)
            }
        }
    }

    // MARK: Grid

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: ChromaMetrics.gridGap) {
                ForEach(model.filteredThemes) { theme in
                    ThemeCard(theme: theme)
                }
                ImportCard { model.showingImport = true }
            }
            .padding(ChromaMetrics.gridPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.windowBackground)
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: ChromaMetrics.gridGap), count: 3)
    }

    private func loadFailure(_ error: String) -> some View {
        ContentUnavailableView(
            "Couldn’t Load Themes",
            systemImage: "exclamationmark.triangle",
            description: Text(error)
        )
    }

    // MARK: Toolbar

    /// Real unified-toolbar content. Living on the window's `NSToolbar` (rather
    /// than in the VStack) is what lets AppKit vertically center the traffic
    /// lights in the header strip — no manual inset, no safe-area override.
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            HStack(spacing: ChromaMetrics.toolbarGap) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: ChromaMetrics.controlRadius, style: .continuous))
                Text("Chroma")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(palette.bodyText)
            }
        }
        .sharedBackgroundVisibility(.hidden)
        ToolbarItem(placement: .principal) {
            filterPicker
                .frame(width: 190)
        }
        // Opt out of macOS 26's shared Liquid Glass background so our own button
        // styling (bordered Import, accent-filled Apply) reads as designed.
        .sharedBackgroundVisibility(.hidden)
        ToolbarItemGroup(placement: .primaryAction) {
            SettingsLink {
                Image(systemName: "slider.horizontal.3")
            }
            .buttonStyle(.plain)
            .foregroundStyle(palette.secondaryText)
            .help("Settings")

            Button("Import…") { model.showingImport = true }
                .buttonStyle(.bordered)

            Button {
                model.showingPlan = true
            } label: {
                // Toolbar labels are icon-only by default; force the text back.
                Label("Apply…", systemImage: "wand.and.stars")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(AccentProminentButtonStyle(palette: palette))
            .disabled(model.selectedTheme == nil)
        }
        .sharedBackgroundVisibility(.hidden)
    }

    private var filterPicker: some View {
        @Bindable var model = model
        return Picker("Filter", selection: Binding(
            get: { FilterOption(model.filter) },
            set: { model.filter = $0.appearance }
        )) {
            ForEach(FilterOption.allCases, id: \.self) { option in
                Text(option.label).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}

/// The three-way appearance filter, bridging the segmented control's concrete
/// selection to `AppModel.filter`'s optional `Appearance` (`nil` = All).
private enum FilterOption: Hashable, CaseIterable {
    case all, light, dark

    init(_ appearance: Theme.Appearance?) {
        switch appearance {
        case .none: self = .all
        case .light: self = .light
        case .dark: self = .dark
        }
    }

    var appearance: Theme.Appearance? {
        switch self {
        case .all: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var label: String {
        switch self {
        case .all: "All"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

// MARK: - Footer

private struct GalleryFooter: View {
    @Environment(AppModel.self) private var model
    @Environment(\.chromaPalette) private var palette

    var body: some View {
        HStack(spacing: 8) {
            Text("\(model.themes.count) themes · Space or double-click to preview")
                .foregroundStyle(palette.tertiaryText)
            Spacer(minLength: 12)
            TrustLine()
        }
        .font(.caption)
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background(palette.chromeBackground)
        .overlay(alignment: .top) {
            Rectangle().fill(palette.separator).frame(height: ChromaMetrics.hairline)
        }
    }
}

// MARK: - Theme card

/// One gallery cell, rendered in ITS OWN theme's palette (not the window's), so
/// the grid reads as a wall of finished themes. Click selects (re-themes the
/// window); double-click selects and opens Peek.
private struct ThemeCard: View {
    @Environment(AppModel.self) private var model
    let theme: Theme

    private var palette: Palette { theme.palette }
    private var isSelected: Bool { model.selectedID == theme.id }
    private var isCurrent: Bool { model.lastAppliedID == theme.id }

    var body: some View {
        VStack(spacing: 0) {
            TerminalPreview(theme: theme, variant: .mini)
                .frame(height: 118)
                .clipped()
            Rectangle().fill(palette.separator).frame(height: ChromaMetrics.hairline)
            bottomRow
        }
        .background(palette.chromeBackground)
        .clipShape(RoundedRectangle(cornerRadius: ChromaMetrics.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: ChromaMetrics.cardRadius, style: .continuous)
                .strokeBorder(palette.separator, lineWidth: ChromaMetrics.hairline)
        }
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: ChromaMetrics.cardRadius, style: .continuous)
                    .strokeBorder(palette.accentColor, lineWidth: ChromaMetrics.selectionRing)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            model.selectedID = theme.id
            model.isPeeking = true
        }
        .onTapGesture {
            model.selectedID = theme.id
        }
    }

    private var bottomRow: some View {
        HStack(spacing: 6) {
            Text(theme.name)
                .font(.callout.weight(.semibold))
                .foregroundStyle(palette.bodyText)
                .lineLimit(1)
            if isCurrent {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(palette[.green].color)
            }
            Spacer(minLength: 4)
            accentDots
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }

    private var accentDots: some View {
        HStack(spacing: 3) {
            ForEach(Array(palette.accentSpectrum.enumerated()), id: \.offset) { _, color in
                Circle().fill(color).frame(width: 7, height: 7)
            }
        }
    }
}

// MARK: - Import card

/// The trailing grid cell: a dashed affordance that opens the Import flow.
private struct ImportCard: View {
    @Environment(\.chromaPalette) private var palette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                Text("Import Theme…")
                    .font(.callout)
            }
            .foregroundStyle(palette.tertiaryText)
            .frame(maxWidth: .infinity, minHeight: 158)
            .contentShape(Rectangle())
            .overlay {
                RoundedRectangle(cornerRadius: ChromaMetrics.cardRadius, style: .continuous)
                    .strokeBorder(
                        palette.tertiaryText.opacity(0.5),
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                    )
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Trust line

/// The persistent plan summary: how many files an Apply would touch, and a
/// warning tail when a tool can't be planned. Reads `AppModel.currentPlan`
/// (debounced) — never `plan(for:)` — so it costs nothing per render. Shared
/// by the gallery footer and the Peek top bar.
struct TrustLine: View {
    @Environment(AppModel.self) private var model
    @Environment(\.chromaPalette) private var palette

    var body: some View {
        text
            .font(.caption)
            .foregroundStyle(palette.tertiaryText)
            .lineLimit(1)
    }

    private var text: Text {
        let plan = model.currentPlan
        let modify = plan.filter { if case .modify = $0.outcome { return true }; return false }.count
        let create = plan.filter { if case .create = $0.outcome { return true }; return false }.count
        let failed = plan.compactMap { plan -> String? in
            if case .failed = plan.outcome { return plan.tool.displayName }
            return nil
        }

        let line = summary(modify: modify, create: create)
        if !failed.isEmpty {
            let names = failed.joined(separator: ", ")
            let warning = Text(" · \(names) can’t plan").foregroundColor(palette[.yellow].color)
            return Text("\(line)\(warning)")
        }
        return line
    }

    /// Base sentence. `.bak` is monospaced per the spec; backups are only
    /// mentioned when something is actually overwritten.
    private func summary(modify: Int, create: Int) -> Text {
        let bak = Text(".bak").font(.system(.caption, design: .monospaced))
        switch (modify, create) {
        case (0, 0):
            return Text("Everything already matches — nothing to apply.")
        case (let m, 0):
            return Text("Will modify \(m) file(s) — backups kept as \(bak)")
        case (0, let c):
            return Text("Will create \(c) file(s)")
        case (let m, let c):
            return Text("Will modify \(m) file(s), create \(c) — backups kept as \(bak)")
        }
    }
}

// MARK: - Shared button style

/// The prominent Apply button: accent fill, darkest-surface ink, semibold —
/// the one control that always carries the theme's accent.
struct AccentProminentButtonStyle: ButtonStyle {
    let palette: Palette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(palette.onAccentText)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                palette.accentColor.opacity(configuration.isPressed ? 0.82 : 1),
                in: RoundedRectangle(cornerRadius: ChromaMetrics.controlRadius, style: .continuous)
            )
            .contentShape(Rectangle())
    }
}

// d

#if DEBUG
/// One card in its own theme's palette — the leaf worth tuning in the canvas.
#Preview("Theme card") {
    if let theme = PreviewData.theme {
        ThemeCard(theme: theme)
            .environment(PreviewData.model)
            .environment(\.chromaPalette, theme.palette)
            .frame(width: 320)
            .padding()
    } else {
        Text("No bundled themes in canvas")
    }
}

// The header is now real NSToolbar content (`GalleryView.toolbarContent`), which
// only renders inside an actual window — there's no view to preview in the
// canvas. Verify the toolbar (and the traffic-light integration) by running the
// app, not here.

/// The footer with its live trust line.
#Preview("Footer") {
    if let theme = PreviewData.theme {
        GalleryFooter()
            .environment(PreviewData.model)
            .environment(\.chromaPalette, theme.palette)
            .frame(width: 900)
    } else {
        Text("No bundled themes in canvas")
    }
}
#endif
