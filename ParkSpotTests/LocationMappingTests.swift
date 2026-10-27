import CoreLocation
import Testing
@testable import ParkSpot

/// The pure rules `LocationService` applies to what Core Location hands it.
struct LocationMappingTests {
    let stamp = Date(timeIntervalSince1970: 1_000_000)

    func location(accuracy: Double) -> CLLocation {
        CLLocation(coordinate: .init(latitude: -6.2, longitude: 106.8), altitude: 0,
                   horizontalAccuracy: accuracy, verticalAccuracy: -1, timestamp: stamp)
    }

    // R-l: a negative horizontalAccuracy means "invalid" and would otherwise read as a perfect fix.
    @Test func negativeAccuracyFixIsDropped() { #expect(LocationFix(location(accuracy: -1)) == nil) }

    @Test func validFixKeepsItsValues() {
        let fix = LocationFix(location(accuracy: 12))
        #expect(fix == LocationFix(coordinate: .init(latitude: -6.2, longitude: 106.8), horizontalAccuracy: 12, timestamp: stamp))
    }

    @Test func zeroAccuracyIsStillAFix() { #expect(LocationFix(location(accuracy: 0))?.horizontalAccuracy == 0) }

    @Test func trueHeadingIsPreferred() {
        #expect(Heading(trueHeading: 90, magneticHeading: 80, accuracy: 5) == Heading(degrees: 90))
    }

    @Test func magneticHeadingWhenTrueIsUnavailable() {
        #expect(Heading(trueHeading: -1, magneticHeading: 80, accuracy: 5) == Heading(degrees: 80))
    }

    @Test func uncalibratedCompassGivesNoHeading() {
        #expect(Heading(trueHeading: 90, magneticHeading: 80, accuracy: -1) == nil)
    }

    @Test func authorizationStatusesMap() {
        #expect(LocationAuthorization(.notDetermined) == .notDetermined)
        #expect(LocationAuthorization(.authorizedWhenInUse) == .authorized)
        #expect(LocationAuthorization(.authorizedAlways) == .authorized)
        #expect(LocationAuthorization(.denied) == .denied)
        #expect(LocationAuthorization(.restricted) == .denied)
    }
}
