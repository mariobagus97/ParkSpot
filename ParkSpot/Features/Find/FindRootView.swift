import SwiftUI

/// Find as a full-screen cover: the navigation stack, and the routes it can push.
/// The map destination is a placeholder until the map screen lands; the coordinator already pushes `.map`.
struct FindRootView: View {
    @Bindable var coordinator: FindCoordinator
    let deps: AppDependencies

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            Group {
                if let spot = coordinator.spot {
                    FindView(spot: spot, coordinator: coordinator, deps: deps)
                } else {
                    Theme.bg.ignoresSafeArea()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: FindCoordinator.Route.self) { route in
                switch route {
                case .map:
                    Text(verbatim: "Map")
                }
            }
        }
    }
}
