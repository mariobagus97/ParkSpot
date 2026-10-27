import Foundation
import SwiftData
import Testing
@testable import ParkSpot

@MainActor struct SpotRepositoryTests {
    let container = ModelContainer.inMemory()
    let photos = FakePhotoStore()
    var repo: SpotRepository { SpotRepository(context: container.mainContext, photos: photos) }

    func spot(_ file: String, minutesAgo: Double = 0, floor: String? = nil) -> ParkingSpot {
        let s = ParkingSpot(createdAt: Date(timeIntervalSince1970: 1_800_000_000).addingTimeInterval(-minutesAgo * 60),
                            photoFileName: file)
        s.floor = floor
        return s
    }

    @Test func insertActiveDeactivatesPrevious() throws {
        let a = spot("a"), b = spot("b"); try repo.insertActive(a); try repo.insertActive(b)
        #expect(try repo.activeSpot()?.id == b.id); #expect(a.isActive == false)
    }

    @Test func insertActiveMarksTheNewSpotActive() throws {
        let a = spot("a"); try repo.insertActive(a)
        #expect(a.isActive == true); #expect(try repo.activeSpot()?.id == a.id)
    }

    @Test func activateKeepsOneActive() throws {
        let a = spot("a", minutesAgo: 10), b = spot("b")
        try repo.insertActive(a); try repo.insertActive(b)
        try repo.activate(a)
        let active = try repo.allSpots().filter(\.isActive)
        #expect(active.map(\.id) == [a.id]); #expect(a.isActive == true); #expect(b.isActive == false)
        #expect(try repo.activeSpot()?.id == a.id)
    }

    @Test func endSessionClearsActive() throws {
        let a = spot("a"); try repo.insertActive(a)
        try repo.endSession(a)
        #expect(a.isActive == false); #expect(try repo.activeSpot() == nil)
        #expect(try repo.allSpots().count == 1)
    }

    @Test func deleteRemovesPhotoFile() throws {
        let a = spot("a.jpg"); try repo.insertActive(a); try repo.delete(a)
        #expect(photos.deleted == ["a.jpg"]); #expect(try repo.allSpots().isEmpty)
    }

    @Test func deleteLeavesOtherSpotsAndTheirPhotos() throws {
        let a = spot("a.jpg", minutesAgo: 5), b = spot("b.jpg")
        try repo.insertActive(a); try repo.insertActive(b)
        try repo.delete(a)
        #expect(photos.deleted == ["a.jpg"]); #expect(try repo.allSpots().map(\.id) == [b.id])
    }

    @Test func allSpotsActiveFirstThenNewest() throws {
        let a = spot("a", minutesAgo: 30), b = spot("b", minutesAgo: 10)
        let c = spot("c", minutesAgo: 20), d = spot("d", minutesAgo: 5)
        for s in [a, b, c, d] { try repo.insertActive(s) }
        try repo.activate(c)   // active, but neither the newest nor the oldest
        #expect(try repo.allSpots().map(\.photoFileName) == ["c", "d", "b", "a"])
    }

    @Test func recentInactiveExcludesActiveAndRespectsLimit() throws {
        let inactive = (1...12).map { spot("s\($0)", minutesAgo: Double($0)) }
        for s in inactive { try repo.insertActive(s); try repo.endSession(s) }
        let active = spot("active")   // the newest of all, so it would lead if it weren't excluded
        try repo.insertActive(active)
        let recent = try repo.recentInactive(limit: 10)
        #expect(recent.count == 10); #expect(recent.contains { $0.isActive } == false)
        #expect(recent.map(\.photoFileName) == (1...10).map { "s\($0)" })
    }

    @Test func spotByID() throws {
        let a = spot("a"); try repo.insertActive(a)
        #expect(try repo.spot(id: a.id)?.photoFileName == "a"); #expect(try repo.spot(id: UUID()) == nil)
    }

    @Test func mutatorsSaveToTheStore() throws {
        let other = ModelContext(container)   // a second context sees only what was saved
        let a = spot("a"), b = spot("b", minutesAgo: 5)
        try repo.insertActive(b); try repo.insertActive(a)
        #expect(try other.fetch(FetchDescriptor<ParkingSpot>(predicate: #Predicate { $0.isActive })).map(\.photoFileName) == ["a"])
        try repo.activate(b)
        #expect(try other.fetch(FetchDescriptor<ParkingSpot>(predicate: #Predicate { $0.isActive })).map(\.photoFileName) == ["b"])
        try repo.endSession(b)
        #expect(try other.fetch(FetchDescriptor<ParkingSpot>(predicate: #Predicate { $0.isActive })).isEmpty)
        try repo.delete(a)
        #expect(try other.fetch(FetchDescriptor<ParkingSpot>()).map(\.photoFileName) == ["b"])
    }

    @Test func savedLocationNeedsAllThreeValues() {
        let s = spot("a"); s.latitude = 1; s.longitude = 2; #expect(s.savedLocation == nil)
        s.accuracy = 5; #expect(s.savedLocation?.accuracy == 5)
    }

    @Test func setLocationSetsAndClearsAllThree() {
        let s = spot("a")
        s.setLocation(LocationFix(coordinate: Coordinate(latitude: -6.2, longitude: 106.8), horizontalAccuracy: 12, timestamp: Date()))
        #expect(s.latitude == -6.2); #expect(s.longitude == 106.8); #expect(s.accuracy == 12)
        #expect(s.savedLocation == SavedLocation(coordinate: Coordinate(latitude: -6.2, longitude: 106.8), accuracy: 12))
        s.setLocation(nil)
        #expect(s.latitude == nil); #expect(s.longitude == nil); #expect(s.accuracy == nil); #expect(s.savedLocation == nil)
    }

    @Test func newSpotStartsInactiveWithoutOptionals() {
        let s = spot("a")
        #expect(s.isActive == false)
        #expect(s.latitude == nil); #expect(s.longitude == nil); #expect(s.accuracy == nil)
        #expect(s.floor == nil); #expect(s.note == nil); #expect(s.placeName == nil); #expect(s.photoTint == nil)
    }

    @Test func kindFollowsFloor() { #expect(spot("a", floor: "B2").kind == .mall); #expect(spot("b").kind == .street) }
}
