import Foundation
import Testing
@testable import ParkSpot

@MainActor struct SpotFilterTests {
    func spot(_ file: String, floor: String? = nil, placeName: String? = nil, note: String? = nil) -> ParkingSpot {
        let s = ParkingSpot(createdAt: Date(timeIntervalSince1970: 1_800_000_000), photoFileName: file)
        s.floor = floor; s.placeName = placeName; s.note = note
        return s
    }

    @Test func keysAreStable() {
        #expect(SpotFilter.allCases.map(\.key) == ["all", "malls", "streets"])
    }

    @Test func allKeepsEverySpot() {
        let spots = [spot("a", floor: "B2"), spot("b")]
        #expect(SpotFilter.all.apply(to: spots, query: "").map(\.photoFileName) == ["a", "b"])
    }

    @Test func mallsKeepsSpotsWithFloor() {
        let spots = [spot("a", floor: "B2"), spot("b"), spot("c", floor: "P5")]
        #expect(SpotFilter.malls.apply(to: spots, query: "").map(\.photoFileName) == ["a", "c"])
    }

    @Test func streetsKeepsSpotsWithoutFloor() {
        let spots = [spot("a", floor: "B2"), spot("b"), spot("c", floor: "P5"), spot("d")]
        #expect(SpotFilter.streets.apply(to: spots, query: "").map(\.photoFileName) == ["b", "d"])
    }

    @Test func searchIgnoresCaseAndDiacritics() {
        let spots = [spot("a", floor: "B2", placeName: "Plaza Sénayan", note: "Dekat LIFT biru"),
                     spot("b", placeName: "Jalan Sudirman", note: "depan toko roti"),
                     spot("c")]
        #expect(SpotFilter.all.apply(to: spots, query: "lift").map(\.photoFileName) == ["a"])
        #expect(SpotFilter.all.apply(to: spots, query: "senayan").map(\.photoFileName) == ["a"])
        #expect(SpotFilter.all.apply(to: spots, query: "SUDIRMAN").map(\.photoFileName) == ["b"])
        #expect(SpotFilter.all.apply(to: spots, query: "nothing like this").isEmpty)
        #expect(SpotFilter.all.apply(to: spots, query: "").map(\.photoFileName) == ["a", "b", "c"])
    }

    @Test func searchAppliesWithinTheKindFilter() {
        let spots = [spot("a", floor: "B2", note: "near the lift"), spot("b", note: "lift lobby side")]
        #expect(SpotFilter.malls.apply(to: spots, query: "lift").map(\.photoFileName) == ["a"])
        #expect(SpotFilter.streets.apply(to: spots, query: "lift").map(\.photoFileName) == ["b"])
    }
}
