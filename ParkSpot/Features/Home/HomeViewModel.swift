import Foundation
import Observation

/// The recent spots shelf on Home, filtered by the chips.
@MainActor @Observable final class HomeViewModel {
    static let recentLimit = 10

    private let repository: SpotRepository

    var filter: SpotFilter = .all
    private(set) var recent: [ParkingSpot] = []

    init(repository: SpotRepository) {
        self.repository = repository
    }

    func reload() {
        let spots = (try? repository.recentInactive(limit: Self.recentLimit)) ?? []
        recent = filter.apply(to: spots, query: "")
    }
}
