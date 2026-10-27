import Foundation
import Observation
import UIKit

/// "Park here" from the tap to the details sheet: replace check, camera, photo, details. It owns every alert and
/// full-screen cover of the flow; `saveFlow(_:deps:saver:)` only renders them.
///
/// Location capture starts at the tap, before the camera opens, so a slow photo never costs the position.
@MainActor @Observable final class SaveCoordinator {
    enum Alert: Equatable { case confirmReplace, photoRequired, saveFailed }
    enum Cover: Equatable { case camera, cameraDenied }

    private(set) var alert: Alert?
    private(set) var cover: Cover?
    private(set) var detailsSpotID: UUID?
    /// Place name of the spot a replace would push out of "active", for the alert text. nil when it has none.
    /// Only meaningful while the alert shows; it is left alone afterwards so the alert doesn't change as it fades.
    private(set) var replacingPlaceName: String?
    /// Called with the id of the spot once its photo is stored.
    var onSaved: (UUID) -> Void = { _ in }

    @ObservationIgnored private let deps: AppDependencies
    @ObservationIgnored private let saver: SpotSaver
    /// True from `start()` until the flow ends (cancel, or the details sheet closes).
    @ObservationIgnored private var isRunning = false
    /// Changes whenever a flow ends, so a camera-permission answer that arrives late is dropped.
    @ObservationIgnored private var flowID = 0

    init(deps: AppDependencies, saver: SpotSaver) {
        self.deps = deps
        self.saver = saver
    }

    /// Ignored while a flow runs, so a double tap never opens a second camera. An active spot is replaced only
    /// after the user agrees.
    func start() {
        guard !isRunning else { return }
        // Reading the store can fail. If it does, say so and leave the button usable rather than guessing.
        let active: ParkingSpot?
        do {
            active = try deps.repository.activeSpot()
        } catch {
            alert = .saveFailed
            return
        }
        replacingPlaceName = active?.placeName
        isRunning = true
        if active == nil {
            beginCamera()
        } else {
            alert = .confirmReplace
        }
    }

    func confirmReplace() {
        guard alert == .confirmReplace else { return }
        alert = nil
        beginCamera()
    }

    /// Leaves the flow from anywhere before the spot is stored: nothing is saved and the capture stops.
    func cancel() {
        alert = nil
        cover = nil
        saver.cancelCapture()
        endFlow()
    }

    /// The photo is the point of the app: store it, then open the details. The saver throws when it can't.
    func photoTaken(_ image: UIImage) {
        do {
            let spot = try saver.commit(photo: image)
            cover = nil
            alert = nil
            detailsSpotID = spot.id
            onSaved(spot.id)
        } catch {
            cover = nil
            alert = .saveFailed
            // A dropped cover-to-alert transition must never leave "Park here" dead.
            endFlow()
        }
    }

    /// No photo, no spot. The capture keeps running while the user decides whether to take one.
    func cameraCancelled() {
        cover = nil
        alert = .photoRequired
    }

    func retakePhoto() {
        alert = nil
        cover = .camera
    }

    /// The sheet is closed. The spot stays as saved and keeps sharpening in the background.
    func detailsDone() {
        detailsSpotID = nil
        endFlow()               // the flow is over; the spot keeps sharpening on its own
    }

    // MARK: Private

    private func beginCamera() {
        #if DEBUG
        if let testPhoto = deps.testPhoto {
            saver.beginCapture()
            photoTaken(testPhoto)
            return
        }
        #endif
        if deps.location.authorization == .notDetermined {
            Task { [location = deps.location] in _ = await location.requestAuthorization() }   // never waited for
        }
        saver.beginCapture()

        switch deps.camera.status() {
        case .authorized:
            cover = .camera
        case .notDetermined:
            let id = flowID
            Task { [weak self] in
                guard let granted = await self?.deps.camera.request() else { return }
                self?.cameraAnswered(granted: granted, flowID: id)
            }
        case .denied:
            showCameraDenied()
        case .unavailable:
            #if DEBUG
            cover = .camera   // the picker falls back to the photo library
            #else
            showCameraDenied()
            #endif
        }
    }

    private func cameraAnswered(granted: Bool, flowID id: Int) {
        guard id == flowID, isRunning else { return }
        if granted {
            cover = .camera
        } else {
            showCameraDenied()
        }
    }

    /// Without a camera there will be no photo, so the capture is pointless.
    private func showCameraDenied() {
        saver.cancelCapture()
        cover = .cameraDenied
    }

    private func endFlow() {
        isRunning = false
        flowID += 1
    }
}
