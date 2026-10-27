import SwiftUI

/// The Now Playing-style Find screen. It renders `FindViewModel` and forwards taps to `FindCoordinator`;
/// the five states of `FindDisplay` decide what the middle of the screen shows.
struct FindView: View {
    let spot: ParkingSpot
    let coordinator: FindCoordinator
    let deps: AppDependencies

    @State private var viewModel: FindViewModel
    @Environment(\.openURL) private var openURL

    init(spot: ParkingSpot, coordinator: FindCoordinator, deps: AppDependencies) {
        self.spot = spot
        self.coordinator = coordinator
        self.deps = deps
        _viewModel = State(initialValue: FindViewModel(spot: spot, location: deps.location))
    }

    var body: some View {
        ZStack {
            background
            VStack(spacing: 12) {
                topBar
                ScrollView {
                    VStack(spacing: 12) {
                        hero
                        meta
                        stateBlock
                        progressBar
                        controls
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 8)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .padding(.top, 8)
        }
        .task { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }

    // MARK: Pieces

    private var background: some View {
        let tint = UInt32(truncatingIfNeeded: spot.photoTint ?? Int(Theme.Hex.surface2))
        return LinearGradient(colors: [Color(hex: tint).opacity(0.85), Theme.bg],
                              startPoint: .top, endPoint: .center)
            .ignoresSafeArea()
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button(action: coordinator.close) {
                Image(systemName: "chevron.down")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.text1)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("close"))

            VStack(spacing: 2) {
                Text("finding")
                    .font(.caption2.weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(1.4)
                    .foregroundStyle(Theme.text2)
                if let name = spot.placeName, !name.isEmpty {
                    Text(verbatim: name)
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1)
                } else {
                    Text("unnamed")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.text2)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)

            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 8)
    }

    private var hero: some View {
        CoverArt(photos: deps.photos, fileName: spot.photoFileName, tint: spot.photoTint, cornerRadius: 8)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if case .precise = viewModel.display {
                    CompassView(angle: viewModel.arrowAngle)
                        .padding(22)
                        .background(Theme.black.opacity(0.45), in: Circle())
                        .padding(28)
                }
            }
            .overlay(alignment: .bottomLeading) {
                if let floor = spot.floor, !floor.isEmpty {
                    FloorBadge(floor)
                        .padding(10)
                }
            }
    }

    private var meta: some View {
        HStack(alignment: .bottom, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                if let distance = viewModel.distanceText {
                    Text(verbatim: distance)
                        .font(.largeTitle.weight(.black))
                        .monospacedDigit()
                        .foregroundStyle(Theme.text1)
                }
                if !caption.isEmpty {
                    Text(verbatim: caption)
                        .font(.subheadline)
                        .foregroundStyle(Theme.text2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: viewModel.accessibilityText))

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
    }

    /// The state's own block: the warning, the arrival, the calibration hint or the photo-only note.
    @ViewBuilder private var stateBlock: some View {
        switch viewModel.display {
        case .rough:
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 9) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .accessibilityHidden(true)
                    Text(String(format: String(localized: "rough_fmt"),
                                viewModel.accuracyText ?? ""))
                        .font(.footnote.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                }
                if viewModel.isApproximateLocation {
                    settingsLink
                }
            }
            .foregroundStyle(Theme.warning)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Theme.warning.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        case .photoOnly:
            VStack(alignment: .leading, spacing: 6) {
                Text("photo_only")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.text1.opacity(0.85))
                if viewModel.isLocationDenied {
                    Text("loc_t")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Theme.warning)
                    Text("loc_b")
                        .font(.footnote)
                        .foregroundStyle(Theme.text2)
                    settingsLink
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        case .locating:
            Text("locating")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.text2)
        case .noHeading:
            Text("calibrate")
                .font(.footnote)
                .foregroundStyle(Theme.text2)
                .multilineTextAlignment(.center)
        case .arrived, .precise:
            EmptyView()
        }
    }

    private var settingsLink: some View {
        Button {
            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
        } label: {
            Text("open_settings")
                .font(.footnote.weight(.bold))
                .foregroundStyle(Theme.accent)
                .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
    }

    private var progressBar: some View {
        VStack(spacing: 6) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.text1.opacity(0.2))
                    Capsule()
                        .fill(Theme.text1)
                        .frame(width: max(4, proxy.size.width * viewModel.progress))
                }
            }
            .frame(height: 4)

            HStack {
                Text(verbatim: savedAt)
                Spacer()
                Text("your_car")
            }
            .font(.caption2)
            .foregroundStyle(Theme.text2)
        }
        .padding(.top, 2)
    }

    private var controls: some View {
        HStack(alignment: .top, spacing: 28) {
            if showsMapAndDirections {
                control(systemImage: "map", label: "map", action: coordinator.showMap)
            }

            VStack(spacing: 4) {
                Button(action: coordinator.foundIt) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Theme.black)
                        .frame(width: 64, height: 64)
                        .background(Theme.accent, in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("found_it")
                .accessibilityLabel(Text("found"))
                Text("found")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Theme.text1)
                    .accessibilityHidden(true)
            }

            if showsMapAndDirections {
                control(systemImage: "figure.walk", label: "directions", action: coordinator.openDirections)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private func control(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 4) {
            CircleIconButton(systemImage: systemImage, labelKey: label, filled: true, action: action)
            Text(LocalizedStringKey(label))
                .font(.caption2)
                .foregroundStyle(Theme.text2)
                .accessibilityHidden(true)
        }
    }

    // MARK: Copy

    private var showsMapAndDirections: Bool {
        if case .photoOnly = viewModel.display { return false }
        return spot.savedLocation != nil
    }

    /// The short line under the big number: the direction, or "you're here". Every other state says its
    /// line once, in `stateBlock`, so nothing is printed twice.
    private var caption: String {
        if let direction = viewModel.direction {
            return String(localized: String.LocalizationValue(direction.key))
        }
        if case .arrived = viewModel.display {
            return String(localized: "arrived")
        }
        return ""
    }

    private var savedAt: String {
        String(format: String(localized: "saved_at_fmt"),
               spot.createdAt.formatted(date: .omitted, time: .shortened))
    }
}
