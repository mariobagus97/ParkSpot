import Foundation
import SwiftData
import Testing
import UIKit
@testable import ParkSpot

@MainActor struct FindCoordinatorTests {
    let location = FakeLocation()
    let photos = FakePhotoStore()
    let maps = FakeMaps()
    let clock = FakeClock()
    let container = ModelContainer.inMemory()
    let deps: AppDependencies
    let saver: SpotSaver

    init() {
        container.mainContext.autosaveEnabled = false
        deps = .test(location: location, photos: photos, container: container, maps: maps, clock: clock)
        saver = SpotSaver(deps: deps)
    }

    /// An active spot 84 m east, stored in the repository.
    func storedSpot(metres: Double? = 84) throws -> ParkingSpot {
        let spot = ParkingSpot(createdAt: clock.now, photoFileName: "a.jpg")
        if let metres {
            spot.latitude = 0
            spot.longitude = metres / 111_194.93
            spot.accuracy = 5
        }
        spot.placeName = "Jl. Sudirman"
        try deps.repository.insertActive(spot)
        return spot
    }

    @Test func showMapPushesRoute() throws {
        let spot = try storedSpot()
        let coordinator = FindCoordinator(spotID: spot.id, deps: deps, saver: saver)

        coordinator.showMap()

        #expect(coordinator.path == [.map])
    }

    @Test func foundItEndsSessionAndCallsBack() throws {
        let spot = try storedSpot()
        let coordinator = FindCoordinator(spotID: spot.id, deps: deps, saver: saver)
        var ended = 0
        coordinator.onEnded = { ended += 1 }

        coordinator.foundIt()

        #expect(try deps.repository.activeSpot() == nil)
        #expect(ended == 1)
    }

    @Test func foundItStopsRefinement() async throws {
        saver.beginCapture()
        let spot = try saver.commit(photo: .solid())
        #expect(saver.isRefining)
        let coordinator = FindCoordinator(spotID: spot.id, deps: deps, saver: saver)

        coordinator.foundIt()
        await settle()

        #expect(!saver.isRefining)
    }

    @Test func directionsOpensMapsWithSpotCoordinate() throws {
        let spot = try storedSpot()
        let coordinator = FindCoordinator(spotID: spot.id, deps: deps, saver: saver)

        coordinator.openDirections()

        let expected = try #require(spot.savedLocation?.coordinate)
        #expect(maps.opened == [expected])
    }

    @Test func directionsWithoutCoordinatesDoesNothing() throws {
        let spot = try storedSpot(metres: nil)
        let coordinator = FindCoordinator(spotID: spot.id, deps: deps, saver: saver)

        coordinator.openDirections()

        #expect(maps.opened.isEmpty)
    }

    @Test func idIsTheSpotID() throws {
        let spot = try storedSpot()
        let coordinator = FindCoordinator(spotID: spot.id, deps: deps, saver: saver)

        #expect(coordinator.id == spot.id)
    }

    @Test func foundItWithAMissingSpotStillCallsBack() {
        let coordinator = FindCoordinator(spotID: UUID(), deps: deps, saver: saver)
        var ended = 0
        coordinator.onEnded = { ended += 1 }

        #expect(coordinator.spot == nil)
        coordinator.foundIt()
        #expect(ended == 1)
    }

    @Test func photoOpensAndCloses() throws {
        let spot = try storedSpot()
        let coordinator = FindCoordinator(spotID: spot.id, deps: deps, saver: saver)

        coordinator.showPhoto()
        #expect(coordinator.isPhotoPresented)

        coordinator.hidePhoto()
        #expect(!coordinator.isPhotoPresented)
    }

    @Test func closeKeepsSpotActive() throws {
        let spot = try storedSpot()
        let coordinator = FindCoordinator(spotID: spot.id, deps: deps, saver: saver)
        var closed = 0
        coordinator.onClose = { closed += 1 }

        coordinator.close()

        #expect(closed == 1)
        #expect(try deps.repository.activeSpot()?.id == spot.id)
    }
}
