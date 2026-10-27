import Foundation

struct Coordinate: Equatable, Hashable, Sendable {
    var latitude: Double
    var longitude: Double
}

struct LocationFix: Equatable, Sendable {
    var coordinate: Coordinate
    var horizontalAccuracy: Double
    var timestamp: Date
}

/// Compass heading in degrees, 0..<360, relative to true north when available.
struct Heading: Equatable, Sendable {
    var degrees: Double
}
