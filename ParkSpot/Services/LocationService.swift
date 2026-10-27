import CoreLocation

@MainActor protocol LocationProviding: AnyObject {
    var authorization: LocationAuthorization { get }
    var isApproximate: Bool { get }                 // reduced-accuracy authorization
    var lastKnownFix: LocationFix? { get }
    func requestAuthorization() async -> LocationAuthorization
    func fixes() -> AsyncStream<LocationFix>        // one stream per call; updates stop when no stream is left
    func headings() -> AsyncStream<Heading?>        // nil while the compass needs calibration (headingAccuracy < 0)
}

extension LocationFix {
    /// nil for a location Core Location marks invalid (negative `horizontalAccuracy`), which would otherwise read as a perfect fix.
    init?(_ location: CLLocation) {
        guard location.horizontalAccuracy >= 0 else { return nil }
        self.init(coordinate: Coordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude),
                  horizontalAccuracy: location.horizontalAccuracy,
                  timestamp: location.timestamp)
    }
}

extension Heading {
    /// True north when Core Location has it (`trueHeading` ≥ 0), else magnetic north. nil while the compass is uncalibrated.
    init?(trueHeading: Double, magneticHeading: Double, accuracy: Double) {
        guard accuracy >= 0 else { return nil }
        self.init(degrees: trueHeading >= 0 ? trueHeading : magneticHeading)
    }
}

extension LocationAuthorization {
    init(_ status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined: self = .notDetermined
        case .authorizedWhenInUse, .authorizedAlways: self = .authorized
        case .denied, .restricted: self = .denied
        @unknown default: self = .denied
        }
    }
}

/// One `CLLocationManager`, fanned out to every open stream. Updates run only while a stream is open.
@MainActor final class LocationService: NSObject, LocationProviding {
    private let manager = CLLocationManager()
    private var fixStreams: [UUID: AsyncStream<LocationFix>.Continuation] = [:]
    private var headingStreams: [UUID: AsyncStream<Heading?>.Continuation] = [:]
    private var authorizationWaiters: [CheckedContinuation<LocationAuthorization, Never>] = []

    override init() {
        super.init()
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.headingFilter = 1
        manager.delegate = self
    }

    var authorization: LocationAuthorization { LocationAuthorization(manager.authorizationStatus) }
    var isApproximate: Bool { manager.accuracyAuthorization == .reducedAccuracy }
    var lastKnownFix: LocationFix? { manager.location.flatMap { LocationFix($0) } }

    func requestAuthorization() async -> LocationAuthorization {
        let current = authorization
        guard current == .notDetermined else { return current }
        return await withCheckedContinuation { waiter in
            authorizationWaiters.append(waiter)
            if authorizationWaiters.count == 1 { manager.requestWhenInUseAuthorization() }
        }
    }

    func fixes() -> AsyncStream<LocationFix> {
        let id = UUID()
        let (stream, continuation) = AsyncStream.makeStream(of: LocationFix.self)
        fixStreams[id] = continuation
        if fixStreams.count == 1 { manager.startUpdatingLocation() }
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.closeFixStream(id) }
        }
        return stream
    }

    func headings() -> AsyncStream<Heading?> {
        let id = UUID()
        let (stream, continuation) = AsyncStream.makeStream(of: Heading?.self,
                                                              bufferingPolicy: .bufferingNewest(1))
        headingStreams[id] = continuation
        if headingStreams.count == 1 { manager.startUpdatingHeading() }
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.closeHeadingStream(id) }
        }
        return stream
    }

    private func closeFixStream(_ id: UUID) {
        guard fixStreams.removeValue(forKey: id) != nil, fixStreams.isEmpty else { return }
        manager.stopUpdatingLocation()
    }

    private func closeHeadingStream(_ id: UUID) {
        guard headingStreams.removeValue(forKey: id) != nil, headingStreams.isEmpty else { return }
        manager.stopUpdatingHeading()
    }
}

// The delegate is called on the main thread (the manager is created there), so the conformance is isolated to the main actor.
extension LocationService: @MainActor CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for fix in locations.compactMap({ LocationFix($0) }) {
            for continuation in fixStreams.values { continuation.yield(fix) }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let heading = Heading(trueHeading: newHeading.trueHeading,
                              magneticHeading: newHeading.magneticHeading,
                              accuracy: newHeading.headingAccuracy)
        for continuation in headingStreams.values { continuation.yield(heading) }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let current = authorization
        guard current != .notDetermined else { return }
        let waiters = authorizationWaiters
        authorizationWaiters = []
        for waiter in waiters { waiter.resume(returning: current) }
    }
}
