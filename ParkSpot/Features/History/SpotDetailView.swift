import MapKit
import SwiftUI

/// One saved spot: the photo, what was written down, where it is, and the two actions.
struct SpotDetailView: View {
    let spot: ParkingSpot
    let coordinator: HistoryCoordinator
    let deps: AppDependencies

    @State private var confirmDelete = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    CoverArt(photos: deps.photos, fileName: spot.photoFileName, tint: spot.photoTint, cornerRadius: 8)
                        .aspectRatio(4 / 3, contentMode: .fit)
                    Text(verbatim: spot.placeName ?? String(localized: "unnamed"))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Theme.text1)
                    Text(verbatim: spot.vehicleKind.name)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.text2)
                    if let floor = spot.floor, !floor.isEmpty {
                        HStack(spacing: 8) {
                            Text("floor")
                                .font(.footnote)
                                .foregroundStyle(Theme.text2)
                            FloorBadge(floor)
                        }
                    }
                    if let note = spot.note, !note.isEmpty {
                        Text(verbatim: note)
                            .font(.subheadline)
                            .foregroundStyle(Theme.text1)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    Text(verbatim: spot.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(Theme.text2)
                    if let coordinate = spot.savedLocation?.coordinate {
                        map(coordinate)
                    }
                    PillButton("use_again") { coordinator.useAgain(spot.id) }
                        .accessibilityIdentifier("detail_use_again")
                    PillButton("delete", style: .outline) { confirmDelete = true }
                }
                .padding(16)
            }
        }
        .navigationTitle(Text("tab_lib"))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("delete_t", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("delete", role: .destructive) { coordinator.delete(spot.id) }
            Button("cancel", role: .cancel) {}
        }
    }

    private func map(_ coordinate: Coordinate) -> some View {
        Map(initialPosition: .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: coordinate.latitude,
                                                                                       longitude: coordinate.longitude),
                                                        latitudinalMeters: 300, longitudinalMeters: 300)),
            interactionModes: []) {
            Annotation(coordinate: CLLocationCoordinate2D(latitude: coordinate.latitude,
                                                          longitude: coordinate.longitude)) {
                Text(verbatim: "P")
                    .font(.headline.weight(.black))
                    .foregroundStyle(Theme.black)
                    .frame(width: 34, height: 34)
                    .background(Theme.accent, in: Circle())
            } label: {
                Text(verbatim: "P")
            }
        }
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityHidden(true)
    }
}
