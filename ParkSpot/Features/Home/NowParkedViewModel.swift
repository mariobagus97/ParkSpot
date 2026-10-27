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
    /// True when the spot has no coordinate at all, so the bar can say so instead of showing nothing.
    var hasNoLocation: Bool { spot.savedLocation == nil }

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
        guard task == nil, spot.savedLocation != nil else { return }
        let fixes = location.fixes()
        task = Task { [weak self] in
            for await fix in fixes {
                guard let self, let saved = spot.savedLocation else { return }
                let metres = Geo.distance(from: fix.coordinate, to: saved.coordinate)
                // Roughly the same rule the Find screen uses: a poor fix gets an approximate number.
                let worst = max(saved.accuracy, fix.horizontalAccuracy)
                distanceText = worst > FindDisplay.arrowMaxAccuracy
                    ? String(format: String(localized: "about_fmt"), Formatting.roughDistance(metres, locale: locale))
                    : Formatting.distance(metres, locale: locale)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
