//
//  TerminalPreview.swift
//  Chroma
//
//  The hero of the redesign: a mocked-but-truthful render of the themed
//  terminal stack — SketchyBar strip, a Ghostty window, a Zellij tab bar, and a
//  `bat`-paged Rust file — every color of which is a role of the *previewed*
//  theme. Reused three ways: full (Peek-adjacent), bare (full-bleed Peek), and
//  mini (gallery cards). This is the same trick Chroma performs on the real
//  terminal, rendered in SwiftUI so selection re-themes it instantly.
//

import SwiftUI
import ThemeKit

struct TerminalPreview: View {
    let theme: Theme
    var variant: Variant = .full

    enum Variant { case full, bare, mini }

    private var palette: Palette { theme.palette }
    private var m: Metrics { Metrics.for(variant) }

    var body: some View {
        VStack(spacing: 0) {
            sketchyBar
            ghosttyWindow
                .padding(m.desktop)
        }
        .background(palette[.crust].color)
        .clipShape(RoundedRectangle(cornerRadius: m.outerRadius ?? 0, style: .continuous))
        .overlay {
            if let r = m.outerRadius {
                RoundedRectangle(cornerRadius: r, style: .continuous)
                    .strokeBorder(palette[.text].color.opacity(0.10), lineWidth: 1)
            }
        }
    }

    // MARK: SketchyBar strip

    private var sketchyBar: some View {
        HStack(spacing: m.stripFont * 0.7) {
            Image(systemName: "applelogo")
                .foregroundStyle(palette[.text].color)
            spaceChip("1", background: palette.accent.color, text: palette[.crust].color)
            spaceChip("2", background: palette[.surface0].color, text: palette[.textMuted].color)
            spaceChip("3", background: palette[.surface0].color, text: palette[.textMuted].color)
            Text("ghostty").foregroundStyle(palette[.text].color)
            Spacer(minLength: m.stripFont)
            Text(theme.name).foregroundStyle(palette[.textMuted].color)
            Text("9:41 AM").foregroundStyle(palette.accent.color)
        }
        .font(.system(size: m.stripFont, design: .monospaced))
        .lineLimit(1)
        .padding(.horizontal, m.stripFont)
        .padding(.vertical, m.stripFont * 0.6)
        .frame(maxWidth: .infinity)
        .background(palette[.mantle].color)
    }

    private func spaceChip(_ label: String, background: Color, text: Color) -> some View {
        Text(label)
            .foregroundStyle(text)
            .padding(.horizontal, m.stripFont * 0.5)
            .padding(.vertical, m.stripFont * 0.15)
            .background(background, in: RoundedRectangle(cornerRadius: m.stripFont * 0.35, style: .continuous))
    }

    // MARK: Ghostty window

    private var ghosttyWindow: some View {
        VStack(spacing: 0) {
            zellijBar
            terminalBody
        }
        .background(palette[.base].color)
        .clipShape(RoundedRectangle(cornerRadius: m.ghosttyRadius, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: m.bodyFont, x: 0, y: m.bodyFont * 0.4)
    }

    private var zellijBar: some View {
        HStack(spacing: m.stripFont * 0.7) {
            Text("Zellij")
                .fontWeight(.semibold)
                .foregroundStyle(palette[.green].color)
            zellijTab("1 editor", background: palette.accent.color, text: palette[.crust].color)
            zellijTab("2 shell", background: palette[.surface0].color, text: palette[.textMuted].color)
            Spacer(minLength: m.stripFont)
            Text("chroma").foregroundStyle(palette[.textMuted].color)
        }
        .font(.system(size: m.stripFont, design: .monospaced))
        .lineLimit(1)
        .padding(.horizontal, m.stripFont)
        .padding(.vertical, m.stripFont * 0.55)
        .frame(maxWidth: .infinity)
        .background(palette[.mantle].color)
    }

    private func zellijTab(_ label: String, background: Color, text: Color) -> some View {
        Text(label)
            .foregroundStyle(text)
            .padding(.horizontal, m.stripFont * 0.5)
            .padding(.vertical, m.stripFont * 0.15)
            .background(background, in: RoundedRectangle(cornerRadius: m.stripFont * 0.35, style: .continuous))
    }

    // MARK: Terminal body

    private var terminalBody: some View {
        VStack(alignment: .leading, spacing: m.lineGap) {
            promptLine
            command("bat src/palette.rs")
            if m.showFrame {
                frameLine(.top)
                fileHeader
                frameLine(.mid)
            }
            ForEach(Array(Self.codeLines.prefix(m.codeLines).enumerated()), id: \.offset) { index, tokens in
                codeLine(number: index + 1, tokens: tokens)
            }
            if m.showFrame { frameLine(.bottom) }
            if m.showApply {
                command("chroma apply \(theme.id)")
                appliedLine
            }
            if m.showCursor {
                cursorLine
            }
        }
        .font(.system(size: m.bodyFont, design: .monospaced))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(m.bodyPadding)
    }

    // Runs are composed with string interpolation of styled `Text` — `Text +`
    // is deprecated on macOS 26. Literal text in the outer string inherits the
    // outer `.foregroundColor`; interpolated `Text` keeps its own color.

    private var promptLine: Text {
        let path = Text("~/dev/chroma").foregroundColor(palette[.cyan].color)
        let branch = Text("main").foregroundColor(palette[.purple].color)
        return Text("\(path) on \(branch)").foregroundColor(palette[.textMuted].color)
    }

    /// A `❯ <cmd>` shell line: green prompt glyph, command in body text.
    private func command(_ text: String) -> Text {
        let prompt = Text("❯ ").foregroundColor(palette[.green].color)
        return Text("\(prompt)\(text)").foregroundColor(palette[.text].color)
    }

    private var fileHeader: Text {
        let gutter = Text("       │ ").foregroundColor(palette[.overlay].color)
        let label = Text("File: ").foregroundColor(palette[.textMuted].color)
        return Text("\(gutter)\(label)src/palette.rs").foregroundColor(palette[.text].color)
    }

    private enum FrameEdge { case top, mid, bottom }

    /// One rule line of `bat`'s box frame, drawn in the overlay color.
    private func frameLine(_ edge: FrameEdge) -> some View {
        let junction: String
        switch edge {
        case .top: junction = "┬"
        case .mid: junction = "┼"
        case .bottom: junction = "┴"
        }
        return Text("───────\(junction)────────────────────────")
            .foregroundColor(palette[.overlay].color)
            .lineLimit(1)
    }

    /// A numbered source line: muted line number, overlay gutter, colored tokens.
    private func codeLine(number: Int, tokens: [Token]) -> Text {
        let lineNo = Text(String(format: "%4d ", number)).foregroundColor(palette[.textMuted].color)
        let gutter = Text("│ ").foregroundColor(palette[.overlay].color)
        var line = Text("\(lineNo)\(gutter)")
        for token in tokens {
            let run = Text(token.text).foregroundColor(color(for: token.kind))
            line = Text("\(line)\(run)")
        }
        return line
    }

    private var appliedLine: Text {
        let check = Text("✓ ").foregroundColor(palette[.green].color)
        return Text("\(check)Applied \(theme.name): updated 4 file(s) — config, starship.toml, chroma-palette.sh, theme.zsh.")
            .foregroundColor(palette[.textMuted].color)
    }

    private var cursorLine: Text {
        let prompt = Text("❯ ").foregroundColor(palette[.green].color)
        let block = Text("█").foregroundColor(palette.accent.color)
        return Text("\(prompt)\(block)")
    }

    private func color(for kind: Token.Kind) -> Color {
        switch kind {
        case .keyword: return palette[.purple].color
        case .type: return palette[.yellow].color
        case .function: return palette[.blue].color
        case .plain: return palette[.text].color
        }
    }
}

// MARK: - Syntax model

/// A minimal token stream — enough to color a short Rust excerpt the way `bat`
/// would: keywords, type names, function names, and everything else as plain
/// body text. Kept as data so the mini variant can slice the first N lines.
private struct Token {
    enum Kind { case keyword, type, function, plain }
    let text: String
    let kind: Kind

    static func kw(_ t: String) -> Token { .init(text: t, kind: .keyword) }
    static func ty(_ t: String) -> Token { .init(text: t, kind: .type) }
    static func fn(_ t: String) -> Token { .init(text: t, kind: .function) }
    static func p(_ t: String) -> Token { .init(text: t, kind: .plain) }
}

extension TerminalPreview {
    /// `src/palette.rs` — a truthful little slice of what Chroma itself models:
    /// a `Palette` keyed by role. Showcases every syntax color the spec calls
    /// for (keyword purple, type yellow, fn-name blue, punctuation body).
    fileprivate static let codeLines: [[Token]] = [
        [.kw("pub"), .p(" "), .kw("struct"), .p(" "), .ty("Palette"), .p(" {")],
        [.p("    colors"), .p(": "), .ty("HashMap"), .p("<"), .ty("Role"), .p(", "), .ty("Hex"), .p(">,")],
        [.p("}")],
        [.p("")],
        [.kw("pub"), .p(" "), .kw("fn"), .p(" "), .fn("resolve"), .p("("), .p("role"), .p(": "),
         .ty("Role"), .p(") -> "), .ty("Hex"), .p(" {")],
    ]
}

// MARK: - Per-variant metrics

private struct Metrics {
    let bodyFont: CGFloat
    let stripFont: CGFloat
    let showApply: Bool
    let showCursor: Bool
    let showFrame: Bool
    let codeLines: Int
    let desktop: EdgeInsets
    let bodyPadding: CGFloat
    let outerRadius: CGFloat?
    let ghosttyRadius: CGFloat
    var lineGap: CGFloat { bodyFont * 0.55 }

    static func `for`(_ variant: TerminalPreview.Variant) -> Metrics {
        switch variant {
        case .full:
            return Metrics(
                bodyFont: 12, stripFont: 10, showApply: true, showCursor: true, showFrame: true,
                codeLines: 5,
                desktop: EdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18),
                bodyPadding: 12,
                outerRadius: ChromaMetrics.windowRadius, ghosttyRadius: ChromaMetrics.cardRadius
            )
        case .bare:
            return Metrics(
                bodyFont: 13, stripFont: 10.5, showApply: true, showCursor: true, showFrame: true,
                codeLines: 5,
                desktop: EdgeInsets(top: 22, leading: 60, bottom: 34, trailing: 60),
                bodyPadding: 13,
                outerRadius: nil, ghosttyRadius: ChromaMetrics.cardRadius
            )
        case .mini:
            // Trimmed to fit the 118pt card slot without clipping: no trailing
            // cursor line, tight padding. The flexible terminal body then
            // expands to fill the slot instead of overflowing it.
            return Metrics(
                bodyFont: 6.5, stripFont: 5.5, showApply: false, showCursor: false, showFrame: false,
                codeLines: 3,
                desktop: EdgeInsets(top: 5, leading: 6, bottom: 5, trailing: 6),
                bodyPadding: 5,
                outerRadius: nil, ghosttyRadius: ChromaMetrics.controlRadius
            )
        }
    }
}

// MARK: - Previews

#if DEBUG
/// The mini card render, one row per bundled palette — the fastest way to check
/// that a role change reads well across every theme at once.
#Preview("Mini · all themes") {
    ScrollView {
        VStack(spacing: 12) {
            ForEach(PreviewData.themes) { theme in
                TerminalPreview(theme: theme, variant: .mini)
                    .frame(height: 118)
            }
        }
        .padding()
    }
    .frame(width: 360, height: 640)
}

/// The full render for a single theme — the Peek-adjacent variant.
#Preview("Full · one theme") {
    if let theme = PreviewData.theme {
        TerminalPreview(theme: theme, variant: .full)
            .padding()
            .frame(width: 520, height: 360)
    } else {
        Text("No bundled themes in canvas")
    }
}
#endif
