//
//  ThemeDetailView.swift
//  Chroma
//

import SwiftUI
import ThemeKit

/// The detail pane: identity + provenance, a live swatch grid, and the
/// per-tool names, with an "Apply…" action that opens the dry-run preview.
struct ThemeDetailView: View {
    let theme: Theme
    @State private var showingPlan = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                accentBar
                SwatchGrid(palette: theme.palette)
                toolNamesSection
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(theme.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingPlan = true
                } label: {
                    Label("Apply…", systemImage: "wand.and.stars")
                }
            }
        }
        .sheet(isPresented: $showingPlan) {
            PlanPreviewView(theme: theme)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Label(theme.appearance.rawValue.capitalized,
                      systemImage: theme.appearance == .dark ? "moon.fill" : "sun.max.fill")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
                Text("\(theme.family.capitalized) · \(theme.variant.capitalized)")
                    .foregroundStyle(.secondary)
            }
            Text("Source: \(theme.source.url.host() ?? theme.source.url.absoluteString) @ \(theme.source.ref) · fetched \(theme.source.fetchedAt.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }

    /// A quick visual identity: the eight accents in a row.
    private var accentBar: some View {
        HStack(spacing: 6) {
            ForEach([ColorRole.red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink], id: \.self) { role in
                RoundedRectangle(cornerRadius: 6)
                    .fill(theme.palette[role].color)
                    .frame(height: 28)
            }
        }
    }

    private var toolNamesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tool Names")
                .font(.headline)
            ForEach(theme.toolNames.sorted(by: { $0.key < $1.key }), id: \.key) { tool, name in
                HStack {
                    Text(tool)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(name)
                        .font(.callout)
                        .monospaced()
                        .textSelection(.enabled)
                }
                .padding(.vertical, 2)
            }
        }
    }
}
