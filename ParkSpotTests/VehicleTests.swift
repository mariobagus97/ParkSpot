import Foundation
import SwiftData
import Testing
@testable import ParkSpot

@MainActor struct VehicleTests {
    let container = ModelContainer.inMemory()
    let photos = FakePhotoStore()
    let clock = FakeClock()
    var repository: SpotRepository { SpotRepository(context: container.mainContext, photos: photos) }

    @Test func missingValueIsACar() {
        // Spots saved before vehicles existed have no value.
        #expect(Vehicle(stored: nil) == .car)
        #expect(Vehicle(stored: "spaceship") == .car)
    }

    @Test func roundTripsThroughTheStoredString() {
        let spot = ParkingSpot(createdAt: clock.now, photoFileName: "a.jpg")
        #expect(spot.vehicleKind == .car)

        spot.vehicleKind = .bike

        #expect(spot.vehicle == "bike")
        #expect(spot.vehicleKind == .bike)
    }

    @Test func everyVehicleHasANameInBothLanguages() {
        for vehicle in Vehicle.allCases {
            #expect(!vehicle.name.isEmpty)
        }
    }

    @Test func lastUsedVehicleIsTheNewestSpots() throws {
        let older = ParkingSpot(createdAt: clock.now.addingTimeInterval(-600), photoFileName: "old.jpg")
        older.vehicleKind = .bike
        let newer = ParkingSpot(createdAt: clock.now, photoFileName: "new.jpg")
        newer.vehicleKind = .motorbike
        container.mainContext.insert(older)
        container.mainContext.insert(newer)
        try repository.save()

        #expect(try repository.lastUsedVehicle() == .motorbike)
    }

    @Test func lastUsedVehicleIsNilWithNoSpots() throws {
        #expect(try repository.lastUsedVehicle() == nil)
    }
}
