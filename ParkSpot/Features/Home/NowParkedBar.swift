import SwiftUI

/// The strip above the tab bar while a spot is active: photo, place, distance, and a tap that opens Find.
struct NowParkedBar: View {
    let spot: ParkingSpot
    let deps: AppDependencies
    let onTap: () -> Void

    @State private var viewModel: NowParkedViewModel

    init(spot: ParkingSpot, deps: AppDependencies, onTap: @escaping () -> Void) {
        self.spot = spot
        self.deps = deps
        self.onTap = onTap
        _viewModel = State(initialValue: NowParkedViewModel(spot: spot, location: deps.location, now: deps.now))
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                CoverArt(photos: deps.photos, fileName: spot.photoFileName, tint: spot.photoTint, cornerRadius: 4)
                    .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(verbatim: title)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.text1)
                            .lineLimit(1)
                        Text(verbatim: spot.vehicleKind.name)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.text2)
                            .lineLimit(1)
                    }
                    Text(verbatim: subtitle)
                        .font(.caption2)
                        .foregroundStyle(Theme.text2)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Image(systemName: "figure.walk")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 10)
            .frame(height: 56)
            .background(plate, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("now_parked_bar")
        .accessibilityLabel(Text(verbatim: "\(title), \(subtitle)"))
        .padding(.horizontal, 8)
        .padding(.bottom, 6)
        .task { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }

    private var title: String {
        spot.placeName ?? String(localized: "your_car")
    }

    private var subtitle: String {
        if let distance = viewModel.distanceText {
            return "\(distance) · \(viewModel.savedAgoText)"
        }
        if viewModel.hasNoLocation {
            return "\(String(localized: "noloc")) · \(viewModel.savedAgoText)"
        }
        return viewModel.savedAgoText
    }

    /// The photo's own colour, so the strip belongs to the spot.
    private var plate: Color {
        let tint = UInt32(truncatingIfNeeded: spot.photoTint ?? Int(Theme.Hex.surface2))
        return Color(hex: tint).opacity(0.55)
    }
}
