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

    /// The full Copy table of the plan, key by key. A key dropped from the catalog fails here even when
    /// nothing reads it yet (the two table comparisons above cannot see a key missing from both languages).
    @Test func everyPlannedKeyExists() throws {
        let en = try #require(strings("en")), id = try #require(strings("id"))
        for key in Self.plannedKeys {
            #expect(en[key] != nil && id[key] != nil, "\(key) missing from the catalog")
        }
    }

    static let plannedKeys = [
        "about_fmt", "active", "all", "arrived", "back", "calibrate", "cam_b", "cam_t", "cancel", "close",
        "delete", "delete_t", "dir_ahead", "dir_ahead_left", "dir_ahead_right", "dir_behind", "dir_left",
        "dir_right", "directions", "directions_maps", "done", "finding", "floor", "floor_fmt", "floor_ph",
        "found", "gps_fmt", "hello", "improving_fmt", "loc_b", "loc_locked_fmt", "loc_t", "locating", "malls",
        "map", "no_spots", "noloc", "not_now", "note", "note_ph", "open_settings", "other_floor", "park_here",
        "photo_hint", "photo_only", "photo_required_t", "recent", "replace", "replace_b_fmt", "replace_t",
        "rough_fmt", "save_failed_b", "save_failed_t", "saved_ago_fmt", "saved_at_fmt", "search", "spot_saved",
        "streets", "tab_home", "tab_lib", "take_photo", "unnamed", "use_again", "walk_fmt", "your_car",
    ]

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
