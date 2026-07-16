//
//  PlanPreviewView.swift
//  Chroma
//

import SwiftUI
import ThemeKit

/// A preview of applying a theme — one expandable row per managed tool showing
/// what will change — with an Apply button that writes for real via
/// `ApplyEngine` (atomic, with `.bak` backups). The plan is recomputed after a
/// successful apply, so the rows settle to "unchanged".
struct PlanPreviewView: View {
    let theme: Theme
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var plans: [ToolPlan] = []

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(minWidth: 580, minHeight: 520)
        .onAppear {
            model.resetApplyPhase()
            plans = model.plan(for: theme)
        }
    }

    private var isApplying: Bool { model.applyPhase == .applying }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Apply \(theme.name)")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Preview of changes across your managed tools")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }

    @ViewBuilder
    private var content: some View {
        if plans.isEmpty {
            ContentUnavailableView(
                "No Tools Enabled",
                systemImage: "slider.horizontal.3",
                description: Text("Enable tools in Settings to preview changes.")
            )
            .frame(maxHeight: .infinity)
        } else {
            List(plans) { plan in
                PlanRow(plan: plan)
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: 12) {
            resultBanner

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Writes to your real config files")
                        .fontWeight(.medium)
                    Text("Each overwritten file is backed up as <name>.bak first, then reload hooks run.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Close") { dismiss() }
                Button("Apply") {
                    Task {
                        await model.apply(theme)
                        plans = model.plan(for: theme)
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(isApplying)
            }
        }
        .padding()
    }

    @ViewBuilder
    private var resultBanner: some View {
        switch model.applyPhase {
        case .idle:
            EmptyView()
        case .applying:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Applying…").foregroundStyle(.secondary)
                Spacer()
            }
        case .succeeded(let summary):
            Label(summary, systemImage: "checkmark.seal.fill")
                .foregroundStyle(.green)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        case .failed(let message):
            Label("Apply failed: \(message)", systemImage: "xmark.octagon.fill")
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }
}

private struct PlanRow: View {
    let plan: ToolPlan

    var body: some View {
        DisclosureGroup {
            detail
                .padding(.top, 4)
        } label: {
            label
        }
    }

    private var label: some View {
        HStack(spacing: 10) {
            Image(systemName: plan.symbolName)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(plan.tool.displayName)
                    .fontWeight(.medium)
                Text(plan.tool.displayPath)
                    .font(.caption)
                    .monospaced()
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(plan.verb)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch plan.outcome {
        case .failed(let message):
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        case .noop:
            Text("Already matches this theme.")
                .font(.callout)
                .foregroundStyle(.secondary)
        case .create(let new), .modify(_, let new):
            ScrollView {
                Text(new)
                    .font(.caption)
                    .monospaced()
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 200)
            .padding(8)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
        }
    }

    private var tint: Color {
        switch plan.outcome {
        case .create: return .green
        case .modify: return .blue
        case .noop: return .gray
        case .failed: return .orange
        }
    }
}
