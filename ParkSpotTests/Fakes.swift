import SwiftData
import UIKit
@testable import ParkSpot

/// In-memory stand-in for the photo directory. `save` hands out `fake-N.jpg` names.
@MainActor final class FakePhotoStore: PhotoStoring {
    var files: [String: UIImage] = [:]
    var deleted: [String] = []
    var failNextSave = false
    private var counter = 0

    func save(_ image: UIImage) throws -> String {
        if failNextSave {
            failNextSave = false
            throw PhotoStoreError.encodingFailed
        }
        counter += 1
        let name = "fake-\(counter).jpg"
        files[name] = image
        return name
    }

    func image(named name: String) -> UIImage? { files[name] }

    func thumbnail(named name: String, maxPixel: Int) -> UIImage? { files[name] }

    func delete(named name: String) {
        deleted.append(name)
        files[name] = nil
    }
}

extension ModelContainer {
    /// A fresh store that lives only in memory, so every test starts empty.
    static func inMemory() -> ModelContainer {
        do {
            return try ModelContainer(for: ParkingSpot.self,
                                      configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        } catch {
            fatalError("Could not create the in-memory container: \(error)")
        }
    }
}
