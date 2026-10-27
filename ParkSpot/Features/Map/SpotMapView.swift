import MapKit
import SwiftUI

/// The car on a map, with the walk back handed to Apple Maps.
struct SpotMapView: View {
    let spot: ParkingSpot
    let coordinator: FindCoordinator
    let deps: AppDependencies

    @State private var viewModel: MapViewModel

    init(spot: ParkingSpot, coordinator: FindCoordinator, deps: AppDependencies) {
        self.spot = spot
        self.coordinator = coordinator
        self.deps = deps
        _viewModel = State(initialValue: MapViewModel(spot: spot, location: deps.location, maps: deps.maps))
    }

    var body: some View {
        ZStack(alignment: .top) {
            map
            HStack {
                CircleIconButton(systemImage: "chevron.left", labelKey: "close") {
                    if !coordinator.path.isEmpty { coordinator.path.removeLast() }
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
        }
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) { card }
        .task { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }

    private var map: some View {
        Map(initialPosition: .userLocation(fallback: .automatic)) {
            UserAnnotation()
            if let coordinate = viewModel.spotCoordinate {
                Annotation("P", coordinate: CLLocationCoordinate2D(latitude: coordinate.latitude,
                                                                   longitude: coordinate.longitude)) {
                    Text(verbatim: "P")
                        .font(.headline.weight(.black))
                        .foregroundStyle(Theme.black)
                        .frame(width: 38, height: 38)
                        .background(Theme.accent, in: Circle())
                        .overlay { Circle().strokeBorder(Theme.black, lineWidth: 2) }
                }
            }
        }
        .mapControls { MapUserLocationButton() }
        .ignoresSafeArea()
    }

    private var card: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("your_car")
                        .font(.headline)
                        .foregroundStyle(Theme.text1)
                    HStack(spacing: 6) {
                        if let distance = viewModel.distanceText {
                            Text(verbatim: distance)
                        }
                        if let minutes = viewModel.walkMinutes {
                            Text(String(format: String(localized: "walk_fmt"), minutes))
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(Theme.text2)
                }
                Spacer(minLength: 8)
                if let accuracy = viewModel.accuracyText {
                    Text(String(format: String(localized: "gps_fmt"), accuracy))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.text1)
                        .padding(.horizontal, 11)
                        .frame(minHeight: 30)
                        .background(Theme.surface2, in: Capsule())
                        .fixedSize()
                }
            }
            PillButton("directions_maps") { viewModel.walkInMaps() }
                .accessibilityIdentifier("map_directions")
        }
        .padding(14)
        .background(Theme.surface3, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}
