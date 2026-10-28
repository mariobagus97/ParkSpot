import SwiftUI

/// The app's screens, and everything the save and find flows present over them.
struct AppRootView: View {
    @Bindable var coordinator: AppCoordinator
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: $coordinator.selectedTab) {
            HomeView(coordinator: coordinator)
                .parkedBar(coordinator)
                .tabItem { Label("tab_home", systemImage: "house.fill") }
                .tag(AppCoordinator.Tab.home)

            HistoryView(coordinator: coordinator.history, deps: coordinator.deps)
                .parkedBar(coordinator)
                .tabItem { Label("tab_lib", systemImage: "rectangle.stack.fill") }
                .tag(AppCoordinator.Tab.spots)
        }
        .tint(Theme.accent)
        .fullScreenCover(isPresented: findPresented) {
            if let find = coordinator.find {
                FindRootView(coordinator: find, deps: coordinator.deps)
            }
        }
        .saveFlow(coordinator.save, deps: coordinator.deps, saver: coordinator.saver)
        .preferredColorScheme(.dark)
        .task { coordinator.launch() }
        .onChange(of: coordinator.selectedTab) { coordinator.refreshActiveSpot() }
        .onChange(of: scenePhase) { _, phase in
            // Returning from Settings: a permission the user just granted should take effect.
            if phase == .active { coordinator.save.permissionsMayHaveChanged() }
        }
    }

    /// `find` is owned by the coordinator; dismissing the cover clears it.
    private var findPresented: Binding<Bool> {
        Binding(get: { coordinator.find != nil },
                set: { if !$0 { coordinator.dismissFind() } })
    }
}

private extension View {
    /// The now-parked bar, inside the tab's own content rather than wrapped around the whole `TabView`.
    /// Wrapping the TabView put the inset outside the tab bar's layout, and the bar's labels ended up drawn
    /// above the floating capsule instead of inside it.
    func parkedBar(_ coordinator: AppCoordinator) -> some View {
        safeAreaInset(edge: .bottom) {
            if let spot = coordinator.activeSpot {
                NowParkedBar(spot: spot, deps: coordinator.deps) { coordinator.presentFind() }
                    .id(spot.id)   // a new spot gets a fresh bar, not the old one's distance
            }
        }
    }
}
