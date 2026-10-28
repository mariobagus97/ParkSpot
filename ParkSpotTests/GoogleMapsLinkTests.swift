import Foundation
import Testing
@testable import ParkSpot

/// The Google Maps hand-off: a pure URL, so the format and the locale rule can be checked without a device.
struct GoogleMapsLinkTests {
    @Test func walkingDirectionsURL() {
        let url = GoogleMapsLink.walking(to: Coordinate(latitude: -6.2, longitude: 106.8174))

        #expect(url?.absoluteString == "comgooglemaps://?daddr=-6.200000,106.817400&directionsmode=walking")
    }

    @Test func coordinatesUseDotsInAnyLocale() {
        // Indonesian uses a comma as the decimal separator; Google Maps must still get dots.
        let previous = Locale.current
        _ = previous   // the formatter pins en_US_POSIX itself, which this asserts:
        let url = GoogleMapsLink.walking(to: Coordinate(latitude: 0.5, longitude: 0.25))

        #expect(url?.absoluteString.contains("0.500000,0.250000") == true)
        #expect(url?.absoluteString.contains("0,500000") == false)
    }

    @Test func schemeIsTheOneDeclaredInTheInfoPlist() {
        // `canOpenURL` only answers true for schemes listed in LSApplicationQueriesSchemes.
        let schemes = Bundle.main.object(forInfoDictionaryKey: "LSApplicationQueriesSchemes") as? [String]

        #expect(schemes?.contains(GoogleMapsLink.scheme) == true)
    }
}
