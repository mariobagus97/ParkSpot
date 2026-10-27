import SwiftUI

/// The app's screens, and everything the save and find flows present over them.
struct AppRootView: View {
    @Bindable var coordinator: AppCoordinator

    var body: some View {
        TabView(selection: $coordinator.selectedTab) {
            HomeView(coordinator: coordinator)
                .tabItem { Label("tab_home", systemImage: "house.fill") }
                .tag(AppCoordinator.Tab.home)

            HistoryView(coordinator: coordinator.history, deps: coordinator.deps)
                .tabItem { Label("tab_lib", systemImage: "rectangle.stack.fill") }
                .tag(AppCoordinator.Tab.spots)
        }
        .tint(Theme.accent)
        .safeAreaInset(edge: .bottom) {
            if let spot = coordinator.activeSpot {
                NowParkedBar(spot: spot, deps: coordinator.deps) { coordinator.presentFind() }
                    .id(spot.id)   // a new spot gets a fresh bar, not the old one's distance
            }
        }
        .fullScreenCover(isPresented: findPresented) {
            if let find = coordinator.find {
                FindRootView(coordinator: find, deps: coordinator.deps)
            }
        }
        .saveFlow(coordinator.save, deps: coordinator.deps, saver: coordinator.saver)
        .preferredColorScheme(.dark)
        .task { coordinator.launch() }
        .onChange(of: coordinator.selectedTab) { coordinator.refreshActiveSpot() }
    }

    /// `find` is owned by the coordinator; dismissing the cover clears it.
    private var findPresented: Binding<Bool> {
        Binding(get: { coordinator.find != nil },
                set: { if !$0 { coordinator.dismissFind() } })
    }
}
