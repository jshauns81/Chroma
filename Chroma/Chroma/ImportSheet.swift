//
//  ImportSheet.swift
//  Chroma
//
//  The two-step Import Theme flow. Step 1 takes a source — a URL to fetch or a
//  dropped/pasted JSON file. Step 2 reviews the mapping: how many of the 17
//  roles came straight from the source vs. resolved by fallback, with a picker
//  to override each fallback before the theme is saved to Application Support.
//
//  Scope note: import reads *Chroma-format* theme or palette JSON (the same
//  shape the bundled themes and `themectl` use). Upstream project formats
//  (Catppuccin's `palette.json`, Nord's `nordN`) are the domain of
//  `themectl sync` + the family mappers, not this sheet.
//

import SwiftUI
import AppKit
import ThemeKit

struct ImportSheet: View {
    @Environment(AppModel.self) private var model
    @Binding var isPresented: Bool

    @State private var draft: ThemeDraft?
    @State private var urlText = ""
    @State private var fetching = false
    @State private var dropTargeted = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            if let draft {
                ImportReviewStep(
                    draft: draft,
                    existingIDs: Set(model.themes.map(\.id)),
                    onBack: { self.draft = nil; errorMessage = nil },
                    onAdd: { add(draft) }
                )
            } else {
                sourceStep
            }
        }
        .padding(24)
        .frame(width: 500)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 26, height: 26)
                .clipShape(RoundedRectangle(cornerRadius: ChromaMetrics.controlRadius, style: .continuous))
            Text("Import Theme")
                .font(.title2.weight(.semibold))
        }
    }

    // MARK: Step 1 — source

    private var sourceStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Paste a palette URL or drop a theme JSON. Chroma maps its colors onto the 17 semantic roles; missing roles resolve through fallbacks you can review.")
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                TextField("https://…/theme.json", text: $urlText)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .padding(8)
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: ChromaMetrics.controlRadius))
                    .onSubmit(fetch)
                Button("Fetch…", action: fetch)
                    .disabled(urlText.trimmingCharacters(in: .whitespaces).isEmpty || fetching)
            }

            dropZone

            if fetching {
                ProgressView().controlSize(.small)
            }
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }

            HStack {
                Spacer()
                Button("Cancel") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
            }
        }
    }

    private var dropZone: some View {
        VStack(spacing: 6) {
            Image(systemName: "arrow.down.doc")
                .font(.title2)
            Text("or drop a theme JSON here")
                .font(.callout)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .overlay {
            RoundedRectangle(cornerRadius: ChromaMetrics.cardRadius, style: .continuous)
                .strokeBorder(
                    dropTargeted ? Color.accentColor : .secondary.opacity(0.5),
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                )
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first, let data = try? Data(contentsOf: url) else {
                errorMessage = "Couldn’t read that file."
                return false
            }
            ingest(data: data, source: fileSource(url))
            return true
        } isTargeted: { dropTargeted = $0 }
    }

    // MARK: Actions

    private func fetch() {
        let trimmed = urlText.trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: trimmed), url.scheme != nil else {
            errorMessage = "Enter a valid URL."
            return
        }
        fetching = true
        errorMessage = nil
        Task {
            do {
                let data = try await URLSessionThemeFetcher().data(from: url)
                ingest(data: data, source: urlSource(url))
            } catch {
                errorMessage = friendly(error)
            }
            fetching = false
        }
    }

    /// Parse fetched/dropped bytes into a reviewable draft, surfacing a friendly
    /// error if it isn't valid Chroma theme/palette JSON or is missing a
    /// required role.
    private func ingest(data: Data, source: Theme.Source?) {
        do {
            let parsed = try ThemeDraft.parse(data: data)
            try Palette(colors: parsed.colors, primaryAccent: parsed.primaryAccent).validate()
            draft = ThemeDraft(colors: parsed.colors,
                               primaryAccent: parsed.primaryAccent,
                               theme: parsed.theme,
                               source: source)
            errorMessage = nil
        } catch let error as Palette.ValidationError {
            if case .missingRequiredRoles(let roles) = error {
                let names = roles.map(\.rawValue).joined(separator: ", ")
                errorMessage = "Missing required role(s): \(names). A theme must define base, text, red, yellow, green, and blue."
            }
        } catch {
            errorMessage = "Couldn’t read a Chroma theme or palette from that data."
        }
    }

    private func add(_ draft: ThemeDraft) {
        do {
            try model.importTheme(draft.buildTheme(avoiding: Set(model.themes.map(\.id))))
            isPresented = false
        } catch {
            errorMessage = "Couldn’t save: \(error.localizedDescription)"
        }
    }

    private func fileSource(_ url: URL) -> Theme.Source {
        Theme.Source(url: url, ref: "file", fetchedAt: Date())
    }

    private func urlSource(_ url: URL) -> Theme.Source {
        Theme.Source(url: url, ref: "fetched", fetchedAt: Date())
    }

    private func friendly(_ error: Error) -> String {
        if let sync = error as? ThemeSyncError {
            switch sync {
            case .httpStatus(_, let code): return "Server returned HTTP \(code)."
            default: return "Fetch failed: \(sync)"
            }
        }
        return "Fetch failed: \(error.localizedDescription)"
    }
}

// MARK: - Step 2 — review

private struct ImportReviewStep: View {
    @Bindable var draft: ThemeDraft
    let existingIDs: Set<String>
    let onBack: () -> Void
    let onAdd: () -> Void

    @State private var showingFallbacks = false

    private var preview: Palette { draft.previewPalette }
    private var definedCount: Int { draft.colors.count }
    private var fallbackRoles: [ColorRole] { preview.fallbackRoles }
    private var fallbackCount: Int { fallbackRoles.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                TextField("Theme name", text: $draft.name)
                    .textFieldStyle(.roundedBorder)
                Picker("Appearance", selection: $draft.appearance) {
                    Text("Light").tag(Theme.Appearance.light)
                    Text("Dark").tag(Theme.Appearance.dark)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }

            accentBar

            Text("Mapped \(definedCount) of 17 roles — \(fallbackCount) resolved by fallback.")
                .font(.callout)
                .foregroundStyle(fallbackCount > 4 ? .orange : .secondary)

            if !fallbackRoles.isEmpty {
                DisclosureGroup("Review Fallbacks", isExpanded: $showingFallbacks) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(fallbackRoles, id: \.self) { role in
                            fallbackRow(role)
                        }
                    }
                    .padding(.top, 6)
                }
            }

            if let provenance = draft.provenanceText {
                Text(provenance)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            if draft.toolNames["zellij"] == nil {
                Label("No built-in Zellij theme found — Zellij will be skipped when applying.",
                      systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            HStack {
                Button("Back", action: onBack)
                Spacer()
                Button("Add Theme", action: onAdd)
                    .buttonStyle(.borderedProminent)
                    .disabled(draft.trimmedName.isEmpty)
            }
        }
    }

    private var accentBar: some View {
        HStack(spacing: 4) {
            ForEach(Array(preview.accentSpectrum.enumerated()), id: \.offset) { _, color in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(color)
                    .frame(height: 14)
            }
        }
    }

    private func fallbackRow(_ role: ColorRole) -> some View {
        let picked = draft.fallbackPicks[role] ?? .text
        let color = draft.colors[picked] ?? HexColor(rgb: 0xFF00FF)
        return HStack(spacing: 8) {
            Text(role.rawValue)
                .font(.system(.caption, design: .monospaced))
                .frame(width: 84, alignment: .leading)
            Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.tertiary)
            Picker("", selection: Binding(
                get: { draft.fallbackPicks[role] ?? picked },
                set: { draft.fallbackPicks[role] = $0 }
            )) {
                ForEach(draft.definedRoles, id: \.self) { source in
                    Text(source.rawValue).tag(source)
                }
            }
            .labelsHidden()
            .frame(width: 120)
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color.color)
                .frame(width: 16, height: 16)
                .overlay {
                    RoundedRectangle(cornerRadius: 3, style: .continuous).strokeBorder(.quaternary)
                }
            Text(color.hexString)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Draft model

/// Mutable working state for an in-progress import — the palette pulled from the
/// source plus the user's editable name, appearance, and per-role fallback
/// choices. `@Observable` so the review step's fields bind directly.
@Observable
final class ThemeDraft {
    var name: String
    var appearance: Theme.Appearance
    /// Only the roles the source defined explicitly.
    let colors: [ColorRole: HexColor]
    var primaryAccent: ColorRole
    let toolNames: [String: String]
    let source: Theme.Source?
    /// For each undefined role, which defined role currently fills it.
    var fallbackPicks: [ColorRole: ColorRole]

    init(colors: [ColorRole: HexColor], primaryAccent: ColorRole, theme: Theme?, source: Theme.Source?) {
        self.colors = colors
        self.primaryAccent = primaryAccent
        self.name = theme?.name ?? "Imported Theme"
        self.appearance = theme?.appearance ?? Self.inferAppearance(from: colors)
        self.toolNames = theme?.toolNames ?? [:]
        self.source = source ?? theme?.source

        let base = Palette(colors: colors, primaryAccent: primaryAccent)
        var picks: [ColorRole: ColorRole] = [:]
        for role in base.fallbackRoles {
            picks[role] = base.resolvedSource(for: role) ?? .text
        }
        self.fallbackPicks = picks
    }

    var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }
    var definedRoles: [ColorRole] { ColorRole.allCases.filter { colors[$0] != nil } }

    /// The palette with every fallback pick baked in as an explicit color.
    var previewPalette: Palette {
        var resolved = colors
        for (role, pick) in fallbackPicks {
            resolved[role] = colors[pick]
        }
        return Palette(colors: resolved, primaryAccent: primaryAccent)
    }

    /// One-line source caption, e.g. `raw.githubusercontent.com @ fetched · 2026-07-16`.
    var provenanceText: String? {
        guard let source else { return "Imported from file" }
        let host = source.url.host() ?? source.url.lastPathComponent
        let date = source.fetchedAt.formatted(date: .abbreviated, time: .omitted)
        return "\(host) @ \(source.ref) · fetched \(date)"
    }

    /// Assemble the final, complete `Theme`, giving it a unique slug id.
    func buildTheme(avoiding existing: Set<String>) -> Theme {
        let palette = previewPalette
        let id = Self.uniqueSlug(from: name, avoiding: existing)
        let source = self.source
            ?? Theme.Source(url: URL(string: "chroma://imported/\(id)")!, ref: "imported", fetchedAt: Date())
        return Theme(
            id: id, name: trimmedName.isEmpty ? "Imported Theme" : trimmedName,
            family: "imported", variant: id,
            appearance: appearance, source: source, palette: palette, toolNames: toolNames
        )
    }

    // MARK: Parsing

    /// Decode either a full Chroma `Theme` JSON or a bare `Palette` JSON.
    static func parse(data: Data) throws -> (colors: [ColorRole: HexColor], primaryAccent: ColorRole, theme: Theme?) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let theme = try? decoder.decode(Theme.self, from: data) {
            return (theme.palette.colors, theme.palette.primaryAccent, theme)
        }
        let palette = try decoder.decode(Palette.self, from: data)
        return (palette.colors, palette.primaryAccent, nil)
    }

    private static func inferAppearance(from colors: [ColorRole: HexColor]) -> Theme.Appearance {
        guard let base = colors[.base] else { return .dark }
        let luminance = 0.299 * base.red + 0.587 * base.green + 0.114 * base.blue
        return luminance > 0.5 ? .light : .dark
    }

    private static func uniqueSlug(from name: String, avoiding existing: Set<String>) -> String {
        let lowered = name.lowercased()
        var slug = String(lowered.map { $0.isLetter || $0.isNumber ? $0 : "-" })
        while slug.contains("--") { slug = slug.replacingOccurrences(of: "--", with: "-") }
        slug = slug.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        if slug.isEmpty { slug = "imported-theme" }

        guard existing.contains(slug) else { return slug }
        var n = 2
        while existing.contains("\(slug)-\(n)") { n += 1 }
        return "\(slug)-\(n)"
    }
}
