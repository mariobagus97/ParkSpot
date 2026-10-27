import Foundation
import SwiftData
import Testing
@testable import ParkSpot

@MainActor struct HistoryViewModelTests {
    let container = ModelContainer.inMemory()
    let photos = FakePhotoStore()
    let clock = FakeClock()
    let repository: SpotRepository
    let viewModel: HistoryViewModel

    init() {
        container.mainContext.autosaveEnabled = false
        repository = SpotRepository(context: container.mainContext, photos: photos)
        viewModel = HistoryViewModel(repository: repository)
    }

    @discardableResult
    func insert(_ name: String, minutesAgo: Double, active: Bool = false, floor: String? = nil, note: String? = nil) throws -> ParkingSpot {
        let spot = ParkingSpot(createdAt: clock.now.addingTimeInterval(-minutesAgo * 60), photoFileName: "\(name).jpg")
        spot.placeName = name
        spot.floor = floor
        spot.note = note
        if active { try repository.insertActive(spot) } else { container.mainContext.insert(spot); try repository.save() }
        return spot
    }

    @Test func rowsActiveFirst() throws {
        try insert("Old", minutesAgo: 30)
        try insert("Now", minutesAgo: 1, active: true)

        viewModel.reload()

        #expect(viewModel.rows.map(\.placeName) == ["Now", "Old"])
    }

    @Test func searchFilters() throws {
        try insert("Mall", minutesAgo: 10, floor: "B2", note: "Dekat lift biru")
        try insert("Street", minutesAgo: 20, note: "Samping warung")

        viewModel.search("  lift  ")

        #expect(viewModel.rows.map(\.placeName) == ["Mall"])
    }

    @Test func rowWithMissingPhotoStillListed() throws {
        try insert("NoPhoto", minutesAgo: 5)

        viewModel.reload()

        #expect(viewModel.rows.count == 1)
        #expect(photos.image(named: "NoPhoto.jpg") == nil)
    }
}
