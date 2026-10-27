import Foundation

/// Decides which GPS fix to keep after "Park here" and when to stop refining.
struct LocationRefiner: Sendable {
    static let maxDuration: TimeInterval = 20
    static let goodEnough = 20.0
    static let maxLastKnownAge: TimeInterval = 120

    let startedAt: Date
    private(set) var best: LocationFix?

    /// Keeps `lastKnown` only if it is under `maxLastKnownAge` old at `startedAt` and has a valid accuracy.
    init(startedAt: Date, lastKnown: LocationFix?) {
        self.startedAt = startedAt
        if let lastKnown,
           lastKnown.horizontalAccuracy >= 0,
           startedAt.timeIntervalSince(lastKnown.timestamp) < Self.maxLastKnownAge {
            best = lastKnown
        }
    }

    /// Returns true when `best` changed. A strictly lower accuracy wins; a negative accuracy is invalid and ignored.
    mutating func consider(_ fix: LocationFix) -> Bool {
        guard fix.horizontalAccuracy >= 0 else { return false }
        if let best, fix.horizontalAccuracy >= best.horizontalAccuracy { return false }
        best = fix
        return true
    }

    /// True once the best fix is good enough, or `maxDuration` has passed since `startedAt`.
    func isFinished(at now: Date) -> Bool {
        if let best, best.horizontalAccuracy <= Self.goodEnough { return true }
        return now.timeIntervalSince(startedAt) >= Self.maxDuration
    }
}
