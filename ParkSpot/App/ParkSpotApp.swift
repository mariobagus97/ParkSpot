import OSLog
import SwiftData
import SwiftUI

@main
struct ParkSpotApp: App {
    /// Kept for the app's whole life: the repository reads through its context.
    private let container: ModelContainer
    @State private var coordinator: AppCoordinator

    init() {
        #if DEBUG
        if CommandLine.arguments.contains("-ui-testing") {
            let (deps, container) = UITestServices.dependencies()
            self.container = container
            _coordinator = State(initialValue: AppCoordinator(deps: deps))
            return
        }
        #endif
        let container: ModelContainer
        do {
            container = try ModelContainer(for: ParkingSpot.self)
        } catch {
            // A corrupt store would otherwise be a launch crash loop with no clue in the logs.
            Logger(subsystem: "com.mariobagus.parkspot", category: "store")
                .error("could not open the spot store: \(error, privacy: .public); starting with an empty one")
            container = (try? ModelContainer(for: ParkingSpot.self,
                                             configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
                ?? { fatalError("ParkSpot could not open any store") }()
        }
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
