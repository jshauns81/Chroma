import Foundation

/// Fetches raw bytes from a URL.
///
/// A *protocol* for the same reason `CommandRunner` is one: `ThemeSyncer`
/// depends on "something that can fetch bytes," not on `URLSession`.
/// Production injects `URLSessionThemeFetcher`; tests inject a fake that
/// returns a fixture, so the suite never touches the network.
public protocol ThemeFetcher: Sendable {
    func data(from url: URL) async throws -> Data
}

/// The real fetcher, backed by `URLSession`. Read-only outbound HTTPS to the
/// palette's canonical upstream — no injection, nothing SIP touches.
public struct URLSessionThemeFetcher: ThemeFetcher {
    public init() {}

    public func data(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse,
           !(200..<300).contains(http.statusCode) {
            throw ThemeSyncError.httpStatus(url: url, code: http.statusCode)
        }
        return data
    }
}

public enum ThemeSyncError: Error, Equatable {
    /// No mapper is registered for the theme's `family`.
    case unsupportedFamily(String)
    /// The upstream URL couldn't be rewritten to a fetchable raw URL.
    case unfetchableSource(URL)
    /// The upstream fetch returned a non-2xx status.
    case httpStatus(url: URL, code: Int)
    /// The upstream payload didn't contain the requested variant.
    case variantNotFound(String)
    /// The upstream payload was missing a color the mapper needs.
    case missingUpstreamColor(name: String)
    /// An upstream color value wasn't a parseable hex string.
    case invalidUpstreamColor(name: String, value: String)
}
