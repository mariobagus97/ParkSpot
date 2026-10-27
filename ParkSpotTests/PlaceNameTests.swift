import Testing
@testable import ParkSpot

struct PlaceNameTests {
    @Test func nameWins() { #expect(PlaceName.from(.init(name: "Grand Indonesia", thoroughfare: "Jl. M.H. Thamrin", locality: "Jakarta")) == "Grand Indonesia") }
    @Test func thoroughfareWhenNoName() { #expect(PlaceName.from(.init(name: nil, thoroughfare: "Jl. Sudirman", locality: "Jakarta")) == "Jl. Sudirman") }
    @Test func blankNameIsSkipped() { #expect(PlaceName.from(.init(name: "  ", thoroughfare: nil, locality: "Jakarta")) == "Jakarta") }
    @Test func nothingIsNil() { #expect(PlaceName.from(.init(name: nil, thoroughfare: nil, locality: nil)) == nil) }
}
