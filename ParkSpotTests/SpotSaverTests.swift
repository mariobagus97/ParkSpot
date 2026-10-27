import Foundation
import SwiftData
import Testing
import UIKit
@testable import ParkSpot

@MainActor struct SpotSaverTests {
    let location = FakeLocation()
    let photos = FakePhotoStore()
    let geocoder = FakeGeocoder()
    let clock = FakeClock()
    /// Kept for the whole test: a freed container crashes the test host.
    let container = ModelContainer.inMemory()
    let deps: AppDependencies
    let saver: SpotSaver

    init() {
        // Only the saver's own saves may reach the store: autosave would hide a missing one.
        container.mainContext.autosaveEnabled = false
        deps = .test(location: location, photos: photos, container: container, geocoder: geocoder, clock: clock)
        saver = SpotSaver(deps: deps)
    }

    /// A fix at a fixed spot in Jakarta, stamped `age` seconds before the fake clock's now.
    func fix(_ accuracy: Double, age: TimeInterval = 0) -> LocationFix {
        LocationFix(coordinate: Coordinate(latitude: -6.2, longitude: 106.8174),
                    horizontalAccuracy: accuracy,
                    timestamp: clock.now.addingTimeInterval(-age))
    }

    /// The spot as the store holds it, read through a fresh context so unsaved changes stay invisible.
    func stored(_ id: UUID) throws -> ParkingSpot? {
        let reader = ModelContext(container)
        return try reader.fetch(FetchDescriptor<ParkingSpot>(predicate: #Predicate { $0.id == id })).first
    }

    @Test func commitUsesBestFixSoFar() async throws {
        saver.beginCapture()
        location.send(fix(40))
        location.send(fix(15))
        await settle()

        let spot = try saver.commit(photo: .solid())

        #expect(spot.accuracy == 15)
        #expect(spot.isActive)
        #expect(try deps.repository.activeSpot()?.id == spot.id)
    }

    @Test func commitWithoutFixHasNoLocation() async throws {
        // No beginCapture(): commit starts the capture itself.
        let spot = try saver.commit(photo: .solid())

        #expect(spot.savedLocation == nil)
        #expect(spot.isActive)
        #expect(saver.isRefining)
        await settle()
        #expect(location.subscriberCount == 1)
    }

    @Test func persistsEachImprovement() async throws {
        geocoder.name = nil   // a place-name save at the end must not stand in for the improvement's own save
        saver.beginCapture()
        location.send(fix(40))
        await settle()
        let spot = try saver.commit(photo: .solid())
        // Stored by the commit itself, before any later fix.
        #expect(try stored(spot.id)?.accuracy == 40)

        location.send(fix(30))
        await settle()
        #expect(spot.accuracy == 30)
        #expect(try stored(spot.id)?.accuracy == 30)

        location.send(fix(12))
        await settle()

        #expect(spot.accuracy == 12)
        #expect(try stored(spot.id)?.accuracy == 12)
        #expect(try stored(spot.id)?.latitude == -6.2)
    }

    @Test func stopsAt20Metres() async throws {
        saver.beginCapture()
        location.send(fix(40))
        await settle()
        let spot = try saver.commit(photo: .solid())
        #expect(saver.isRefining)

        location.send(fix(20))
        await settle()
        #expect(!saver.isRefining)
        #expect(spot.accuracy == 20)
        #expect(location.subscriberCount == 0)

        location.send(fix(5))
        await settle()
        #expect(spot.accuracy == 20)
        #expect(saver.currentAccuracy == 20)
        #expect(try stored(spot.id)?.accuracy == 20)
    }

    @Test func stopsAfter20Seconds() async throws {
        saver.beginCapture()
        location.send(fix(35))
        await settle()
        let spot = try saver.commit(photo: .solid())

        clock.advance(19)
        saver.checkTimeout()
        #expect(saver.isRefining)

        clock.advance(1)
        saver.checkTimeout()
        #expect(!saver.isRefining)
        await settle()
        #expect(location.subscriberCount == 0)

        location.send(fix(8))
        await settle()
        #expect(spot.accuracy == 35)
    }

    @Test func recentLastKnownIsUsed() throws {
        location.lastKnownFix = fix(25, age: 60)

        let spot = try saver.commit(photo: .solid())

        #expect(spot.accuracy == 25)
        #expect(spot.savedLocation?.coordinate == Coordinate(latitude: -6.2, longitude: 106.8174))
        #expect(saver.currentAccuracy == 25)
    }

    @Test func photoFailureSavesNothing() async throws {
        saver.beginCapture()
        location.send(fix(40))
        await settle()
        photos.failNextSave = true

        #expect(throws: PhotoStoreError.self) { _ = try saver.commit(photo: .solid()) }

        #expect(try deps.repository.allSpots().isEmpty)
        #expect(photos.files.isEmpty)
        #expect(!saver.isRefining)
        await settle()
        #expect(location.subscriberCount == 0)
    }

    @Test func cancelCaptureSavesNothing() async throws {
        saver.beginCapture()
        location.send(fix(40))
        await settle()
        #expect(saver.isRefining)

        saver.cancelCapture()

        #expect(try deps.repository.allSpots().isEmpty)
        #expect(photos.files.isEmpty)
        #expect(!saver.isRefining)
        await settle()
        #expect(location.subscriberCount == 0)
        #expect(try deps.repository.allSpots().isEmpty)
    }

    @Test func geocodesWhenRefinementEnds() async throws {
        saver.beginCapture()
        location.send(fix(40))
        await settle()
        let spot = try saver.commit(photo: .solid())
        await settle()
        #expect(spot.placeName == nil)
        #expect(geocoder.calls.isEmpty)

        location.send(fix(10))
        await settle()

        #expect(spot.placeName == "Jl. Sudirman")
        #expect(geocoder.calls == [Coordinate(latitude: -6.2, longitude: 106.8174)])
        #expect(try stored(spot.id)?.placeName == "Jl. Sudirman")
    }

    @Test func newCaptureStopsOldRefinement() async throws {
        saver.beginCapture()
        location.send(fix(40))
        await settle()
        let a = try saver.commit(photo: .solid())

        saver.beginCapture()
        location.send(fix(5))
        await settle()

        #expect(a.accuracy == 40)
        #expect(try stored(a.id)?.accuracy == 40)
        // The new capture did receive the fix, so the old spot stayed put for the right reason.
        #expect(saver.currentAccuracy == 5)
        let b = try saver.commit(photo: .solid())
        #expect(b.accuracy == 5)
        #expect(a.accuracy == 40)
    }

    @Test func endSessionStopsRefinement() async throws {
        saver.beginCapture()
        location.send(fix(40))
        await settle()
        let a = try saver.commit(photo: .solid())

        saver.stopRefining()
        location.send(fix(5))
        await settle()

        #expect(a.accuracy == 40)
        #expect(try stored(a.id)?.accuracy == 40)
        #expect(!saver.isRefining)
        #expect(location.subscriberCount == 0)

        clock.advance(30)
        saver.checkTimeout()
        await settle()
        #expect(geocoder.calls.isEmpty)
        #expect(a.placeName == nil)
    }

    @Test func photoTintIsStored() throws {
        let spot = try saver.commit(photo: .solid(10, 10, .red))

        #expect(near(spot.photoTint, 0xFF0000))
        #expect(near(try stored(spot.id)?.photoTint, 0xFF0000))
    }

    // MARK: Controllers' rulings

    /// R-c: a refinement that is already over at commit stores the best fix and geocodes at once.
    @Test func commitAfterGoodFixGeocodesAtOnce() async throws {
        saver.beginCapture()
        location.send(fix(15))
        await settle()
        #expect(!saver.isRefining)

        let spot = try saver.commit(photo: .solid())
        #expect(spot.accuracy == 15)
        #expect(!saver.isRefining)
        await settle()

        #expect(spot.placeName == "Jl. Sudirman")
        #expect(geocoder.calls.count == 1)
        #expect(try stored(spot.id)?.placeName == "Jl. Sudirman")
    }

    /// R-c, time variant: the photo took more than 20 s, so the refinement is over when the spot is committed.
    @Test func commitAfterTwentySecondsDoesNotRefine() async throws {
        saver.beginCapture()
        location.send(fix(35))
        await settle()
        clock.advance(25)

        let spot = try saver.commit(photo: .solid())
        #expect(spot.accuracy == 35)
        #expect(!saver.isRefining)
        await settle()
        #expect(location.subscriberCount == 0)
        #expect(spot.placeName == "Jl. Sudirman")

        location.send(fix(8))
        await settle()
        #expect(spot.accuracy == 35)
    }

    /// Review Focus 5: a place name that arrives after stopRefining() never reaches the spot.
    @Test func placeNameAfterStopIsDiscarded() async throws {
        saver.beginCapture()
        location.send(fix(15))
        await settle()
        let spot = try saver.commit(photo: .solid())   // starts the lookup, which has not run yet

        saver.stopRefining()
        await settle()

        #expect(spot.placeName == nil)
        #expect(try stored(spot.id)?.placeName == nil)
    }

    /// R-o: the repository rolls the failed save back, then the saver removes the photo it just wrote and stops.
    @Test func repositoryFailureDeletesThePhotoAndStops() async throws {
        // A store opened read-only: reading works, so `insertActive` fails only when it saves.
        let store = try FileBackedStore()
        let old = ParkingSpot(createdAt: clock.now.addingTimeInterval(-3600), photoFileName: "old.jpg")
        try SpotRepository(context: store.writable.mainContext, photos: photos).insertActive(old)
        let readOnly = try store.openReadOnly()
        try withExtendedLifetime((store, readOnly)) {
            let failing = AppDependencies.test(location: location, photos: photos, container: readOnly,
                                               geocoder: geocoder, clock: clock)
            let saver = SpotSaver(deps: failing)

            #expect(throws: (any Error).self) { _ = try saver.commit(photo: .solid()) }

            #expect(photos.files.isEmpty)
            #expect(photos.deleted == ["fake-1.jpg"])
            #expect(!saver.isRefining)
            // No ghost spot, and the previous spot keeps its flag: the failed save left nothing behind.
            let spots = try failing.repository.allSpots()
            #expect(spots.map(\.photoFileName) == ["old.jpg"])
            #expect(spots.map(\.isActive) == [true])
            #expect(!readOnly.mainContext.hasChanges)
        }
        await settle()
        #expect(location.subscriberCount == 0)
    }

    /// The consumer and timeout tasks hold the saver weakly, so dropping the saver frees it.
    @Test func runningCaptureDoesNotRetainTheSaver() async throws {
        var owned: SpotSaver? = SpotSaver(deps: deps)
        weak let observed = owned
        owned?.beginCapture()
        await settle()
        #expect(location.subscriberCount == 1)

        owned = nil
        await settle()

        #expect(observed == nil)
    }
}
