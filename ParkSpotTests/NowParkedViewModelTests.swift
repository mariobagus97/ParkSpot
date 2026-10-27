import Foundation
import SwiftData
import Testing
@testable import ParkSpot

@MainActor struct NowParkedViewModelTests {
    let location = FakeLocation()
    let clock = FakeClock()
    let container = ModelContainer.inMemory()

    let here = Coordinate(latitude: 0, longitude: 0)
    var east84: Coordinate { Coordinate(latitude: 0, longitude: 84 / 111_194.93) }

    func spot(coordinate: Coordinate?) -> ParkingSpot {
        let spot = ParkingSpot(createdAt: clock.now.addingTimeInterval(-7200), photoFileName: "a.jpg")
        if let coordinate {
            spot.latitude = coordinate.latitude
            spot.longitude = coordinate.longitude
            spot.accuracy = 5
        }
        return spot
    }

    @Test func distanceWhenFixAndLocation() async {
        let viewModel = NowParkedViewModel(spot: spot(coordinate: east84), location: location, now: { clock.now })

        viewModel.start()
        location.send(LocationFix(coordinate: here, horizontalAccuracy: 5, timestamp: clock.now))
        await settle()

        #expect(viewModel.distanceText == "84 m")
        viewModel.stop()
    }

    @Test func nilWithoutSavedLocation() async {
        let viewModel = NowParkedViewModel(spot: spot(coordinate: nil), location: location, now: { clock.now })

        viewModel.start()
        location.send(LocationFix(coordinate: here, horizontalAccuracy: 5, timestamp: clock.now))
        await settle()

        #expect(viewModel.distanceText == nil)
        viewModel.stop()
    }

    @Test func savedAgoMentionsHours() {
        let viewModel = NowParkedViewModel(spot: spot(coordinate: east84), location: location, now: { clock.now })

        #expect(viewModel.savedAgoText.contains("2"))
    }
}
