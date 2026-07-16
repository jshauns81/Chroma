//
//  SwatchGrid.swift
//  Chroma
//

import SwiftUI
import ThemeKit

/// A live preview of a palette, grouped by the semantic role families the
/// design principles use (backgrounds / text / accents). Colors are read
/// through the palette subscript, so any role a source palette omits shows the
/// color its fallback chain resolves to — exactly what an adapter would emit.
struct SwatchGrid: View {
    let palette: Palette

    private struct RoleGroup {
        let title: String
        let roles: [ColorRole]
    }

    private static let groups: [RoleGroup] = [
        RoleGroup(title: "Backgrounds",
                  roles: [.crust, .mantle, .base, .surface0, .surface1, .surface2, .overlay]),
        RoleGroup(title: "Text", roles: [.textMuted, .text]),
        RoleGroup(title: "Accents",
                  roles: [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink]),
    ]

    private let columns = [GridItem(.adaptive(minimum: 92), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(Self.groups, id: \.title) { group in
                VStack(alignment: .leading, spacing: 8) {
                    Text(group.title)
                        .font(.headline)
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                        ForEach(group.roles, id: \.self) { role in
                            Swatch(role: role, color: palette[role])
                        }
                    }
                }
            }
        }
    }
}

private struct Swatch: View {
    let role: ColorRole
    let color: HexColor

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            RoundedRectangle(cornerRadius: 8)
                .fill(color.color)
                .frame(height: 44)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.quaternary, lineWidth: 1)
                }
            Text(role.rawValue)
                .font(.caption)
                .fontWeight(.medium)
            Text(color.hexString)
                .font(.caption2)
                .monospaced()
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }
}
