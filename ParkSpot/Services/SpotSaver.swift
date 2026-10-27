import Foundation
import Observation
import UIKit

/// "Park here": location capture starts at the tap, the spot is committed once the photo exists, and the stored
/// position keeps improving in the background until it is good enough or 20 s have passed.
///
/// Every capture has an id. Anything that outlives its capture (a fix already in flight, the timeout, a place-name
/// lookup) compares that id before it writes, so an old capture can never touch a spot again.
@MainActor @Observable final class SpotSaver {
    /// True from the tap until the refinement is over (good enough, timed out, stopped or cancelled).
    private(set) var isRefining = false
    /// The best accuracy so far in metres, for the "sharpening GPS" line.
    private(set) var currentAccuracy: Double?

    @ObservationIgnored private let deps: AppDependencies
    @ObservationIgnored private var captureID = 0
    @ObservationIgnored private var refiner: LocationRefiner?     // nil while no capture is open
    @ObservationIgnored private var spot: ParkingSpot?            // set by commit
    @ObservationIgnored private var refinementIsOver = false
    @ObservationIgnored private var consumer: Task<Void, Never>?
    @ObservationIgnored private var timeout: Task<Void, Never>?
    @ObservationIgnored private var geocoding: Task<Void, Never>?

    init(deps: AppDependencies) {
        self.deps = deps
    }

    /// Called at the "Park here" tap. Ends any earlier refinement, then starts a new one from the last known fix.
    func beginCapture() {
        endCapture()
        let now = deps.now()
        let refiner = LocationRefiner(startedAt: now, lastKnown: deps.location.lastKnownFix)
        self.refiner = refiner
        currentAccuracy = refiner.best?.horizontalAccuracy
        guard !refiner.isFinished(at: now) else {
            refinementIsOver = true   // a recent, good last-known fix: nothing left to wait for
            return
        }
        isRefining = true
        let id = captureID
        let fixes = deps.location.fixes()   // subscribed now, so no fix between the tap and the task is lost
        consumer = Task { [weak self] in
            for await fix in fixes {
                guard let self, self.captureID == id else { return }
                self.receive(fix)
            }
        }
        timeout = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(LocationRefiner.maxDuration)) } catch { return }
            guard let self, self.captureID == id else { return }
            self.checkTimeout()
        }
    }

    /// Stores the spot with the best fix so far and keeps refining it. Throws if the photo can't be saved, and then
    /// nothing is inserted and the capture is over. Without an earlier `beginCapture()` the capture starts here.
    func commit(photo: UIImage) throws -> ParkingSpot {
        if refiner == nil || spot != nil { beginCapture() }

        let fileName: String
        do {
            fileName = try deps.photos.save(photo)
        } catch {
            cancelCapture()
            throw error
        }

        let newSpot = ParkingSpot(createdAt: deps.now(), photoFileName: fileName)
        newSpot.photoTint = PhotoTint.average(of: photo)   // builds a CIContext: once per commit
        newSpot.setLocation(refiner?.best)
        do {
            try deps.repository.insertActive(newSpot)
        } catch {
            deps.photos.delete(named: fileName)   // the repository has no rollback
            stopRefining()
            throw error
        }
        spot = newSpot

        // Refinement may already be over (a good fix, or the photo took 20 s): store the best fix and name it now.
        if refinementIsOver {
            lookUpPlaceName()
        } else if refiner?.isFinished(at: deps.now()) == true {
            finishRefinement()
        }
        return newSpot
    }

    /// No photo was taken: stop and save nothing.
    func cancelCapture() {
        endCapture()
        currentAccuracy = nil
    }

    /// "Found it", replace or delete: the committed spot is never touched again.
    func stopRefining() {
        endCapture()
    }

    /// Ends the refinement once 20 s have passed since the tap. Also run by the internal timer.
    func checkTimeout() {
        guard !refinementIsOver, refiner?.isFinished(at: deps.now()) == true else { return }
        finishRefinement()
    }

    // MARK: Private

    /// Invalidates the current capture: later fixes, timeouts and place names for it are ignored.
    private func endCapture() {
        captureID += 1
        consumer?.cancel()
        timeout?.cancel()
        geocoding?.cancel()
        consumer = nil
        timeout = nil
        geocoding = nil
        refiner = nil
        spot = nil
        refinementIsOver = false
        isRefining = false
    }

    private func receive(_ fix: LocationFix) {
        guard !refinementIsOver, let improved = refiner?.consider(fix) else { return }
        if improved {
            currentAccuracy = fix.horizontalAccuracy
            if let spot {
                spot.setLocation(fix)
                persist()
            }
        }
        if refiner?.isFinished(at: deps.now()) == true { finishRefinement() }
    }

    private func finishRefinement() {
        guard !refinementIsOver else { return }
        refinementIsOver = true
        isRefining = false
        consumer?.cancel()
        timeout?.cancel()
        consumer = nil
        timeout = nil
        lookUpPlaceName()
    }

    /// Names the committed spot after its position is final. Does nothing without a spot or a position.
    private func lookUpPlaceName() {
        guard let spot, let coordinate = refiner?.best?.coordinate else { return }
        let id = captureID
        geocoding = Task { [weak self, geocoder = deps.geocoder] in
            let name = await geocoder.placeName(for: coordinate)
            guard let self, self.captureID == id, let name else { return }
            spot.placeName = name
            self.persist()
        }
    }

    /// A failed background save leaves the change pending in the context, so the next save retries it.
    private func persist() {
        try? deps.repository.save()
    }
}
