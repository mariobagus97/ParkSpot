import Foundation
import Observation

/// Your spots: every saved spot, filtered by the chips and the search field.
@MainActor @Observable final class HistoryViewModel {
    private let repository: SpotRepository

    var filter: SpotFilter = .all
    private(set) var query = ""
    private(set) var rows: [ParkingSpot] = []

    init(repository: SpotRepository) {
        self.repository = repository
    }

    func search(_ text: String) {
        query = text
        reload()
    }

    func reload() {
        let spots = (try? repository.allSpots()) ?? []
        // Trimmed, because the filter treats a space as a real query.
        rows = filter.apply(to: spots, query: query.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
