import Foundation
import SwiftData
import Testing
@testable import ParkSpot

@MainActor struct HomeViewModelTests {
    let container = ModelContainer.inMemory()
    let photos = FakePhotoStore()
    let clock = FakeClock()
    let repository: SpotRepository
    let viewModel: HomeViewModel

    init() {
        container.mainContext.autosaveEnabled = false
        repository = SpotRepository(context: container.mainContext, photos: photos)
        viewModel = HomeViewModel(repository: repository)
    }

    func insert(_ name: String, minutesAgo: Double, active: Bool = false, floor: String? = nil) throws {
        let spot = ParkingSpot(createdAt: clock.now.addingTimeInterval(-minutesAgo * 60), photoFileName: "\(name).jpg")
        spot.placeName = name
        spot.floor = floor
        if active { try repository.insertActive(spot) } else { container.mainContext.insert(spot); try repository.save() }
    }

    @Test func recentExcludesActive() throws {
        try insert("Old", minutesAgo: 30)
        try insert("Now", minutesAgo: 1, active: true)

        viewModel.reload()

        #expect(viewModel.recent.map(\.placeName) == ["Old"])
    }

    @Test func recentCappedAtTen() throws {
        for index in 0..<12 {
            try insert("S\(index)", minutesAgo: Double(index + 1))
        }

        viewModel.reload()

        #expect(viewModel.recent.count == 10)
    }

    @Test func mallsFilterApplies() throws {
        try insert("Mall", minutesAgo: 10, floor: "B2")
        try insert("Street", minutesAgo: 20)

        viewModel.filter = .malls
        viewModel.reload()

        #expect(viewModel.recent.map(\.placeName) == ["Mall"])
    }
}
