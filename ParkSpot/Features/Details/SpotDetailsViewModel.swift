import Foundation
import Observation

/// State of the "Spot saved" sheet: the optional floor and note, and what the GPS is still doing.
@MainActor @Observable final class SpotDetailsViewModel {
    static let quickFloors = ["B3", "B2", "B1", "G", "1", "2"]   // "+" opens 3…10 and a free-text field
    static let moreFloors = (3...10).map(String.init)
    static let noteLimit = 140

    /// The spot being described; the sheet reads its photo and (once it is looked up) its place name.
    let spot: ParkingSpot
    /// What was parked. Starts from this spot, else the previous spot's vehicle, else a car.
    private(set) var vehicle: Vehicle
    private(set) var floor: String?
    /// What the "+" panel's text field shows, exactly as typed. It lives here, not in the view, so a quick-floor
    /// tap empties it in the same step that selects the chip; `setTypedFloor(_:)` is the only way to change it.
    private(set) var typedFloor = ""
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
        vehicle = spot.vehicle == nil
            ? ((try? repository.lastUsedVehicle()) ?? .car)
            : spot.vehicleKind
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

    /// Picks a floor; picking the selected one again clears it. Also empties the free-text field, so the chip and
    /// the typed text never both claim to be the floor.
    /// Collapsing the "+" panel drops a floor that came from the text field, which is now out of sight.
    /// A floor picked from the always-visible quick chips stays.
    func clearTypedFloor() {
        if floor == typedFloor { floor = nil }
        typedFloor = ""
    }

    /// Picks the vehicle. There is always one selected, so tapping the current one keeps it.
    func selectVehicle(_ value: Vehicle) {
        vehicle = value
    }

    func selectFloor(_ value: String) {
        typedFloor = ""
        floor = floor == value ? nil : value
    }

    /// The free-text field: its trimmed text is the floor, blank clears it. `typedFloor` keeps the text as typed.
    func setTypedFloor(_ text: String) {
        typedFloor = text
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        floor = trimmed.isEmpty ? nil : trimmed
    }

    /// Writes floor and note to the spot (a blank note is none) and saves.
    func done() throws {
        spot.vehicleKind = vehicle
        spot.floor = floor
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        spot.note = trimmed.isEmpty ? nil : trimmed
        try repository.save()
    }
}
