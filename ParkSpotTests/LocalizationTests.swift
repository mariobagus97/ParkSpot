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

    /// Every copy key the code builds by name (not as a literal) must exist, or the screen shows the key.
    @Test func codeKeysExist() throws {
        let en = try #require(strings("en"))
        for phrase in DirectionPhrase.allCases { #expect(en[phrase.key] != nil, "\(phrase.key) missing") }
        for filter in SpotFilter.allCases { #expect(en[filter.key] != nil, "\(filter.key) missing") }
    }

    /// Reads `<lang>.lproj/Localizable.strings` from the host app bundle.
    private func strings(_ lang: String) -> [String: String]? {
        guard let path = Bundle.main.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: lang) else {
            return nil
        }
        return NSDictionary(contentsOfFile: path) as? [String: String]
    }
}
