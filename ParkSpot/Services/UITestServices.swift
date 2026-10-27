#if DEBUG
import Foundation
import SwiftData
import UIKit

/// Everything the app talks to, faked for UI tests: a scripted location, no camera UI, an in-memory store.
/// Only `-ui-testing` uses it, and it is compiled out of release builds.
@MainActor enum UITestServices {
    static func dependencies() -> (AppDependencies, ModelContainer) {
        let container = (try? ModelContainer(for: ParkingSpot.self,
                                            configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
            ?? { fatalError("UI testing could not open an in-memory store") }()
        let photos = PhotoStore(directory: FileManager.default.temporaryDirectory
            .appending(path: "parkspot-uitest-\(UUID().uuidString)"))

        var deps = AppDependencies(location: UITestLocation(),
                                   camera: UITestCamera(),
                                   photos: photos,
                                   repository: SpotRepository(context: container.mainContext, photos: photos),
                                   geocoder: UITestGeocoder(),
                                   maps: UITestMaps(),
                                   now: { Date() })
        deps.testPhoto = solidImage()
        return (deps, container)
    }
}

/// A plain 1200x1200 image in the mockup's blue, so the photo step needs no camera.
func solidImage() -> UIImage {
    let size = CGSize(width: 1200, height: 1200)
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1
    format.preferredRange = .standard
    return UIGraphicsImageRenderer(size: size, format: format).image { context in
        UIColor(red: 0x3B / 255, green: 0x5B / 255, blue: 0x7A / 255, alpha: 1).setFill()
        context.fill(CGRect(origin: .zero, size: size))
    }
}

/// Authorized, fixed at a spot in Jakarta, and answers the first `fixes()` call with that position.
@MainActor final class UITestLocation: LocationProviding {
    private var fixStreams: [UUID: AsyncStream<LocationFix>.Continuation] = [:]
    private var headingStreams: [UUID: AsyncStream<Heading?>.Continuation] = [:]

    let fix = LocationFix(coordinate: Coordinate(latitude: -6.2, longitude: 106.8174),
                          horizontalAccuracy: 5,
                          timestamp: Date())

    var authorization: LocationAuthorization { .authorized }
    var isApproximate: Bool { false }
    var lastKnownFix: LocationFix? { fix }

    func requestAuthorization() async -> LocationAuthorization { .authorized }

    func fixes() -> AsyncStream<LocationFix> {
        let id = UUID()
        let (stream, continuation) = AsyncStream.makeStream(of: LocationFix.self)
        fixStreams[id] = continuation
        continuation.yield(fix)
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.fixStreams.removeValue(forKey: id) }
        }
        return stream
    }

    func headings() -> AsyncStream<Heading?> {
        let id = UUID()
        let (stream, continuation) = AsyncStream.makeStream(of: Heading?.self)
        headingStreams[id] = continuation
        continuation.yield(Heading(degrees: 90))
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.headingStreams.removeValue(forKey: id) }
        }
        return stream
    }
}

@MainActor final class UITestCamera: CameraAuthorizing {
    func status() -> CameraStatus { .authorized }
    func request() async -> Bool { true }
}

@MainActor final class UITestGeocoder: Geocoding {
    func placeName(for coordinate: Coordinate) async -> String? { "Jl. Sudirman" }
}

@MainActor final class UITestMaps: MapsOpening {
    func openWalkingDirections(to coordinate: Coordinate, name: String?) {}
}
#endif
