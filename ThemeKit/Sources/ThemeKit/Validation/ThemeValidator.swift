import Foundation

/// Structural + semantic validation of theme JSON files.
///
/// Two distinct failure modes, surfaced separately because they mean different
/// things to whoever's editing the file:
///
/// - **Malformed** — the JSON didn't decode into a `Theme` at all: a syntax
///   error, an unknown `ColorRole` name, or an unparseable hex string. These
///   are caught by `Theme`'s (hand-written) `Codable` conformance.
/// - **Missing roles** — the file decoded fine, but the palette omits a role
///   `Palette.requiredRoles` says every theme must define explicitly.
///
/// `validate` never throws for a bad *theme file* — a malformed file is a
/// result, not an exception — so one broken file doesn't hide the verdicts on
/// its neighbours. It only throws if the *directory itself* can't be read.
public enum ThemeValidator {
    public struct Report: Sendable, Equatable {
        public let url: URL
        public let outcome: Outcome

        public enum Outcome: Sendable, Equatable {
            /// Decoded and every required role is present.
            case valid(themeID: String)
            /// Failed to decode into a `Theme`.
            case malformed(reason: String)
            /// Decoded, but these required roles are absent from the palette.
            case missingRoles([ColorRole])
        }

        public var isValid: Bool {
            if case .valid = outcome { return true }
            return false
        }

        /// A single line suitable for CLI output, e.g. `✓ catppuccin-mocha`.
        public var summary: String {
            let file = url.lastPathComponent
            switch outcome {
            case .valid(let id):
                return "✓ \(file) (\(id))"
            case .malformed(let reason):
                return "✗ \(file): \(reason)"
            case .missingRoles(let roles):
                let names = roles.map(\.rawValue).joined(separator: ", ")
                return "✗ \(file): missing required role(s): \(names)"
            }
        }
    }

    /// Validate every `*.json` in `directory`.
    public static func validate(directory: URL) throws -> [Report] {
        try ThemeStore.themeURLs(in: directory).map(validate(fileAt:))
    }

    /// Validate the themes bundled inside `ThemeKit`.
    public static func validateBundled() throws -> [Report] {
        try ThemeStore.bundledThemeURLs().map(validate(fileAt:))
    }

    /// Validate one file, mapping every failure onto an `Outcome`.
    public static func validate(fileAt url: URL) -> Report {
        let theme: Theme
        do {
            theme = try ThemeStore.loadTheme(at: url)
        } catch {
            return Report(url: url, outcome: .malformed(reason: describe(error)))
        }

        do {
            try theme.validate()
            return Report(url: url, outcome: .valid(themeID: theme.id))
        } catch let Palette.ValidationError.missingRequiredRoles(roles) {
            return Report(url: url, outcome: .missingRoles(roles))
        } catch {
            return Report(url: url, outcome: .malformed(reason: describe(error)))
        }
    }

    /// Unwrap `ThemeStore.LoadError.decodeFailed` to the underlying decode
    /// error's message, so the report points at the real problem instead of a
    /// wrapper.
    private static func describe(_ error: Error) -> String {
        if case let ThemeStore.LoadError.decodeFailed(_, underlying) = error {
            return describe(underlying)
        }
        if let decoding = error as? DecodingError {
            switch decoding {
            case .dataCorrupted(let ctx),
                 .keyNotFound(_, let ctx),
                 .typeMismatch(_, let ctx),
                 .valueNotFound(_, let ctx):
                return ctx.debugDescription
            @unknown default:
                return String(describing: decoding)
            }
        }
        return error.localizedDescription
    }
}
