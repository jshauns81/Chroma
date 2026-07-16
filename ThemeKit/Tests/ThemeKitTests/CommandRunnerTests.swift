import Testing
import Foundation
@testable import ThemeKit

@Suite("ProcessCommandRunner PATH")
struct CommandRunnerTests {
    /// The reason SketchyBar/chezmoi hooks silently failed from the GUI app:
    /// its minimal PATH lacked Homebrew. augmentedPATH must inject it.
    @Test func prependsHomebrewToMinimalGuiPath() {
        let path = ProcessCommandRunner.augmentedPATH("/usr/bin:/bin:/usr/sbin:/sbin")
        #expect(path.contains("/opt/homebrew/bin"))
        #expect(path.contains("/usr/local/bin"))
        // Homebrew must come *before* the inherited system dirs so a Homebrew
        // tool wins, matching the user's shell.
        let dirs = path.split(separator: ":").map(String.init)
        let brew = try? #require(dirs.firstIndex(of: "/opt/homebrew/bin"))
        let usrbin = try? #require(dirs.firstIndex(of: "/usr/bin"))
        #expect((brew ?? .max) < (usrbin ?? 0))
    }

    @Test func preservesInheritedEntriesAndDeDupes() {
        // An inherited PATH that already has Homebrew shouldn't gain a duplicate.
        let path = ProcessCommandRunner.augmentedPATH("/opt/homebrew/bin:/usr/bin")
        let occurrences = path.split(separator: ":").filter { $0 == "/opt/homebrew/bin" }
        #expect(occurrences.count == 1)
        #expect(path.contains("/usr/bin"))
    }

    @Test func handlesNilInheritedPath() {
        let path = ProcessCommandRunner.augmentedPATH(nil)
        #expect(path.contains("/opt/homebrew/bin"))
        #expect(path.contains("/usr/bin")) // falls back to a sane system default
    }
}
