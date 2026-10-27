import Testing
import Foundation
@testable import ParkSpot

struct FindDisplayTests {
    let here = Coordinate(latitude: 0, longitude: 0)

    /// A point `m` metres due east of `here`.
    func east(_ m: Double) -> Coordinate { .init(latitude: 0, longitude: m / 111_194.93) }

    func make(savedAcc: Double = 5, currentAcc: Double = 5, metres: Double = 84, heading: Heading? = .init(degrees: 0),
              auth: LocationAuthorization = .authorized, hasFix: Bool = true) -> FindDisplay {
        FindDisplay.make(saved: .init(coordinate: east(metres), accuracy: savedAcc),
                         current: hasFix ? .init(coordinate: here, horizontalAccuracy: currentAcc, timestamp: .now) : nil,
                         heading: heading, authorization: auth)
    }

    /// `worstAccuracy` for `.rough`, nil for every other case.
    func worst(_ display: FindDisplay) -> Double? {
        guard case let .rough(_, worstAccuracy) = display else { return nil }
        return worstAccuracy
    }

    @Test func noSavedLocationIsPhotoOnly() {
        #expect(FindDisplay.make(saved: nil, current: nil, heading: nil, authorization: .authorized) == .photoOnly)
    }
    @Test func deniedAuthorizationIsPhotoOnly() { #expect(make(auth: .denied) == .photoOnly) }
    @Test func noCurrentFixIsLocating() { #expect(make(hasFix: false) == .locating) }
    @Test func savedOver30IsRough() { #expect(worst(make(savedAcc: 31)) == 31) }
    @Test func currentOver30IsRough() { #expect(worst(make(currentAcc: 45)) == 45) }
    @Test func both30IsPrecise() {
        guard case let .precise(d, a) = make(savedAcc: 30, currentAcc: 30) else { Issue.record("not precise"); return }
        #expect(abs(d - 84) < 0.01); #expect(abs(a - 90) < 0.01)
    }
    @Test func under10IsArrived() { #expect(make(metres: 9.9) == .arrived) }
    @Test func justOver10IsNotArrived() { #expect(make(metres: 10.5) != .arrived) }
    @Test func roughWinsOverArrived() { #expect(worst(make(currentAcc: 45, metres: 5)) == 45) }
    @Test func missingHeadingIsNoHeading() { guard case .noHeading = make(heading: nil) else { Issue.record("expected noHeading"); return } }
}

struct WalkProgressTests {
    @Test func halfway() { #expect(WalkProgress.value(current: 42, start: 84) == 0.5) }
    @Test func furtherThanStartIsZero() { #expect(WalkProgress.value(current: 100, start: 84) == 0) }
    @Test func zeroStartIsDone() { #expect(WalkProgress.value(current: 0, start: 0) == 1) }
}

// MARK: - Review Focus 2: location off with no fix must never stick on "Getting your location…"

extension FindDisplayTests {
    @Test func deniedWithoutFixIsPhotoOnly() {
        #expect(make(auth: .denied, hasFix: false) == .photoOnly)
    }
}
