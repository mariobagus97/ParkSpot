import Foundation
import Testing
@testable import ParkSpot

@MainActor struct MapViewModelTests {
    let location = FakeLocation()
    let maps = FakeMaps()
    let clock = FakeClock()

    let here = Coordinate(latitude: 0, longitude: 0)
    var east84: Coordinate { Coordinate(latitude: 0, longitude: 84 / 111_194.93) }

    func spot(coordinate: Coordinate?) -> ParkingSpot {
        let spot = ParkingSpot(createdAt: clock.now, photoFileName: "a.jpg")
        if let coordinate {
            spot.latitude = coordinate.latitude
            spot.longitude = coordinate.longitude
            spot.accuracy = 5
        }
        spot.placeName = "Jl. Sudirman"
        return spot
    }

    func fix() -> LocationFix {
        LocationFix(coordinate: here, horizontalAccuracy: 5, timestamp: clock.now)
    }

    @Test func walkTimeFromDistance() async {
        let spot = spot(coordinate: east84)
        let viewModel = MapViewModel(spot: spot, location: location, maps: maps)

        viewModel.start()
        location.send(fix())
        await settle()

        #expect(viewModel.distanceText == "84 m")
        #expect(viewModel.walkMinutes == 1)
        viewModel.stop()
    }

    @Test func noFixHidesDistance() async {
        let viewModel = MapViewModel(spot: spot(coordinate: east84), location: location, maps: maps)

        viewModel.start()
        await settle()

        #expect(viewModel.distanceText == nil)
        #expect(viewModel.walkMinutes == nil)
        viewModel.stop()
    }

    @Test func coordinateLessSpotHasNoDistanceOrAccuracy() async {
        let viewModel = MapViewModel(spot: spot(coordinate: nil), location: location, maps: maps)

        viewModel.start()
        location.send(fix())
        await settle()

        #expect(viewModel.distanceText == nil)
        #expect(viewModel.walkMinutes == nil)
        #expect(viewModel.accuracyText == nil)
        viewModel.stop()
    }

    @Test func walkInMapsUsesSpotCoordinate() {
        let viewModel = MapViewModel(spot: spot(coordinate: east84), location: location, maps: maps)

        viewModel.walkInMaps()

        #expect(maps.opened == [east84])
    }

    @Test func walkInMapsWithoutCoordinateDoesNothing() {
        let viewModel = MapViewModel(spot: spot(coordinate: nil), location: location, maps: maps)

        viewModel.walkInMaps()

        #expect(maps.opened.isEmpty)
    }
}
