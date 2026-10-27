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
                    ZStack {
                        Theme.bg.ignoresSafeArea()
                        Button(action: coordinator.close) {
                            Image(systemName: "chevron.down")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Theme.text1)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("close"))
                    }
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
