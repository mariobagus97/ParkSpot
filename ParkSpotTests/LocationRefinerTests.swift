import Testing
import Foundation
@testable import ParkSpot

struct LocationRefinerTests {
    let t0 = Date(timeIntervalSince1970: 1_000_000)
    func fix(_ acc: Double, at s: Double = 0) -> LocationFix {
        .init(coordinate: .init(latitude: 0, longitude: 0), horizontalAccuracy: acc, timestamp: t0.addingTimeInterval(s))
    }
    @Test func lastKnownUnder120sIsUsed() { #expect(LocationRefiner(startedAt: t0, lastKnown: fix(25, at: -119)).best?.horizontalAccuracy == 25) }
    @Test func lastKnownOver120sIsIgnored() { #expect(LocationRefiner(startedAt: t0, lastKnown: fix(25, at: -121)).best == nil) }
    @Test func betterFixReplaces() {
        var r = LocationRefiner(startedAt: t0, lastKnown: nil); _ = r.consider(fix(40))
        let changed = r.consider(fix(15))
        #expect(changed); #expect(r.best?.horizontalAccuracy == 15)
    }
    @Test func worseFixIsIgnored() {
        var r = LocationRefiner(startedAt: t0, lastKnown: nil); _ = r.consider(fix(15))
        let changed = r.consider(fix(40))
        #expect(!changed); #expect(r.best?.horizontalAccuracy == 15)
    }
    @Test func invalidAccuracyIsIgnored() {
        var r = LocationRefiner(startedAt: t0, lastKnown: nil)
        let changed = r.consider(fix(-1))
        #expect(!changed); #expect(r.best == nil)
    }
    @Test func lastKnownAtExactly120sIsIgnored() { #expect(LocationRefiner(startedAt: t0, lastKnown: fix(25, at: -120)).best == nil) }
    @Test func lastKnownWithInvalidAccuracyIsIgnored() { #expect(LocationRefiner(startedAt: t0, lastKnown: fix(-1, at: -10)).best == nil) }
    @Test func equalAccuracyDoesNotReplace() {
        var r = LocationRefiner(startedAt: t0, lastKnown: fix(25, at: -10))
        let changed = r.consider(fix(25, at: 5))
        #expect(!changed); #expect(r.best?.timestamp == t0.addingTimeInterval(-10))
    }
    @Test func finishesAt20Metres() { var r = LocationRefiner(startedAt: t0, lastKnown: nil); _ = r.consider(fix(20)); #expect(r.isFinished(at: t0)) }
    @Test func finishesAfter20Seconds() {
        var r = LocationRefiner(startedAt: t0, lastKnown: nil); _ = r.consider(fix(35))
        #expect(!r.isFinished(at: t0.addingTimeInterval(19.9))); #expect(r.isFinished(at: t0.addingTimeInterval(20)))
    }
}
