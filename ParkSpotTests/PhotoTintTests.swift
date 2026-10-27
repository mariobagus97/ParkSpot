import Testing
import UIKit
@testable import ParkSpot

struct PhotoTintTests {
    @Test func solidRed() { #expect(near(PhotoTint.average(of: .solid(10, 10, .red)), 0xFF0000)) }
    @Test func solidAccent() { #expect(near(PhotoTint.average(of: .solid(10, 10, UIColor(red: 0x1E/255, green: 0xD7/255, blue: 0x60/255, alpha: 1))), 0x1ED760)) }
}
