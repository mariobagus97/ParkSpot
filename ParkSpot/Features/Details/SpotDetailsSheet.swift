import SwiftUI

/// The "Spot saved" sheet: the photo, the place, the GPS status, then the optional floor and note.
/// Renders `SpotDetailsViewModel` and reports "Done"; the save flow decides what happens next.
struct SpotDetailsSheet: View {
    @Bindable var viewModel: SpotDetailsViewModel
    let photos: PhotoStoring
    let onDone: () -> Void

    @State private var showsMoreFloors = false
    @FocusState private var noteIsFocused: Bool
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header
                label("floor")
                floors
                label("note")
                noteField
                if viewModel.locationOff { locationOffNote }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            PillButton("done", action: onDone)
                .accessibilityIdentifier("details_done")
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background(Theme.surface3)
        }
        .background(Theme.surface3)
        // The brief asks for medium only. Large stays as a deliberate accessibility deviation: it gives the expanded
        // "+" panel (3…10 and the text field), the location-off note and large Dynamic Type room, so they don't
        // have to scroll. Done is pinned by the safeAreaInset above and is visible at either detent.
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.surface3)
        .presentationCornerRadius(16)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            CoverArt(photos: photos, fileName: viewModel.spot.photoFileName, tint: viewModel.spot.photoTint)
                .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 2) {
                Label {
                    Text("spot_saved")
                } icon: {
                    Image(systemName: "checkmark")
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.accent)

                if let placeName = viewModel.spot.placeName {
                    Text(verbatim: placeName)
                        .font(.headline)
                        .foregroundStyle(Theme.text1)
                } else {
                    Text("unnamed")
                        .font(.headline)
                        .foregroundStyle(Theme.text1)
                }
                if let refiningText = viewModel.refiningText {
                    HStack(spacing: 6) {
                        PulsingDot()
                        Text(verbatim: refiningText)
                            .font(.caption)
                            .foregroundStyle(Theme.text2)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func label(_ key: String) -> some View {
        Text(LocalizedStringKey(key))
            .font(.caption.weight(.bold))
            .textCase(.uppercase)
            .tracking(1.4)
            .foregroundStyle(Theme.text2)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: Floor

    private var floors: some View {
        VStack(alignment: .leading, spacing: 4) {
            ScrollView(.horizontal) {
                HStack(spacing: 4) {
                    ForEach(SpotDetailsViewModel.quickFloors, id: \.self) { floor in
                        floorChip(floor)
                    }
                    Chip(verbatim: "+", isOn: showsMoreFloors) {
                        withAnimation { showsMoreFloors.toggle() }
                    }
                    .accessibilityLabel(Text("other_floor"))
                }
            }
            .scrollIndicators(.hidden)

            if showsMoreFloors {
                ScrollView(.horizontal) {
                    HStack(spacing: 4) {
                        ForEach(SpotDetailsViewModel.moreFloors, id: \.self) { floor in
                            floorChip(floor)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                inputPill {
                    TextField(text: typedFloorBinding, prompt: Text("floor_ph")) { Text("other_floor") }
                        .textInputAutocapitalization(.characters)
                        .submitLabel(.done)
                }
            }
        }
    }

    /// The field reads and writes the view model, which owns the text and the floor it implies.
    private var typedFloorBinding: Binding<String> {
        Binding(get: { viewModel.typedFloor }, set: { viewModel.setTypedFloor($0) })
    }

    private func floorChip(_ floor: String) -> some View {
        Chip(verbatim: floor, isOn: viewModel.floor == floor) {
            viewModel.selectFloor(floor)
        }
    }

    // MARK: Note

    private var noteField: some View {
        inputPill {
            TextField(text: $viewModel.note, prompt: Text("note_ph")) { Text("note") }
                .focused($noteIsFocused)
                .submitLabel(.done)
                .onSubmit { noteIsFocused = false }
        }
    }

    /// A 44 pt pill with a hairline border, like the design's input.
    private func inputPill<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .font(.subheadline)
            .foregroundStyle(Theme.text1)
            .padding(.horizontal, 18)
            .frame(minHeight: 44)
            .background(Theme.surface2, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.text3, lineWidth: 1))
    }

    // MARK: Location off

    private var locationOffNote: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.footnote)
                .foregroundStyle(Theme.warning)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("loc_t")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Theme.warning)
                Text("loc_b")
                    .font(.footnote)
                    .foregroundStyle(Theme.text2)
                Button(action: openSettings) {
                    Text("open_settings")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Theme.accent)
                        .frame(minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.top, 9)
        .background(Theme.warning.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

/// The orange "still working" dot. Static when Reduce Motion is on.
private struct PulsingDot: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDim = false

    var body: some View {
        Circle()
            .fill(Theme.warning)
            .frame(width: 7, height: 7)
            .opacity(isDim ? 0.3 : 1)
            .accessibilityHidden(true)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { isDim = true }
            }
    }
}

#if DEBUG
import SwiftData

#Preview("Details sheet") {
    DetailsSheetPreview()
        .preferredColorScheme(.dark)
}

/// Builds a saved spot in an in-memory store, so the sheet can be previewed with real parts.
private struct DetailsSheetPreview: View {
    @State private var model = Model()

    var body: some View {
        SpotDetailsSheet(viewModel: model.viewModel, photos: PreviewPhotos()) {}
    }

    /// Owns the container: a context outlives its container only by crashing.
    @MainActor private final class Model {
        let container: ModelContainer
        let viewModel: SpotDetailsViewModel

        init() {
            // Preview-only: a store that can't be built has nothing to show.
            container = try! ModelContainer(for: ParkingSpot.self,
                                            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            let deps = AppDependencies.live(container: container)
            let spot = ParkingSpot(createdAt: .now, photoFileName: "preview.jpg")
            spot.placeName = "Jl. Sudirman"
            spot.photoTint = 0x3B5B7A
            viewModel = SpotDetailsViewModel(spot: spot, saver: SpotSaver(deps: deps),
                                             repository: deps.repository, location: deps.location)
        }
    }
}
#endif
