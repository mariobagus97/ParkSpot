import Foundation
import SwiftData

/// Reads and writes parking spots. Keeps at most one spot active (R2) and every mutator saves.
@MainActor final class SpotRepository {
    private let context: ModelContext
    private let photos: PhotoStoring

    init(context: ModelContext, photos: PhotoStoring) {
        self.context = context
        self.photos = photos
    }

    func activeSpot() throws -> ParkingSpot? {
        var descriptor = FetchDescriptor<ParkingSpot>(predicate: #Predicate { $0.isActive == true },
                                                      sortBy: [Self.newestFirst])
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// The active spot first, then the rest, newest first.
    func allSpots() throws -> [ParkingSpot] {
        let spots = try context.fetch(FetchDescriptor<ParkingSpot>(sortBy: [Self.newestFirst]))
        return spots.filter(\.isActive) + spots.filter { !$0.isActive }
    }

    /// Up to `limit` spots that are not active, newest first.
    func recentInactive(limit: Int) throws -> [ParkingSpot] {
        var descriptor = FetchDescriptor<ParkingSpot>(predicate: #Predicate { $0.isActive == false },
                                                      sortBy: [Self.newestFirst])
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    func spot(id: UUID) throws -> ParkingSpot? {
        var descriptor = FetchDescriptor<ParkingSpot>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// Stores `spot` as the active one; the previously active spot becomes inactive.
    func insertActive(_ spot: ParkingSpot) throws {
        try deactivateAll(except: spot)
        spot.isActive = true
        context.insert(spot)
        try save()
    }

    /// Makes `spot` the active one; the previously active spot becomes inactive.
    func activate(_ spot: ParkingSpot) throws {
        try deactivateAll(except: spot)
        spot.isActive = true
        try save()
    }

    func endSession(_ spot: ParkingSpot) throws {
        spot.isActive = false
        try save()
    }

    /// Removes the photo file first, then the record.
    func delete(_ spot: ParkingSpot) throws {
        photos.delete(named: spot.photoFileName)
        context.delete(spot)
        try save()
    }

    func save() throws {
        try context.save()
    }

    private static let newestFirst = SortDescriptor(\ParkingSpot.createdAt, order: .reverse)

    private func deactivateAll(except spot: ParkingSpot) throws {
        let active = try context.fetch(FetchDescriptor<ParkingSpot>(predicate: #Predicate { $0.isActive == true }))
        for other in active where other.id != spot.id {
            other.isActive = false
        }
    }
}
