import SwiftData
import SwiftUI

@main
struct ParkSpotApp: App {
    /// Kept for the app's whole life: the repository reads through its context.
    private let container: ModelContainer
    @State private var coordinator: AppCoordinator

    init() {
        let container = (try? ModelContainer(for: ParkingSpot.self)) ?? {
            fatalError("ParkSpot could not open its store")
        }()
        self.container = container
        let deps = AppDependencies.live(container: container)
        _coordinator = State(initialValue: AppCoordinator(deps: deps))
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(coordinator: coordinator)
        }
    }
}
