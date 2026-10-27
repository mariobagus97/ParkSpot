import Foundation
import SwiftData
import Testing
import UIKit
@testable import ParkSpot

@MainActor final class Recorder: @unchecked Sendable { var values: [Bool] = [] }

@MainActor struct HistoryCoordinatorTests {
    let recorder = Recorder()
    let location = FakeLocation()
    let photos = FakePhotoStore()
    let clock = FakeClock()
    let container = ModelContainer.inMemory()
    let deps: AppDependencies
    let saver: SpotSaver
    let coordinator: HistoryCoordinator

    final class Recorder: @unchecked Sendable { var values: [Bool] = [] }

    init() {
        container.mainContext.autosaveEnabled = false
        deps = .test(location: location, photos: photos, container: container, clock: clock)
        saver = SpotSaver(deps: deps)
        coordinator = HistoryCoordinator(deps: deps, saver: saver)
        coordinator.onActiveChanged = { [recorder] openFind in recorder.values.append(openFind) }
    }

    func insert(_ name: String, active: Bool = false) throws -> ParkingSpot {
        let spot = ParkingSpot(createdAt: clock.now, photoFileName: "\(name).jpg")
        spot.placeName = name
        if active { try deps.repository.insertActive(spot) } else { container.mainContext.insert(spot); try deps.repository.save() }
        return spot
    }

    @Test func useAgainWithoutActiveActivates() throws {
        let spot = try insert("Old")

        coordinator.useAgain(spot.id)

        #expect(try deps.repository.activeSpot()?.id == spot.id)
        #expect(recorder.values == [true])
    }

    @Test func useAgainWithOtherActiveAsks() throws {
        let current = try insert("Now", active: true)
        let old = try insert("Old")

        coordinator.useAgain(old.id)

        #expect(coordinator.confirmUseAgainFor == old.id)
        #expect(try deps.repository.activeSpot()?.id == current.id)
        #expect(recorder.values.isEmpty)
    }

    @Test func confirmUseAgainActivatesAndNotifies() throws {
        try insert("Now", active: true)
        let old = try insert("Old")
        coordinator.useAgain(old.id)

        coordinator.confirmUseAgain()

        #expect(try deps.repository.activeSpot()?.id == old.id)
        #expect(coordinator.confirmUseAgainFor == nil)
        #expect(recorder.values == [true])
    }

    @Test func deleteActiveStopsRefinementAndNotifies() async throws {
        let spot = try saver.commit(photo: .solid())
        #expect(saver.isRefining)

        coordinator.delete(spot.id)

        #expect(!saver.isRefining)
        #expect(try deps.repository.activeSpot() == nil)
        #expect(recorder.values == [false])
    }

    @Test func deleteInactiveDoesNotNotify() throws {
        try insert("Now", active: true)
        let old = try insert("Old")

        coordinator.delete(old.id)

        #expect(try deps.repository.allSpots().map(\.placeName) == ["Now"])
        #expect(recorder.values.isEmpty)
    }
}
