import SwiftData
import UIKit
@testable import ParkSpot

/// In-memory stand-in for the photo directory. `save` hands out `fake-N.jpg` names.
@MainActor final class FakePhotoStore: PhotoStoring {
    var files: [String: UIImage] = [:]
    var deleted: [String] = []
    var failNextSave = false
    private var counter = 0

    func save(_ image: UIImage) throws -> String {
        if failNextSave {
            failNextSave = false
            throw PhotoStoreError.encodingFailed
        }
        counter += 1
        let name = "fake-\(counter).jpg"
        files[name] = image
        return name
    }

    func image(named name: String) -> UIImage? { files[name] }

    func thumbnail(named name: String, maxPixel: Int) -> UIImage? { files[name] }

    func delete(named name: String) {
        deleted.append(name)
        files[name] = nil
    }
}

extension ModelContainer {
    /// A fresh store that lives only in memory, so every test starts empty.
    static func inMemory() -> ModelContainer {
        do {
            return try ModelContainer(for: ParkingSpot.self,
                                      configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        } catch {
            fatalError("Could not create the in-memory container: \(error)")
        }
    }
}

/// A store file on disk that a test seeds through `writable` and then reopens with `openReadOnly()`:
/// reads work and every save throws. (An in-memory store cannot be made read-only.)
/// The directory is removed with the object, so keep it alive for as long as its containers are used.
@MainActor final class FileBackedStore {
    let writable: ModelContainer
    private let directory: URL
    private let url: URL

    init() throws {
        directory = URL.temporaryDirectory.appending(path: "ParkSpotTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        url = directory.appending(path: "store.sqlite")
        writable = try ModelContainer(for: ParkingSpot.self, configurations: ModelConfiguration(url: url))
        _ = try ModelContext(writable).fetchCount(FetchDescriptor<ParkingSpot>())   // creates the file
    }

    func openReadOnly() throws -> ModelContainer {
        try ModelContainer(for: ParkingSpot.self, configurations: ModelConfiguration(url: url, allowsSave: false))
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }
}

/// Scripted location source. Every open `fixes()`/`headings()` stream counts in `subscriberCount` until it terminates.
@MainActor final class FakeLocation: LocationProviding {
    var authorization: LocationAuthorization = .authorized
    var isApproximate = false
    var lastKnownFix: LocationFix?
    private(set) var requestCount = 0
    private(set) var subscriberCount = 0
    private var fixStreams: [UUID: AsyncStream<LocationFix>.Continuation] = [:]
    private var headingStreams: [UUID: AsyncStream<Heading?>.Continuation] = [:]

    /// Answers with the current `authorization`, so a test decides the outcome by setting it first.
    func requestAuthorization() async -> LocationAuthorization {
        requestCount += 1
        return authorization
    }

    func fixes() -> AsyncStream<LocationFix> {
        let id = UUID()
        let (stream, continuation) = AsyncStream.makeStream(of: LocationFix.self)
        fixStreams[id] = continuation
        subscriberCount += 1
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.closeFixStream(id) }
        }
        return stream
    }

    func headings() -> AsyncStream<Heading?> {
        let id = UUID()
        let (stream, continuation) = AsyncStream.makeStream(of: Heading?.self)
        headingStreams[id] = continuation
        subscriberCount += 1
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.closeHeadingStream(id) }
        }
        return stream
    }

    func send(_ fix: LocationFix) {
        for continuation in fixStreams.values { continuation.yield(fix) }
    }

    func sendHeading(_ heading: Heading?) {
        for continuation in headingStreams.values { continuation.yield(heading) }
    }

    private func closeFixStream(_ id: UUID) {
        guard fixStreams.removeValue(forKey: id) != nil else { return }
        subscriberCount -= 1
    }

    private func closeHeadingStream(_ id: UUID) {
        guard headingStreams.removeValue(forKey: id) != nil else { return }
        subscriberCount -= 1
    }
}

@MainActor final class FakeCamera: CameraAuthorizing {
    var statusValue: CameraStatus = .authorized
    var requestResult = true
    private(set) var requestCount = 0

    func status() -> CameraStatus { statusValue }

    func request() async -> Bool {
        requestCount += 1
        return requestResult
    }
}

@MainActor final class FakeGeocoder: Geocoding {
    var name: String?
    private(set) var calls: [Coordinate] = []

    init(name: String? = "Jl. Sudirman") {
        self.name = name
    }

    func placeName(for coordinate: Coordinate) async -> String? {
        calls.append(coordinate)
        return name
    }
}

@MainActor final class FakeMaps: MapsOpening {
    private(set) var opened: [Coordinate] = []

    func openWalkingDirections(to coordinate: Coordinate, name: String?) {
        opened.append(coordinate)
    }
}

/// A clock that only moves when a test says so. Build fix timestamps from `now` so they look recent.
@MainActor final class FakeClock {
    var now: Date

    init(now: Date = Date(timeIntervalSince1970: 1_000_000)) {
        self.now = now
    }

    func advance(_ seconds: TimeInterval) {
        now = now.addingTimeInterval(seconds)
    }
}

extension AppDependencies {
    /// Fakes for everything; pass the ones a test wants to inspect or script.
    /// The result keeps `container` alive: a `ModelContext` alone does not, and using it after the container is gone crashes.
    static func test(location: LocationProviding = FakeLocation(),
                     camera: CameraAuthorizing = FakeCamera(),
                     photos: PhotoStoring = FakePhotoStore(),
                     container: ModelContainer = .inMemory(),
                     geocoder: Geocoding = FakeGeocoder(),
                     maps: MapsOpening = FakeMaps(),
                     clock: FakeClock = FakeClock()) -> AppDependencies {
        AppDependencies(location: location,
                        camera: camera,
                        photos: photos,
                        repository: SpotRepository(context: container.mainContext, photos: photos),
                        geocoder: geocoder,
                        maps: maps,
                        now: { withExtendedLifetime(container) { clock.now } })
    }
}

/// Lets stream consumers on the main actor run before the next assertion.
@MainActor func settle() async {
    for _ in 0..<20 { await Task.yield() }
}
