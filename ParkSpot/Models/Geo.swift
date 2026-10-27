import Foundation

enum Geo {
    static let earthRadius = 6_371_000.0

    /// Great-circle distance in metres (haversine).
    static func distance(from: Coordinate, to: Coordinate) -> Double {
        let phi1 = radians(from.latitude), phi2 = radians(to.latitude)
        let dPhi = phi2 - phi1
        let dLambda = radians(to.longitude - from.longitude)
        let a = sin(dPhi / 2) * sin(dPhi / 2) + cos(phi1) * cos(phi2) * sin(dLambda / 2) * sin(dLambda / 2)
        return earthRadius * 2 * atan2(a.squareRoot(), (1 - a).squareRoot())
    }

    /// Initial bearing from `from` to `to` in degrees, 0..<360 (0 = north, 90 = east).
    static func bearing(from: Coordinate, to: Coordinate) -> Double {
        let phi1 = radians(from.latitude), phi2 = radians(to.latitude)
        let dLambda = radians(to.longitude - from.longitude)
        let y = sin(dLambda) * cos(phi2)
        let x = cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(dLambda)
        let degrees = atan2(y, x) * 180 / .pi
        return fmod(degrees + 360, 360)
    }

    /// `bearing − heading`, normalised to (−180, 180]. Positive means the target is to the right.
    static func relativeAngle(bearing: Double, heading: Double) -> Double {
        var angle = fmod(bearing - heading, 360)
        if angle > 180 { angle -= 360 }
        if angle <= -180 { angle += 360 }
        return angle
    }

    /// `target` expressed as an unbounded angle that is the shortest turn from `previous`,
    /// so a rotating arrow never spins the long way round at the 0/360 seam.
    static func unwrap(previous: Double, target: Double) -> Double {
        previous + relativeAngle(bearing: target, heading: previous)
    }

    private static func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }
}

enum DirectionPhrase: Sendable, CaseIterable {
    case ahead, aheadRight, right, behind, left, aheadLeft

    /// Sectors by relative angle: |a| ≤ 20 ahead, ≤ 70 slightly to a side, ≤ 135 to a side, otherwise behind.
    init(relativeAngle: Double) {
        let magnitude = abs(relativeAngle)
        let isRight = relativeAngle > 0
        switch magnitude {
        case ...20: self = .ahead
        case ...70: self = isRight ? .aheadRight : .aheadLeft
        case ...135: self = isRight ? .right : .left
        default: self = .behind
        }
    }

    /// Localizable.xcstrings key.
    var key: String {
        switch self {
        case .ahead: "dir_ahead"
        case .aheadRight: "dir_ahead_right"
        case .right: "dir_right"
        case .behind: "dir_behind"
        case .left: "dir_left"
        case .aheadLeft: "dir_ahead_left"
        }
    }
}
