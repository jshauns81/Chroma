//
//  SplashView.swift
//  Chroma
//
//  The first-launch brand moment: the app icon's eight accent bars spring up
//  from the baseline, staggered, then the wordmark fades in and the whole
//  overlay dissolves. Drawn in the last-applied theme's palette so even the
//  splash is themed. Plays once per app session (guarded by `didShowSplash`).
//

import SwiftUI
import ThemeKit

struct SplashView: View {
    @Environment(AppModel.self) private var model

    /// The icon motif: eight bars, accent hues red→pink, these exact heights.
    private static let barHeights: [CGFloat] = [34, 52, 42, 60, 38, 56, 46, 64]

    @State private var barsUp = false
    @State private var titleIn = false
    @State private var overlayOpacity = 1.0

    private var palette: Palette {
        model.lastAppliedTheme?.palette ?? model.chromePalette
    }

    var body: some View {
        ZStack {
            palette[.crust].color.ignoresSafeArea()

            VStack(spacing: 22) {
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(Array(Self.barHeights.enumerated()), id: \.offset) { index, height in
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(accent(index))
                            .frame(width: 11, height: height)
                            .scaleEffect(y: barsUp ? 1 : 0, anchor: .bottom)
                            .opacity(barsUp ? 1 : 0)
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.62)
                                    .delay(Double(index) * 0.07),
                                value: barsUp
                            )
                    }
                }
                .frame(height: 64, alignment: .bottom)

                Text("Chroma")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(palette.bodyText)
                    .opacity(titleIn ? 1 : 0)
            }
        }
        .opacity(overlayOpacity)
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .task { await play() }
    }

    /// The accent hue for bar `index`, red→pink across the spectrum.
    private func accent(_ index: Int) -> Color {
        let spectrum = palette.accentSpectrum
        return spectrum[index % spectrum.count]
    }

    private func play() async {
        barsUp = true
        // Bars finish around 0.07*7 + 0.5 ≈ 1.0s; bring the wordmark in as they settle.
        try? await Task.sleep(for: .seconds(0.9))
        withAnimation(.easeIn(duration: 0.35)) { titleIn = true }
        // Hold briefly, then dissolve (~1.7s in, ~2.1s total).
        try? await Task.sleep(for: .seconds(0.8))
        withAnimation(.easeOut(duration: 0.4)) { overlayOpacity = 0 }
        try? await Task.sleep(for: .seconds(0.4))
        model.didShowSplash = true
    }

    /// Tap-to-skip: dismiss immediately.
    private func finish() {
        model.didShowSplash = true
    }
}
