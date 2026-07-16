import Foundation

/// A single tool's knowledge of how to express a `Theme` in *its own* config
/// format.
///
/// An adapter is a **pure transform**: given a theme and the current on-disk
/// config text (`nil` when the file doesn't exist yet), it returns the new text
/// that should be written. It performs no file I/O itself — that's the job of
/// `ApplyEngine` (Milestone 4), which will own atomic writes, backups, dry-run
/// diffs, and reload hooks. Keeping adapters pure is what makes them trivially
/// unit-testable from the terminal: a `String` goes in, a `String` comes out,
/// no disk or environment involved.
public protocol ThemeAdapter: Sendable {
    /// The tool's key in `Theme.toolNames` and in per-tool settings
    /// (e.g. `"ghostty"`, `"zellij"`).
    var toolName: String { get }

    /// Produce the config text for `theme`, given the `current` contents of the
    /// tool's config file (`nil` when that file doesn't exist yet).
    ///
    /// - Throws: an `AdapterError`, or one of the helper errors
    ///   (`ConfigLineEditor.EditError`, `TemplateRenderer.RenderError`), when
    ///   the theme can't be expressed — e.g. a required anchor line is missing,
    ///   or the theme lacks a name this tool needs.
    func render(theme: Theme, current: String?) throws -> String
}

/// Errors shared across adapters. The shared helpers throw their own, more
/// precise errors (`ConfigLineEditor.EditError`, `TemplateRenderer.RenderError`).
public enum AdapterError: Error, Equatable {
    /// The theme has no entry in `toolNames` for a tool that needs one to point
    /// at a built-in theme (e.g. Ghostty's `theme = <name>`).
    case missingToolName(tool: String, theme: String)
}
