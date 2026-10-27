import Foundation
import Testing
@testable import ParkSpot

/// The app collects nothing and tracks nobody: the manifest has to say so.
struct PrivacyManifestTests {
    @Test func noTrackingAndNothingCollected() throws {
        let url = try #require(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let plist = try #require(NSDictionary(contentsOf: url) as? [String: Any])

        #expect(plist["NSPrivacyTracking"] as? Bool == false)
        #expect((plist["NSPrivacyTrackingDomains"] as? [Any])?.isEmpty == true)
        #expect((plist["NSPrivacyCollectedDataTypes"] as? [Any])?.isEmpty == true)
        // No UserDefaults, no file timestamps, no boot-time reads: nothing needs a required-reason API.
        #expect((plist["NSPrivacyAccessedAPITypes"] as? [Any])?.isEmpty == true)
    }
}
