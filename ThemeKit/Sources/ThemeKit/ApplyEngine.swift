import Foundation

/// One tool Chroma manages: the adapter that knows how to theme it, paired with
/// the on-disk config file that adapter's output belongs in.
///
/// The pairing lives here (not in the adapter) on purpose: an adapter is a pure
/// theme→text transform and shouldn't care *where* the file is. Keeping the URL
/// separate also makes the engine testable — tests point these at temp files,
/// never real dotfiles.
public struct ManagedTool: Sendable {
    public let adapter: any ThemeAdapter
    public let url: URL
    /// Command to reload the tool after its config changes, as
    /// `[executable, arg, …]` (e.g. `["sketchybar", "--reload"]`). `nil` means
    /// the tool needs no reload.
    public let reloadCommand: [String]?

    public init(adapter: any ThemeAdapter, url: URL, reloadCommand: [String]? = nil) {
        self.adapter = adapter
        self.url = url
        self.reloadCommand = reloadCommand
    }
}

/// What applying a theme *would* do to one file — computed by reading the
/// current file and running the adapter, but writing nothing.
public struct PlannedChange: Sendable, Equatable {
    public let toolName: String
    public let url: URL
    /// The file's current contents, or `nil` if it doesn't exist yet.
    public let oldContent: String?
    /// The contents the adapter wants to write.
    public let newContent: String

    /// The file doesn't exist yet — applying would create it.
    public var willCreate: Bool { oldContent == nil }
    /// The file already has exactly the desired contents — applying is a no-op.
    public var isNoop: Bool { oldContent == newContent }

    /// A short human-readable status, e.g. for `themectl` dry-run output.
    public var summary: String {
        let verb = isNoop ? "unchanged" : (willCreate ? "create" : "modify")
        return "\(toolName): \(verb) \(url.path)"
    }
}

/// Plans and applies a theme across every managed tool.
///
/// It's an `actor` because `apply` mutates `lastAppliedThemeID` and performs a
/// sequence of file writes: actor isolation serializes those, so two concurrent
/// `apply` calls can't interleave writes or race on the stored state. (While it
/// only *planned*, it was correctly a plain `struct` — the state is what earns
/// the promotion.)
public actor ApplyEngine {
    public let tools: [ManagedTool]
    /// How external commands (hooks) are run. Injected so tests never shell out.
    let runner: any CommandRunner
    /// Optional dotfile-sync hook run per changed file, with `"{}"` replaced by
    /// the file's path — e.g. `["chezmoi", "re-add", "{}"]`. `nil` disables it.
    let dotfileReAddCommand: [String]?

    /// The id of the most recently applied theme, or `nil` if none yet.
    public private(set) var lastAppliedThemeID: Theme.ID?

    public init(
        tools: [ManagedTool],
        runner: any CommandRunner = ProcessCommandRunner(),
        dotfileReAddCommand: [String]? = nil
    ) {
        self.tools = tools
        self.runner = runner
        self.dotfileReAddCommand = dotfileReAddCommand
    }

    /// Compute, without writing anything, what applying `theme` would do to
    /// each managed tool's config file.
    ///
    /// - Throws: rethrows any adapter error (e.g. a missing anchor line) or a
    ///   file-read error, so a broken plan fails loudly before any write.
    public func plan(for theme: Theme) throws -> [PlannedChange] {
        try tools.map { tool in
            let old = try Self.readIfExists(tool.url)
            let new = try tool.adapter.render(theme: theme, current: old)
            return PlannedChange(
                toolName: tool.adapter.toolName,
                url: tool.url,
                oldContent: old,
                newContent: new
            )
        }
    }

    /// Apply `theme`: write every non-noop change to disk, backing up any file
    /// we overwrite, then record the applied theme.
    ///
    /// - Returns: the full plan (including no-ops), so callers can report what
    ///   happened.
    /// - Throws: on the first write failure. Files already written stay written
    ///   (their `.bak` backups let you recover); a partial failure is surfaced
    ///   rather than hidden.
    @discardableResult
    public func apply(_ theme: Theme) async throws -> [PlannedChange] {
        let changes = try plan(for: theme)
        let changed = changes.filter { !$0.isNoop }

        // 1. Write every changed file (atomic, with backup).
        for change in changed {
            try Self.write(change)
        }

        // 2. Dotfile-sync hook: re-add each changed file to its source of truth
        //    (chezmoi), so Chroma's edit doesn't drift from the managed dotfile.
        if let template = dotfileReAddCommand {
            for change in changed {
                let command = template.map { $0 == "{}" ? change.url.path : $0 }
                _ = try await runner.run(command[0], arguments: Array(command.dropFirst()))
            }
        }

        // 3. Reload each tool whose config actually changed, once.
        for tool in tools {
            guard let reload = tool.reloadCommand, !reload.isEmpty,
                  changed.contains(where: { $0.toolName == tool.adapter.toolName })
            else { continue }
            _ = try await runner.run(reload[0], arguments: Array(reload.dropFirst()))
        }

        lastAppliedThemeID = theme.id
        return changes
    }

    /// Write one change atomically, backing up an existing file first.
    private static func write(_ change: PlannedChange) throws {
        let fileManager = FileManager.default

        // Generated files (bat's theme.zsh, SketchyBar's colors.sh) may live in
        // a directory that doesn't exist yet — create it if needed.
        let directory = change.url.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        // Back up an existing file to `<name>.bak` before overwriting it, so a
        // bad theme is always recoverable. (Skipped for first-time creates.)
        if change.oldContent != nil {
            let backup = change.url.appendingPathExtension("bak")
            if fileManager.fileExists(atPath: backup.path) {
                try fileManager.removeItem(at: backup)
            }
            try fileManager.copyItem(at: change.url, to: backup)
        }

        // `atomically: true` writes to a temp file and renames it into place, so
        // a crash mid-write can never leave a half-written config.
        try change.newContent.write(to: change.url, atomically: true, encoding: .utf8)
    }

    /// Read a file's contents, returning `nil` when the file simply isn't there
    /// (a first-time create) but rethrowing genuine read failures.
    private static func readIfExists(_ url: URL) throws -> String? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try String(contentsOf: url, encoding: .utf8)
    }
}
