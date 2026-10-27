import Foundation
import SwiftData
import Testing
@testable import ParkSpot

@MainActor struct FindViewModelTests {
    let location = FakeLocation()
    let clock = FakeClock()
    let container = ModelContainer.inMemory()
    let deps: AppDependencies

    init() {
        deps = .test(location: location, container: container, clock: clock)
    }

    /// A point `metres` due east of the caller's position (0, 0).
    func east(_ metres: Double) -> Coordinate {
        Coordinate(latitude: 0, longitude: metres / 111_194.93)
    }

    /// A saved spot `metres` away with the given saved accuracy. Not inserted: the view model only reads it.
    func spot(metres: Double = 84, accuracy: Double = 5, floor: String? = nil) -> ParkingSpot {
        let spot = ParkingSpot(createdAt: clock.now, photoFileName: "a.jpg")
        spot.latitude = 0
        spot.longitude = metres / 111_194.93
        spot.accuracy = accuracy
        spot.floor = floor
        return spot
    }

    /// A fix where the user stands, stamped now.
    func fix(_ accuracy: Double) -> LocationFix {
        LocationFix(coordinate: Coordinate(latitude: 0, longitude: 0),
                    horizontalAccuracy: accuracy,
                    timestamp: clock.now)
    }

    @Test func locatingThenPrecise() async {
        let viewModel = FindViewModel(spot: spot(), location: location)
        #expect(viewModel.display == .locating)

        viewModel.start()
        location.send(fix(5))
        location.sendHeading(Heading(degrees: 0))
        await settle()

        guard case let .precise(distance, _) = viewModel.display else {
            Issue.record("expected precise, got \(viewModel.display)")
            return
        }
        #expect(abs(distance - 84) < 0.05)
        #expect(viewModel.direction == .right)
        viewModel.stop()
    }

    /// Review Focus 2: location off and no fix must never leave the screen on "Getting your location…".
    @Test func deniedShowsPhotoOnly() async {
        location.authorization = .denied
        let viewModel = FindViewModel(spot: spot(), location: location)

        viewModel.start()
        await settle()

        #expect(viewModel.display == .photoOnly)
        viewModel.stop()
    }

    @Test func poorAccuracyIsRough() async {
        let viewModel = FindViewModel(spot: spot(), location: location)
        viewModel.start()
        location.send(fix(45))
        await settle()

        guard case let .rough(_, worst) = viewModel.display else {
            Issue.record("expected rough, got \(viewModel.display)")
            return
        }
        #expect(worst == 45)
        viewModel.stop()
    }

    @Test func progressFromFirstDistance() async {
        let viewModel = FindViewModel(spot: spot(), location: location)
        viewModel.start()
        location.send(fix(5))
        await settle()

        let nearer = LocationFix(coordinate: east(42), horizontalAccuracy: 5, timestamp: clock.now)
        location.send(nearer)
        await settle()

        #expect(abs(viewModel.progress - 0.5) < 0.01)
        viewModel.stop()
    }

    @Test func calibrationNeededIsNoHeading() async {
        let viewModel = FindViewModel(spot: spot(), location: location)
        viewModel.start()
        location.send(fix(5))
        location.sendHeading(Heading(degrees: 10))
        await settle()

        location.sendHeading(nil)
        await settle()

        guard case .noHeading = viewModel.display else {
            Issue.record("expected noHeading, got \(viewModel.display)")
            return
        }
        viewModel.stop()
    }

    @Test func spotWithoutCoordinatesIsPhotoOnly() async {
        let viewModel = FindViewModel(spot: ParkingSpot(createdAt: clock.now, photoFileName: "a.jpg"),
                                      location: location)
        viewModel.start()
        location.send(fix(5))
        await settle()

        #expect(viewModel.display == .photoOnly)
        viewModel.stop()
    }

    @Test func noteIsOfferedForTheGarage() {
        let spot = spot(accuracy: 45)
        spot.note = "Dekat lift biru"

        let viewModel = FindViewModel(spot: spot, location: location)

        #expect(viewModel.spotNote == "Dekat lift biru")
    }

    @Test func blankNoteIsNotOffered() {
        let spot = spot(accuracy: 45)
        spot.note = "   "

        #expect(FindViewModel(spot: spot, location: location).spotNote == nil)
    }

    /// R9: the coordinate is what Map and Directions need; a denied permission must not take them away.
    @Test func deniedStillOffersMapWhenTheSpotHasCoordinates() async {
        location.authorization = .denied
        let viewModel = FindViewModel(spot: spot(), location: location)

        viewModel.start()
        await settle()

        #expect(viewModel.display == .photoOnly)
        #expect(viewModel.offersMapAndDirections)
        viewModel.stop()
    }

    @Test func spotWithoutCoordinatesOffersNothing() {
        let viewModel = FindViewModel(spot: ParkingSpot(createdAt: clock.now, photoFileName: "a.jpg"),
                                      location: location)

        #expect(!viewModel.offersMapAndDirections)
    }

    /// A refinement that lands after Find opens must upgrade the screen, not sit stale.
    @Test func refinementAfterOpenUpgradesTheDisplay() async {
        let spot = spot(accuracy: 45)
        let viewModel = FindViewModel(spot: spot, location: location)

        viewModel.start()
        location.send(fix(5))
        await settle()
        guard case .rough = viewModel.display else {
            Issue.record("expected a rough display first, got \(viewModel.display)")
            return
        }

        spot.accuracy = 8          // the saver sharpened the stored spot while Find was open
        location.send(fix(5))
        location.sendHeading(Heading(degrees: 0))   // a heading is needed for the arrow state
        await settle()

        guard case .precise = viewModel.display else {
            Issue.record("expected the display to sharpen, got \(viewModel.display)")
            return
        }
        viewModel.stop()
    }

    @Test func accessibilityTextCombinesDistanceAndDirection() async {
        let viewModel = FindViewModel(spot: spot(), location: location)
        viewModel.start()
        location.send(fix(5))
        location.sendHeading(Heading(degrees: 0))
        await settle()

        #expect(viewModel.accessibilityText.contains("84 m"))
        #expect(viewModel.accessibilityText.contains(String(localized: "dir_right")))
        viewModel.stop()
    }
}
