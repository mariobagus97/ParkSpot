import Testing
import UIKit
@testable import ParkSpot

@MainActor struct PhotoStoreTests {
    let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    @Test func saveThenLoad() throws {
        let s = PhotoStore(directory: dir); let name = try s.save(.solid(100, 50))
        #expect(name.hasSuffix(".jpg")); #expect(s.image(named: name)?.cgImage?.width == 100)
    }
    @Test func largeImageIsDownscaled() throws {
        let s = PhotoStore(directory: dir); let img = s.image(named: try s.save(.solid(4000, 3000)))
        #expect(img?.cgImage?.width == 2048); #expect(img?.cgImage?.height == 1536)
    }
    @Test func missingFileReturnsNil() {
        let s = PhotoStore(directory: dir)
        #expect(s.image(named: "missing.jpg") == nil); #expect(s.thumbnail(named: "missing.jpg", maxPixel: 64) == nil)
    }
    @Test func thumbnailFitsMaxPixel() throws {
        let s = PhotoStore(directory: dir); let name = try s.save(.solid(400, 200))
        let thumb = s.thumbnail(named: name, maxPixel: 64)
        #expect(thumb?.cgImage?.width == 64); #expect(thumb?.cgImage?.height == 32)
    }
    @Test func deleteRemovesFile() throws { let s = PhotoStore(directory: dir); let n = try s.save(.solid()); s.delete(named: n); #expect(s.image(named: n) == nil) }
    @Test func saveThrowsWhenDirectoryIsAFile() throws {
        FileManager.default.createFile(atPath: dir.path, contents: Data("x".utf8))
        #expect(throws: (any Error).self) { try PhotoStore(directory: dir).save(.solid()) }
    }
}
