import SwiftUI

/// Find as a full-screen cover: the navigation stack, the map route, and the full-screen photo.
struct FindRootView: View {
    @Bindable var coordinator: FindCoordinator
    let deps: AppDependencies

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            Group {
                if let spot = coordinator.spot {
                    FindView(spot: spot, coordinator: coordinator, deps: deps)
                } else {
                    VStack {
                        HStack {
                            Button(action: coordinator.close) {
                                Image(systemName: "chevron.down")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Theme.text1)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text("close"))
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        Spacer()
                    }
                    .background(Theme.bg.ignoresSafeArea())
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: FindCoordinator.Route.self) { route in
                switch route {
                case .map:
                    if let spot = coordinator.spot {
                        SpotMapView(spot: spot, coordinator: coordinator, deps: deps)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: Binding(get: { coordinator.isPhotoPresented },
                                              set: { if !$0 { coordinator.hidePhoto() } })) {
            if let spot = coordinator.spot {
                PhotoViewer(photos: deps.photos, fileName: spot.photoFileName) { coordinator.hidePhoto() }
            }
        }
    }
}
