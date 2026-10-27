import Testing
import Foundation
@testable import ParkSpot

struct ThemeTests {
    @Test func specColours() {
        #expect(Theme.Hex.bg == 0x121212)
        #expect(Theme.Hex.accent == 0x1ED760)
        #expect(Theme.Hex.warning == 0xFFA42B)
        #expect(Theme.Hex.negative == 0xF3727F)
        #expect(Theme.Hex.black == 0x000000)
    }
}
