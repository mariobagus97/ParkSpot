import SwiftUI

/// Home: the big "Park here" button and the recent spots.
struct HomeView: View {
    let coordinator: AppCoordinator

    @State private var viewModel: HomeViewModel

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        _viewModel = State(initialValue: HomeViewModel(repository: coordinator.deps.repository))
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                header
                parkButton
                recentSection
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .task { viewModel.reload() }
        .onChange(of: viewModel.filter) { viewModel.reload() }
        .onChange(of: coordinator.activeSpotID) { viewModel.reload() }   // parking again changes the shelf
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                PMark()
                Spacer()
            }
            Text("hello")
                .font(.title2.weight(.bold))
                .foregroundStyle(Theme.text1)
            HStack(spacing: 8) {
                ForEach(SpotFilter.allCases, id: \.self) { filter in
                    Chip(filter.key, isOn: viewModel.filter == filter) {
                        viewModel.filter = filter
                    }
                }
            }
        }
    }

    private var parkButton: some View {
        Button(action: coordinator.save.start) {
            VStack(spacing: 2) {
                Text(verbatim: "P")
                    .font(.system(size: 64, weight: .black))
                    .foregroundStyle(Theme.black)
                Text("park_here")
                    .font(.caption2.weight(.bold))
                    .textCase(.uppercase)
                    .tracking(1.6)
                    .foregroundStyle(Theme.black)
            }
            .frame(width: 168, height: 168)
            .background(Theme.accent, in: Circle())
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("park_button")
        .accessibilityLabel(Text("park_here"))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    @ViewBuilder private var recentSection: some View {
        if !viewModel.recent.isEmpty {
            Text("recent")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.text1)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(viewModel.recent) { spot in
                        VStack(alignment: .leading, spacing: 6) {
                            CoverArt(photos: coordinator.deps.photos,
                                     fileName: spot.photoFileName,
                                     tint: spot.photoTint,
                                     cornerRadius: 6)
                                .frame(width: 104, height: 104)
                            Text(verbatim: spot.placeName ?? String(localized: "unnamed"))
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(Theme.text1)
                                .lineLimit(1)
                            if let floor = spot.floor, !floor.isEmpty {
                                Text(verbatim: floor)
                                    .font(.caption2)
                                    .foregroundStyle(Theme.text2)
                            }
                        }
                        .frame(width: 104, alignment: .leading)
                    }
                }
            }
        }
    }
}
