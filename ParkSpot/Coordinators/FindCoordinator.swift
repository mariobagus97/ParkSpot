import Foundation
import Observation
import SwiftData

/// The Find screen from opening to "Found it": it holds the spot, its own routes, and the two ways out.
@MainActor @Observable final class FindCoordinator: Identifiable {
    enum Route: Hashable {
        case map
    }

    /// The spot's id, so a full-screen cover can be bound to it.
    let id: UUID
    private(set) var spot: ParkingSpot?
    var path: [Route] = []
    /// The full-screen photo of the spot.
    private(set) var isPhotoPresented = false

    /// Called after the session ended, so the caller can drop its reference.
    var onEnded: () -> Void = {}
    /// Called when the user closes Find without ending the session; the spot stays active.
    var onClose: () -> Void = {}

    private let deps: AppDependencies
    private let saver: SpotSaver

    init(spotID: UUID, deps: AppDependencies, saver: SpotSaver) {
        id = spotID
        self.deps = deps
        self.saver = saver
        spot = try? deps.repository.spot(id: spotID)
    }

    func showMap() {
        path.append(.map)
    }

    /// Hands the walk to Apple Maps. Nothing to open when the spot has no coordinates.
    func openDirections() {
        guard let coordinate = spot?.savedLocation?.coordinate else { return }
        deps.maps.openWalkingDirections(to: coordinate, name: spot?.placeName)
    }

    /// "Found it": the refinement stops first, so no late fix can write to the ended spot.
    func foundIt() {
        guard let spot else {
            onEnded()
            return
        }
        saver.stopRefining()
        try? deps.repository.endSession(spot)
        onEnded()
    }

    func showPhoto() {
        isPhotoPresented = true
    }

    func hidePhoto() {
        isPhotoPresented = false
    }

    func close() {
        onClose()
    }
}
