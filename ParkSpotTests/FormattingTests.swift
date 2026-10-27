import Testing
import Foundation
@testable import ParkSpot

struct FormattingTests {
    let en = Locale(identifier: "en_US"), id = Locale(identifier: "id_ID")
    @Test func metresUnder1000() { #expect(Formatting.distance(84.4, locale: en) == "84 m"); #expect(Formatting.distance(999.4, locale: en) == "999 m") }
    @Test func kilometresFrom1000() { #expect(Formatting.distance(999.6, locale: en) == "1.0 km"); #expect(Formatting.distance(1234, locale: en) == "1.2 km") }
    @Test func indonesianDecimalComma() { #expect(Formatting.distance(1234, locale: id) == "1,2 km") }
    @Test func roughRoundsToTen() {
        #expect(Formatting.roughDistance(43, locale: en) == "40 m"); #expect(Formatting.roughDistance(45, locale: en) == "50 m")
        #expect(Formatting.roughDistance(3, locale: en) == "10 m")
    }
    @Test func accuracyWholeMetres() { #expect(Formatting.accuracy(12.4, locale: en) == "12 m") }
    @Test func walkMinutes() {
        #expect(Formatting.walkMinutes(84) == 1); #expect(Formatting.walkMinutes(200) == 2)
        #expect(Formatting.walkMinutes(1000) == 12); #expect(Formatting.walkMinutes(5) == 1)
    }
}
