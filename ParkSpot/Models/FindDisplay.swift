import Foundation

enum LocationAuthorization: Sendable {
    case notDetermined, denied, authorized
}

struct SavedLocation: Equatable, Sendable {
    var coordinate: Coordinate
    var accuracy: Double
}

/// What the Find screen shows, decided from the saved spot, the live fix, the compass and the permission.
enum FindDisplay: Equatable, Sendable {
    case precise(distance: Double, relativeAngle: Double)
    case rough(distance: Double, worstAccuracy: Double)
    case arrived
    case noHeading(distance: Double)
    case locating
    case photoOnly

    /// The arrow is shown only when both accuracies are at most this many metres.
    static let arrowMaxAccuracy = 30.0
    /// Closer than this many metres counts as arrived.
    static let arrivalDistance = 10.0

    static func make(saved: SavedLocation?, current: LocationFix?, heading: Heading?,
                     authorization: LocationAuthorization) -> FindDisplay {
        guard let saved, authorization != .denied else { return .photoOnly }
        guard let current else { return .locating }

        let distance = Geo.distance(from: current.coordinate, to: saved.coordinate)
        let worst = max(saved.accuracy, current.horizontalAccuracy)
        if worst > arrowMaxAccuracy { return .rough(distance: distance, worstAccuracy: worst) }
        if distance < arrivalDistance { return .arrived }
        guard let heading else { return .noHeading(distance: distance) }

        let bearing = Geo.bearing(from: current.coordinate, to: saved.coordinate)
        return .precise(distance: distance, relativeAngle: Geo.relativeAngle(bearing: bearing, heading: heading.degrees))
    }
}

enum WalkProgress: Sendable {
    /// Share of the walk already done: `1 − current/start`, clamped to 0…1. A start of 0 or less counts as done.
    static func value(current: Double, start: Double) -> Double {
        guard start > 0 else { return 1 }
        return min(max(1 - current / start, 0), 1)
    }
}
