import Foundation
import Observation

/// State of the "Spot saved" sheet: the optional floor and note, and what the GPS is still doing.
@MainActor @Observable final class SpotDetailsViewModel {
    static let quickFloors = ["B3", "B2", "B1", "G", "1", "2"]   // "+" opens 3…10 and a free-text field
    static let moreFloors = (3...10).map(String.init)
    static let noteLimit = 140

    /// The spot being described; the sheet reads its photo and (once it is looked up) its place name.
    let spot: ParkingSpot
    private(set) var floor: String?
    /// Never longer than `noteLimit` characters: what is typed past it is dropped.
    var note: String {
        didSet {
            if note.count > Self.noteLimit { note = String(note.prefix(Self.noteLimit)) }
        }
    }

    @ObservationIgnored private let saver: SpotSaver
    @ObservationIgnored private let repository: SpotRepository
    @ObservationIgnored private let location: LocationProviding

    init(spot: ParkingSpot, saver: SpotSaver, repository: SpotRepository, location: LocationProviding) {
        self.spot = spot
        self.saver = saver
        self.repository = repository
        self.location = location
        floor = spot.floor
        note = spot.note ?? ""
    }

    /// "Sharpening GPS… ±12 m" while the position is still improving. Nil without a first fix, as there is no
    /// accuracy to show, and nil while location is off, where the location note speaks instead.
    var refiningText: String? {
        guard saver.isRefining, !locationOff, let accuracy = saver.currentAccuracy else { return nil }
        return String(format: String(localized: "improving_fmt"), Formatting.accuracy(accuracy, locale: .current))
    }

    /// Location permission is denied: the sheet explains that the spot is saved without a position.
    var locationOff: Bool { location.authorization == .denied }

    /// Picks a floor; picking the selected one again clears it.
    func selectFloor(_ value: String) {
        floor = floor == value ? nil : value
    }

    /// The free-text field: its trimmed text is the floor, blank clears it.
    func setTypedFloor(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        floor = trimmed.isEmpty ? nil : trimmed
    }

    /// Writes floor and note to the spot (a blank note is none) and saves.
    func done() throws {
        spot.floor = floor
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        spot.note = trimmed.isEmpty ? nil : trimmed
        try repository.save()
    }
}
