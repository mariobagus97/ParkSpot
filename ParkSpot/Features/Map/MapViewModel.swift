import Foundation
import Observation

/// The map's numbers: how far the car is, how long the walk takes, and how good the fix is.
@MainActor @Observable final class MapViewModel {
    private let spot: ParkingSpot
    private let location: LocationProviding
    private let maps: MapsOpening
    private let locale = Locale.current

    private var task: Task<Void, Never>?

    /// Nil until a fix arrives; the map still shows the car without one.
    private(set) var distanceText: String?
    private(set) var walkMinutes: Int?
    private(set) var accuracyText: String?

    var spotCoordinate: Coordinate? { spot.savedLocation?.coordinate }

    init(spot: ParkingSpot, location: LocationProviding, maps: MapsOpening) {
        self.spot = spot
        self.location = location
        self.maps = maps
    }

    func start() {
        guard task == nil else { return }
        let fixes = location.fixes()
        task = Task { [weak self] in
            for await fix in fixes {
                guard let self else { return }
                receive(fix)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    /// Hands the walk to Apple Maps. Nothing to open without a saved coordinate.
    func walkInMaps() {
        guard let spotCoordinate else { return }
        maps.openWalkingDirections(to: spotCoordinate, name: spot.placeName)
    }

    private func receive(_ fix: LocationFix) {
        guard let spotCoordinate else {
            distanceText = nil
            walkMinutes = nil
            accuracyText = nil
            return
        }
        accuracyText = Formatting.accuracy(fix.horizontalAccuracy, locale: locale)
        let distance = Geo.distance(from: fix.coordinate, to: spotCoordinate)
        distanceText = Formatting.distance(distance, locale: locale)
        walkMinutes = Formatting.walkMinutes(distance)
    }
}
