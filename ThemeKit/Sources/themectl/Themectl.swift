import ArgumentParser
import ThemeKit

@main
struct Themectl: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "themectl",
        abstract: "Sync and validate Chroma's theme definitions.",
        subcommands: [List.self]
        // sync / validate arrive in Milestone 5
    )
}

struct List: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "List bundled themes."
    )

    func run() throws {
        print("No themes bundled yet — Milestone 1 adds the Catppuccin flavors.")
    }
}
