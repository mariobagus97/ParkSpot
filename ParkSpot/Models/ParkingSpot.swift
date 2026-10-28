import Foundation
import SwiftData

enum SpotKind: Sendable {
    case mall, street
}

/// One saved parking spot. At most one spot is active at a time; `SpotRepository` keeps it that way.
@Model final class ParkingSpot {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var latitude: Double?
    var longitude: Double?
    var accuracy: Double?
    var photoFileName: String
    var floor: String?
    var note: String?
    /// Raw `Vehicle` value. Optional so spots saved before vehicles existed still open, as cars.
    var vehicle: String?
    var placeName: String?
    /// Average photo colour as 0xRRGGBB.
    var photoTint: Int?
    var isActive: Bool

    init(id: UUID = UUID(), createdAt: Date, photoFileName: String) {
        self.id = id
        self.createdAt = createdAt
        self.photoFileName = photoFileName
        self.isActive = false
    }

    /// The vehicle that was parked, defaulting to a car.
    var vehicleKind: Vehicle {
        get { Vehicle(stored: vehicle) }
        set { vehicle = newValue.rawValue }
    }

    /// Nil unless latitude, longitude and accuracy are all set.
    var savedLocation: SavedLocation? {
        guard let latitude, let longitude, let accuracy else { return nil }
        return SavedLocation(coordinate: Coordinate(latitude: latitude, longitude: longitude), accuracy: accuracy)
    }

    /// A spot with a floor is in a mall; one without is on the street.
    var kind: SpotKind { floor == nil ? .street : .mall }

    /// Sets or clears latitude, longitude and accuracy together.
    func setLocation(_ fix: LocationFix?) {
        latitude = fix?.coordinate.latitude
        longitude = fix?.coordinate.longitude
        accuracy = fix?.horizontalAccuracy
    }
}
