import ArgumentParser
import Foundation
import ThemeKit

@main
struct Themectl: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "themectl",
        abstract: "Sync and validate Chroma's theme definitions.",
        subcommands: [List.self, Validate.self, Sync.self]
    )
}

struct List: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "List bundled themes."
    )

    func run() throws {
        let store = try ThemeStore.bundled()
        for theme in store.themes {
            print("\(theme.id)\t\(theme.name) [\(theme.appearance.rawValue)]")
        }
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
