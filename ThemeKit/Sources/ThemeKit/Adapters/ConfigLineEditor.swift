/// Anchored, single-line replacement inside an existing config file.
///
/// The one rule: **never guess.** If the anchor line isn't found — or is found
/// more than once — we throw, rather than appending a duplicate or picking a
/// line at random. A theme switcher that silently appends duplicate keys or
/// edits the wrong line is worse than one that stops and tells you what it
/// couldn't do. Deciding what to do when an anchor is *missing* (e.g. insert
/// it) is the adapter's policy; this helper only ever **replaces**.
///
/// This is declared as an `enum` with no cases — a common Swift idiom for a
/// pure namespace. Unlike a `struct`, a caseless `enum` cannot be instantiated,
/// which documents "this type is only a home for static functions, never a
/// value you hold onto."
public enum ConfigLineEditor {
    public enum EditError: Error, Equatable {
        /// No line satisfied the anchor. The associated string is the
        /// human-readable anchor label, for a useful error message.
        case anchorNotFound(String)
        /// More than one line satisfied the anchor — ambiguous, so we refuse.
        case ambiguousAnchor(String, matches: Int)
    }

    /// Replace exactly one line matching `anchor` with `replacement`.
    ///
    /// Surrounding lines and the file's trailing newline are preserved.
    ///
    /// - Parameters:
    ///   - content: the current file contents.
    ///   - replacement: the full text of the new line (no trailing newline).
    ///   - anchorLabel: a human-readable description of the anchor, surfaced in
    ///     error messages (e.g. `"theme = …"`).
    ///   - anchor: a predicate deciding whether a given line is the one to
    ///     replace. Receives each line with its own line ending already stripped.
    /// - Throws: `EditError.anchorNotFound` if nothing matches;
    ///   `EditError.ambiguousAnchor` if more than one line matches.
    public static func replacingLine(
        in content: String,
        with replacement: String,
        anchorLabel: String,
        where anchor: (String) -> Bool
    ) throws -> String {
        // Split on newlines *keeping* empty subsequences, so that a trailing
        // "\n" survives the round-trip. Example: "a\nb\n" splits into
        // ["a", "b", ""], and joining with "\n" reproduces "a\nb\n" exactly.
        var lines = content
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        // Collect the indices of every line the predicate accepts. We look at
        // all of them (not just the first) so we can detect ambiguity.
        let matchingIndices = lines.indices.filter { anchor(lines[$0]) }

        guard !matchingIndices.isEmpty else {
            throw EditError.anchorNotFound(anchorLabel)
        }
        guard matchingIndices.count == 1 else {
            throw EditError.ambiguousAnchor(anchorLabel, matches: matchingIndices.count)
        }

        lines[matchingIndices[0]] = replacement
        return lines.joined(separator: "\n")
    }
}
