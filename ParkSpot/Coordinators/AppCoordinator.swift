import Foundation
import Observation
import SwiftData

/// The app's shell: the tabs, the active spot, and the Find cover it presents.
@MainActor @Observable final class AppCoordinator {
    enum Tab: Hashable {
        case home
        case spots
    }

    var selectedTab: Tab = .home
    private(set) var activeSpot: ParkingSpot?
    /// The Find cover, non-nil while it is on screen.
    private(set) var find: FindCoordinator?
    let saver: SpotSaver
    let save: SaveCoordinator
    let history: HistoryCoordinator

    let deps: AppDependencies

    init(deps: AppDependencies) {
        self.deps = deps
        let saver = SpotSaver(deps: deps)
        self.saver = saver
        save = SaveCoordinator(deps: deps, saver: saver)
        history = HistoryCoordinator(deps: deps, saver: saver)
        save.onSaved = { [weak self] _ in self?.refreshActiveSpot() }
        history.onActiveChanged = { [weak self] openFind in
            guard let self else { return }
            refreshActiveSpot()
            if openFind { presentFind() }
        }
    }

    var activeSpotID: UUID? { activeSpot?.id }

    /// What the app does when it comes up: an active spot opens Find straight away (PRD).
    func launch() {
        refreshActiveSpot()
        if activeSpot != nil { presentFind() }
    }

    func presentFind() {
        guard find == nil, let activeSpot else { return }
        let coordinator = FindCoordinator(spotID: activeSpot.id, deps: deps, saver: saver)
        coordinator.onEnded = { [weak self] in self?.spotEnded() }
        coordinator.onClose = { [weak self] in self?.dismissFind() }
        find = coordinator
    }

    func dismissFind() {
        find = nil
    }

    /// "Found it": the session ended, so nothing is on screen and no spot is active.
    func spotEnded() {
        find = nil
        activeSpot = nil
    }

    func refreshActiveSpot() {
        activeSpot = try? deps.repository.activeSpot()
    }
}
