import Foundation
import Observation

/// What the Find screen shows right now, and what it says out loud.
///
/// The rules live in `FindDisplay.make`; this type only feeds it the saved spot, the live fix, the compass
/// and the permission, and turns the answer into the strings the screen renders.
@MainActor @Observable final class FindViewModel {
    private let saved: SavedLocation?
    private let location: LocationProviding
    private let locale = Locale.current

    /// The current state of the screen. Starts from the saved spot's own data, so a spot without coordinates
    /// is `photoOnly` before any fix arrives.
    private(set) var display: FindDisplay
    /// Share of the walk already done, from the first distance seen after `start()`.
    private(set) var progress = 0.0
    /// Cumulative arrow rotation, unwrapped so it always turns the short way.
    private(set) var arrowAngle = 0.0

    private var current: LocationFix?
    private var heading: Heading?
    private var startDistance: Double?
    private var tasks: [Task<Void, Never>] = []

    init(spot: ParkingSpot, location: LocationProviding) {
        self.saved = spot.savedLocation
        self.location = location
        display = FindDisplay.make(saved: spot.savedLocation, current: nil, heading: nil,
                                   authorization: location.authorization)
    }

    /// The direction phrase, only while the arrow is shown.
    var direction: DirectionPhrase? {
        guard case let .precise(_, angle) = display else { return nil }
        return DirectionPhrase(relativeAngle: angle)
    }

    /// Current GPS accuracy for the chip, as whole metres.
    var accuracyText: String? {
        let accuracy: Double? = switch display {
        case let .rough(_, worst): worst
        case .precise: current?.horizontalAccuracy
        default: nil
        }
        guard let accuracy else { return nil }
        return Formatting.accuracy(accuracy, locale: locale)
    }

    /// One sentence for VoiceOver: the distance and the direction, or the state's own copy.
    var accessibilityText: String {
        let key: String = switch display {
        case .precise: "dir_ahead"
        case .rough: "photo_only"
        case .arrived: "arrived"
        case .noHeading: "calibrate"
        case .locating: "locating"
        case .photoOnly: "photo_only"
        }
        switch display {
        case let .precise(distance, _):
            let spoken = direction.map { copy($0.key) } ?? copy(key)
            return "\(Formatting.distance(distance, locale: locale)), \(spoken)"
        case let .rough(distance, _):
            return copy("rough_fmt", Formatting.roughDistance(distance, locale: locale))
        case let .noHeading(distance):
            return "\(Formatting.distance(distance, locale: locale)). \(copy(key))"
        default:
            return copy(key)
        }
    }

    /// Distance text for the big number: whole metres, or an approximation while the fix is rough.
    var distanceText: String? {
        switch display {
        case let .precise(distance, _): Formatting.distance(distance, locale: locale)
        case let .noHeading(distance): Formatting.distance(distance, locale: locale)
        case let .rough(distance, _): copy("about_fmt", Formatting.roughDistance(distance, locale: locale))
        default: nil
        }
    }

    func start() {
        guard tasks.isEmpty else { return }
        // Subscribe before the task runs: an AsyncStream buffers, so a fix sent right after `start()` is not lost.
        let fixes = location.fixes()
        let headings = location.headings()
        tasks.append(Task { [weak self] in
            guard let self, location.authorization == .notDetermined else { return }
            _ = await location.requestAuthorization()
            refresh()
        })
        tasks.append(Task { [weak self] in
            guard let self else { return }
            for await fix in fixes { receive(fix) }
        })
        tasks.append(Task { [weak self] in
            guard let self else { return }
            for await value in headings { receive(heading: value) }
        })
    }

    func stop() {
        for task in tasks { task.cancel() }
        tasks.removeAll()
    }

    private func receive(_ fix: LocationFix) {
        current = fix
        refresh()
    }

    private func receive(heading value: Heading?) {
        heading = value
        refresh()
    }

    private func refresh() {
        let next = FindDisplay.make(saved: saved, current: current, heading: heading,
                                    authorization: location.authorization)
        display = next
        if case let .precise(_, angle) = next {
            arrowAngle = Geo.unwrap(previous: arrowAngle, target: angle)
        }
        guard let saved, let current else { return }
        let distance = Geo.distance(from: current.coordinate, to: saved.coordinate)
        if startDistance == nil { startDistance = distance }
        if let startDistance {
            progress = WalkProgress.value(current: distance, start: startDistance)
        }
    }

    private func copy(_ key: String) -> String {
        String(localized: String.LocalizationValue(key))
    }

    private func copy(_ key: String, _ argument: String) -> String {
        String(format: String(localized: String.LocalizationValue(key)), argument)
    }
}
