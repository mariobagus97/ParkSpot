import Foundation
import SwiftData
import Testing
import UIKit
@testable import ParkSpot

@MainActor struct AppCoordinatorTests {
    let location = FakeLocation()
    let photos = FakePhotoStore()
    let clock = FakeClock()
    let container = ModelContainer.inMemory()
    let deps: AppDependencies
    let coordinator: AppCoordinator

    init() {
        container.mainContext.autosaveEnabled = false
        deps = .test(location: location, photos: photos, container: container, clock: clock)
        coordinator = AppCoordinator(deps: deps)
    }

    func activeSpot() throws -> ParkingSpot {
        let spot = ParkingSpot(createdAt: clock.now, photoFileName: "a.jpg")
        spot.placeName = "Jl. Sudirman"
        try deps.repository.insertActive(spot)
        return spot
    }

    @Test func launchWithActiveSpotPresentsFind() throws {
        let spot = try activeSpot()

        coordinator.launch()

        #expect(coordinator.activeSpotID == spot.id)
        #expect(coordinator.find?.id == spot.id)
    }

    @Test func launchWithoutActiveStaysHome() {
        coordinator.launch()

        #expect(coordinator.find == nil)
        #expect(coordinator.activeSpot == nil)
    }

    @Test func savingSetsActiveSpotWithoutFind() throws {
        let spot = try activeSpot()

        coordinator.save.onSaved(spot.id)

        #expect(coordinator.activeSpotID == spot.id)
        #expect(coordinator.find == nil)
    }

    @Test func spotEndedClearsEverything() throws {
        _ = try activeSpot()
        coordinator.launch()

        coordinator.spotEnded()

        #expect(coordinator.activeSpotID == nil)
        #expect(coordinator.find == nil)
    }

    @Test func presentFindWithoutActiveDoesNothing() {
        coordinator.presentFind()

        #expect(coordinator.find == nil)
    }

    @Test func dismissFindKeepsTheSpotActive() throws {
        let spot = try activeSpot()
        coordinator.launch()

        coordinator.dismissFind()

        #expect(coordinator.find == nil)
        #expect(coordinator.activeSpotID == spot.id)
    }
}
