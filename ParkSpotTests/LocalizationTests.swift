import Testing
import Foundation
@testable import ParkSpot

struct LocalizationTests {
    @Test func everyKeyHasEnglishAndIndonesian() throws {
        let en = try #require(strings("en")), id = try #require(strings("id"))
        #expect(!en.isEmpty)
        #expect(Set(en.keys) == Set(id.keys))
        #expect(id.values.allSatisfy { !$0.isEmpty })
    }

    /// Reads `<lang>.lproj/Localizable.strings` from the host app bundle.
    private func strings(_ lang: String) -> [String: String]? {
        guard let path = Bundle.main.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: lang) else {
            return nil
        }
        return NSDictionary(contentsOfFile: path) as? [String: String]
    }
}
