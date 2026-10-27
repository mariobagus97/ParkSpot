import SwiftUI

/// The app's screens, and everything the save and find flows present over them.
struct AppRootView: View {
    @Bindable var coordinator: AppCoordinator

    var body: some View {
        TabView(selection: $coordinator.selectedTab) {
            HomeView(coordinator: coordinator)
                .tabItem { Label("tab_home", systemImage: "house.fill") }
                .tag(AppCoordinator.Tab.home)
        }
        .tint(Theme.accent)
        .safeAreaInset(edge: .bottom) {
            if let spot = coordinator.activeSpot {
                NowParkedBar(spot: spot, deps: coordinator.deps) { coordinator.presentFind() }
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
    }

    /// `find` is owned by the coordinator; dismissing the cover clears it.
    private var findPresented: Binding<Bool> {
        Binding(get: { coordinator.find != nil },
                set: { if !$0 { coordinator.dismissFind() } })
    }
}
