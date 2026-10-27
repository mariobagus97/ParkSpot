import Foundation
import Observation

/// Your spots: the list, one spot's detail, and the two ways a list row changes the active spot.
@MainActor @Observable final class HistoryCoordinator {
    enum Route: Hashable {
        case detail(UUID)
    }

    var path: [Route] = []
    /// Set while the "replace your current spot?" alert is up.
    private(set) var confirmUseAgainFor: UUID?
    /// Bumped whenever the stored spots change, so the list reloads after a delete or a reuse.
    private(set) var rowsVersion = 0

    /// Called after the active spot changed; `openFind` asks the shell to present Find.
    var onActiveChanged: (_ openFind: Bool) -> Void = { _ in }

    private let deps: AppDependencies
    private let saver: SpotSaver

    init(deps: AppDependencies, saver: SpotSaver) {
        self.deps = deps
        self.saver = saver
    }

    func showDetail(_ id: UUID) {
        path.append(.detail(id))
    }

    /// The spot the replace alert talks about: the active one, which is the one that will move to Your spots.
    var replacingName: String {
        (try? deps.repository.activeSpot())?.placeName ?? String(localized: "unnamed")
    }

    /// Reusing a spot while another one is active has to ask first: only one spot is active at a time.
    func useAgain(_ id: UUID) {
        guard let spot = try? deps.repository.spot(id: id) else { return }
        guard !spot.isActive else { return }        // already showing it: nothing to change
        if (try? deps.repository.activeSpot()) != nil {
            confirmUseAgainFor = id
        } else {
            activate(spot)
        }
    }

    func confirmUseAgain() {
        guard let id = confirmUseAgainFor else { return }
        confirmUseAgainFor = nil
        guard let spot = try? deps.repository.spot(id: id) else { return }
        activate(spot)
    }

    func cancelUseAgain() {
        confirmUseAgainFor = nil
    }

    /// Deleting the active spot stops its refinement first, so no late fix writes to a deleted model.
    func delete(_ id: UUID) {
        guard let spot = try? deps.repository.spot(id: id) else { return }
        let wasActive = spot.isActive
        if wasActive { saver.stopRefining() }
        do {
            try deps.repository.delete(spot)
        } catch {
            return
        }
        confirmUseAgainFor = nil
        rowsVersion += 1
        if wasActive { onActiveChanged(false) }
        path.removeAll { $0 == .detail(id) }
    }

    private func activate(_ spot: ParkingSpot) {
        saver.stopRefining()
        do {
            try deps.repository.activate(spot)
        } catch {
            return                                  // the active spot did not change, so nothing is announced
        }
        rowsVersion += 1
        onActiveChanged(true)
    }
}
