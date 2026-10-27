import Testing
import Foundation
@testable import ParkSpot

struct GeoTests {
    let origin = Coordinate(latitude: 0, longitude: 0)
    @Test func oneDegreeAlongEquator() {
        #expect(abs(Geo.distance(from: origin, to: .init(latitude: 0, longitude: 1)) - 111_194.93) < 0.5)
    }
    @Test func shortDistanceInJakarta() {
        let d = Geo.distance(from: .init(latitude: -6.2, longitude: 106.8166), to: .init(latitude: -6.2, longitude: 106.8174))
        #expect(abs(d - 88.44) < 0.1)
    }
    @Test func bearingEastIs90() { #expect(abs(Geo.bearing(from: origin, to: .init(latitude: 0, longitude: 1)) - 90) < 1e-6) }
    @Test func bearingNorthIs0() { #expect(abs(Geo.bearing(from: origin, to: .init(latitude: 1, longitude: 0))) < 1e-6) }
    @Test func bearingSouthWest() { #expect(abs(Geo.bearing(from: origin, to: .init(latitude: -1, longitude: -1)) - 224.9956) < 0.001) }
    @Test(arguments: [(90.0, 0.0, 90.0), (10, 350, 20), (350, 10, -20), (180, 0, 180), (0, 180, 180), (0, 0, 0)])
    func relativeAngle(_ c: (Double, Double, Double)) { #expect(abs(Geo.relativeAngle(bearing: c.0, heading: c.1) - c.2) < 1e-9) }
    @Test(arguments: [(350.0, 10.0, 370.0), (10, 350, -10), (720, 0, 720)])
    func unwrapTakesShortestTurn(_ c: (Double, Double, Double)) { #expect(abs(Geo.unwrap(previous: c.0, target: c.1) - c.2) < 1e-9) }
    @Test(arguments: [(0.0, DirectionPhrase.ahead), (20, .ahead), (21, .aheadRight), (70, .aheadRight), (71, .right), (135, .right),
                      (136, .behind), (180, .behind), (-20, .ahead), (-21, .aheadLeft), (-70, .aheadLeft), (-71, .left), (-135, .left), (-136, .behind)])
    func directionSectors(_ c: (Double, DirectionPhrase)) { #expect(DirectionPhrase(relativeAngle: c.0) == c.1) }
}
