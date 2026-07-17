//
//  PeekView.swift
//  Chroma
//
//  The full-bleed Peek overlay: the selected theme's terminal stack at full
//  size, a translucent top bar of controls, and an optional Compare split that
//  layers the *current* (last-applied) theme over the left half so you can read
//  the switch at a glance. Colors are the selected palette's roles; the split
//  labels and divider use the design system's white/black scrims.
//

import SwiftUI
import ThemeKit

struct PeekView: View {
    @Environment(AppModel.self) private var model

    private var selected: Theme? { model.selectedTheme }
    private var current: Theme? { model.lastAppliedTheme }
    private var palette: Palette { model.chromePalette }

    var body: some View {
        ZStack {
            palette[.crust].color.ignoresSafeArea()

            if let selected {
                previewStack(selected: selected)
            }
        }
        .overlay(alignment: .top) { topBar }
        .overlay(alignment: .bottom) { bottomHint }
        .transaction { $0.animation = nil }  // don't crossfade the terminal body on selection change
    }

    // MARK: Preview + compare split

    @ViewBuilder
    private func previewStack(selected: Theme) -> some View {
        let comparing = model.isComparing && current != nil

        ZStack {
            TerminalPreview(theme: selected, variant: .bare)

            if comparing, let current {
                // The current theme, clipped to the left half, sits on top of
                // the selected theme — a hard 50/50 seam.
                TerminalPreview(theme: current, variant: .bare)
                    .mask(alignment: .leading) {
                        GeometryReader { geo in
                            Rectangle().frame(width: geo.size.width / 2)
                        }
                    }
            }
        }
        .overlay {
            if comparing {
                Rectangle()
                    .fill(.white.opacity(0.4))
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
            }
        }
        .overlay(alignment: .bottomLeading) {
            if comparing, let current {
                cornerLabel("Current — \(current.name)")
                    .padding(16)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if comparing {
                cornerLabel("Selected — \(selected.name)")
                    .padding(16)
            }
        }
    }

    private func cornerLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10))
            .foregroundStyle(.white.opacity(0.65))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: ChromaMetrics.chipRadius, style: .continuous))
    }

    // MARK: Top bar

    private var topBar: some View {
        @Bindable var model = model

        return HStack(spacing: 10) {
            if let selected {
                Text(selected.name)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(palette.bodyText)
                appearanceCapsule(selected.appearance)
                if model.selectedID == model.lastAppliedID {
                    Text("current")
                        .font(.caption)
                        .foregroundStyle(palette[.green].color)
                }
            }

            Spacer(minLength: 12)

            TrustLine()

            Toggle(isOn: $model.isComparing) {
                Label("Compare", systemImage: "rectangle.split.2x1")
            }
            .toggleStyle(.button)
            .buttonStyle(.bordered)
            .tint(palette.accentColor)
            .disabled(current == nil)
            .help(current == nil ? "Apply a theme first to compare" : "Compare current vs selected")

            // Apply lives in the window toolbar, which stays visible over Peek —
            // no second Apply button here.

            Button {
                model.isPeeking = false
            } label: {
                Image(systemName: "xmark.octagon.fill")
                    .font(.title3)
                    .foregroundStyle(palette.secondaryText)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            .help("Close preview")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .background(palette[.mantle].color.opacity(0.76))
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle().fill(palette.separator).frame(height: ChromaMetrics.hairline)
        }
    }

    private func appearanceCapsule(_ appearance: Theme.Appearance) -> some View {
        let dark = appearance == .dark
        return Label(
            dark ? "Dark" : "Light",
            systemImage: dark ? "moon.fill" : "sun.max.fill"
        )
        .font(.caption)
        .foregroundStyle(palette.secondaryText)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(palette[.surface0].color, in: Capsule())
    }

    private var bottomHint: some View {
        Text("Esc to close · ← → to switch themes")
            .font(.system(size: 10))
            .foregroundStyle(.white.opacity(0.45))
            .padding(.bottom, 10)
    }
}
