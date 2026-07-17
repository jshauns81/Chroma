import ArgumentParser
import Foundation
import ThemeKit

@main
struct Themectl: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "themectl",
        abstract: "Manage Chroma's themes: list, validate, sync, and apply.",
        subcommands: [List.self, Validate.self, Sync.self, Apply.self, Current.self]
    )
}

struct List: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "List available themes (bundled + imported)."
    )

    @Flag(name: .long, help: "Machine format: tab-separated id, name, appearance, accent hex.")
    var porcelain = false

    func run() throws {
        let store = try ThemeStore.chromaLibrary()
        for theme in store.themes {
            if porcelain {
                print("\(theme.id)\t\(theme.name)\t\(theme.appearance.rawValue)\t\(theme.palette.accent.hexString)")
            } else {
                print("\(theme.id)\t\(theme.name) [\(theme.appearance.rawValue)]")
            }
        }
    }
}

struct Apply: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Apply a theme to every managed tool (writes configs, backs up, reloads)."
    )

    @Argument(help: "Theme id to apply (see `themectl list`).")
    var id: String

    @Flag(name: .customLong("no-reload"), help: "Skip the per-tool reload hooks.")
    var noReload = false

    @Flag(name: .long, help: "After writing, run `chezmoi re-add` on changed files.")
    var rebind = false

    @Flag(name: .long, help: "Show what would change without writing any files.")
    var dryRun = false

    func run() async throws {
        let store = try ThemeStore.chromaLibrary()
        guard let theme = store.theme(id: id) else {
            FileHandle.standardError.write(Data("No theme with id '\(id)'. Run `themectl list`.\n".utf8))
            throw ExitCode.failure
        }

        // Skip tools that can't render this theme — e.g. Zellij, which needs a
        // built-in theme name the theme may not carry (Rosé Pine). One
        // unsupported tool shouldn't abort the whole switch; this mirrors the
        // app's per-tool leniency (`AppModel.plan`).
        var usable: [ManagedTool] = []
        var skipped: [String] = []
        for tool in ChromaTools.all {
            let current = try? String(contentsOf: tool.configURL, encoding: .utf8)
            if (try? tool.adapter.render(theme: theme, current: current)) != nil {
                usable.append(tool.managedTool(runReload: !noReload))
            } else {
                skipped.append(tool.displayName)
            }
        }
        if !skipped.isEmpty {
            FileHandle.standardError.write(
                Data("Skipped (no \(theme.name) theme): \(skipped.joined(separator: ", "))\n".utf8)
            )
        }

        let engine = ApplyEngine(
            tools: usable,
            dotfileReAddCommand: rebind ? ["chezmoi", "re-add", "{}"] : nil,
            currentThemeStateURL: ChromaPaths.currentThemeState
        )

        if dryRun {
            for change in try await engine.plan(for: theme) {
                print(change.summary)
            }
            return
        }

        let changes = try await engine.apply(theme)
        let changed = changes.filter { !$0.isNoop }
        if changed.isEmpty {
            print("No changes needed — configs already match \(theme.name).")
        } else {
            let names = changed.map { $0.url.lastPathComponent }.joined(separator: ", ")
            print("Applied \(theme.name): updated \(changed.count) file(s) — \(names).")
        }
    }
}

struct Current: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Print the id of the theme applied most recently."
    )

    func run() throws {
        guard let id = try? String(contentsOf: ChromaPaths.currentThemeState, encoding: .utf8) else {
            throw ExitCode.failure  // nothing applied yet
        }
        print(id.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

struct Validate: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Check theme JSONs decode and define every required role."
    )

    @Option(
        name: .customLong("themes-dir"),
        help: "Directory of theme JSONs to validate. Defaults to the bundled themes."
    )
    var themesDir: String?

    func run() throws {
        let reports = try themesDir.map {
            try ThemeValidator.validate(directory: URL(fileURLWithPath: $0))
        } ?? ThemeValidator.validateBundled()

        for report in reports {
            print(report.summary)
        }

        let invalid = reports.filter { !$0.isValid }.count
        guard invalid == 0 else {
            throw ExitCode.failure
        }
    }
}

struct Sync: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Refresh theme palettes from their canonical upstream sources."
    )

    @Option(
        name: .customLong("themes-dir"),
        help: "Directory of theme JSONs to update in place (e.g. ThemeKit/Sources/ThemeKit/Resources/Themes)."
    )
    var themesDir: String

    @Argument(help: "Theme id(s) to sync. Omit to sync every theme in the directory.")
    var ids: [String] = []

    @Flag(name: .long, help: "Report what would change without writing any files.")
    var dryRun = false

    func run() async throws {
        let directory = URL(fileURLWithPath: themesDir)
        let store = try ThemeStore.load(fromDirectory: directory)

        let targets: [Theme]
        if ids.isEmpty {
            targets = store.themes
        } else {
            targets = try ids.map { id in
                guard let theme = store.theme(id: id) else {
                    throw ValidationError("No theme with id '\(id)' in \(themesDir)")
                }
                return theme
            }
        }

        let syncer = ThemeSyncer()
        var updatedCount = 0

        for theme in targets {
            let updated = try await syncer.synced(theme, now: Date())
            // Only the colors matter for change detection: fetchedAt always
            // differs, so comparing whole themes would report everything as
            // changed and churn the files needlessly.
            guard updated.palette.colors != theme.palette.colors else {
                print("unchanged  \(theme.id)")
                continue
            }

            updatedCount += 1
            if dryRun {
                print("would sync \(theme.id)")
            } else {
                // The filename stem is the theme id by construction (M1).
                let fileURL = directory.appendingPathComponent("\(theme.id).json")
                try ThemeStore.encode(updated).write(to: fileURL)
                print("synced     \(theme.id)")
            }
        }

        if dryRun && updatedCount > 0 {
            print("\n\(updatedCount) theme(s) would change; re-run without --dry-run to write.")
        }
    }
}
