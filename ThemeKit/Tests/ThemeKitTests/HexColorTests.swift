import Foundation
import Testing
@testable import ThemeKit

@Suite("HexColor parsing")
struct HexColorTests {
    @Test("parses common notations", arguments: [
        "#a6da95", "a6da95", "0xffa6da95", "  #A6DA95  ",
    ])
    func parsesNotations(input: String) {
        #expect(HexColor(parsing: input)?.rgb == 0xA6DA95)
    }

    @Test("rejects malformed input", arguments: [
        "", "#fff", "a6da9", "#a6da95ff00", "not-a-color", "#gghhii",
    ])
    func rejectsMalformed(input: String) {
        #expect(HexColor(parsing: input) == nil)
    }

    @Test func roundTripsToHexString() {
        let color = HexColor(parsing: "#24273A")
        #expect(color?.hexString == "#24273a")
    }

    @Test func rendersSketchyBarARGB() {
        let base = HexColor(rgb: 0x24273A)
        #expect(base.argb() == "0xff24273a")
        #expect(base.argb(alpha: 0x40) == "0x4024273a")
        #expect(base.argb(alpha: 0xE6) == "0xe624273a")
    }

    @Test func exposesUnitChannels() throws {
        let white = try #require(HexColor(parsing: "#ffffff"))
        #expect(white.red == 1 && white.green == 1 && white.blue == 1)
        let red = try #require(HexColor(parsing: "#ff0000"))
        #expect(red.red == 1 && red.green == 0 && red.blue == 0)
    }

    @Test func codableUsesHexStrings() throws {
        let json = "\"#c6a0f6\"".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(HexColor.self, from: json)
        #expect(decoded.rgb == 0xC6A0F6)

        let encoded = try JSONEncoder().encode(decoded)
        #expect(String(data: encoded, encoding: .utf8) == "\"#c6a0f6\"")
    }
}
