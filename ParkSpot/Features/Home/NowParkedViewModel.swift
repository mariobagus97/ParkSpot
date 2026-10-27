import Foundation
import Observation

/// The strip above the tab bar while a spot is active: how far the car is and when it was saved.
@MainActor @Observable final class NowParkedViewModel {
    private static let relative = RelativeDateTimeFormatter()

    private let spot: ParkingSpot
    private let location: LocationProviding
    private let now: () -> Date
    private let locale = Locale.current

    private var task: Task<Void, Never>?

    private(set) var distanceText: String?

    init(spot: ParkingSpot, location: LocationProviding, now: @escaping () -> Date) {
        self.spot = spot
        self.location = location
        self.now = now
    }

    var savedAgoText: String {
        let formatter = Self.relative
        formatter.locale = locale
        formatter.unitsStyle = .abbreviated
        let relative = formatter.localizedString(for: spot.createdAt, relativeTo: now())
        return String(format: String(localized: "saved_ago_fmt"), relative)
    }

    func start() {
        guard task == nil, let saved = spot.savedLocation else { return }
        let fixes = location.fixes()
        task = Task { [weak self] in
            for await fix in fixes {
                guard let self else { return }
                distanceText = Formatting.distance(Geo.distance(from: fix.coordinate, to: saved.coordinate),
                                                   locale: locale)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
