import SwiftUI

/// Your spots: the list of saved spots, with search, chips and swipe actions.
struct HistoryView: View {
    @Bindable var coordinator: HistoryCoordinator
    let deps: AppDependencies

    @State private var viewModel: HistoryViewModel

    init(coordinator: HistoryCoordinator, deps: AppDependencies) {
        self.coordinator = coordinator
        self.deps = deps
        _viewModel = State(initialValue: HistoryViewModel(repository: deps.repository))
    }

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            ZStack {
                Theme.bg.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 10) {
                    header
                    list
                }
            }
            .navigationDestination(for: HistoryCoordinator.Route.self) { route in
                switch route {
                case let .detail(id):
                    if let spot = try? deps.repository.spot(id: id) {
                        SpotDetailView(spot: spot, coordinator: coordinator, deps: deps)
                    }
                }
            }
        }
        .tint(Theme.accent)
        .task { viewModel.reload() }
        .onChange(of: viewModel.filter) { viewModel.reload() }
        .alert("replace_t",
               isPresented: Binding(get: { coordinator.confirmUseAgainFor != nil },
                                    set: { if !$0 { coordinator.cancelUseAgain() } })) {
            Button("cancel", role: .cancel) { coordinator.cancelUseAgain() }
            Button("replace", role: .destructive) { coordinator.confirmUseAgain() }
        } message: {
            Text(verbatim: replaceMessage)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                PMark()
                Text("tab_lib")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Theme.text1)
                Spacer()
            }
            HStack(spacing: 8) {
                ForEach(SpotFilter.allCases, id: \.self) { filter in
                    Chip(filter.key, isOn: viewModel.filter == filter) {
                        viewModel.filter = filter
                    }
                }
            }
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.text2)
                    .accessibilityHidden(true)
                TextField("search", text: Binding(get: { viewModel.query },
                                                  set: { viewModel.search($0) }))
                    .textFieldStyle(.plain)
                    .foregroundStyle(Theme.text1)
            }
            .font(.footnote)
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    @ViewBuilder private var list: some View {
        if viewModel.rows.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "parkingsign")
                    .font(.largeTitle)
                    .foregroundStyle(Theme.text2)
                    .accessibilityHidden(true)
                Text("no_spots")
                    .font(.subheadline)
                    .foregroundStyle(Theme.text2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(viewModel.rows) { spot in
                    row(spot)
                        .listRowBackground(Theme.bg)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { coordinator.delete(spot.id) } label: {
                                Label("delete", systemImage: "trash")
                            }
                            Button { coordinator.useAgain(spot.id) } label: {
                                Label("use_again", systemImage: "arrow.clockwise")
                            }
                            .tint(Theme.accent)
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    private func row(_ spot: ParkingSpot) -> some View {
        Button { coordinator.showDetail(spot.id) } label: {
            HStack(spacing: 11) {
                CoverArt(photos: deps.photos, fileName: spot.photoFileName, tint: spot.photoTint, cornerRadius: 4)
                    .frame(width: 52, height: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: spot.placeName ?? String(localized: "noloc"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(spot.isActive ? Theme.accent : Theme.text1)
                        .lineLimit(1)
                    Text(verbatim: subtitle(spot))
                        .font(.caption2)
                        .foregroundStyle(Theme.text2)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                if let floor = spot.floor, !floor.isEmpty {
                    Text(verbatim: floor)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.text1)
                        .padding(.horizontal, 6)
                        .frame(minHeight: 24)
                        .overlay { RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.line, lineWidth: 1) }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func subtitle(_ spot: ParkingSpot) -> String {
        let time = spot.createdAt.formatted(date: .omitted, time: .shortened)
        return spot.isActive ? "\(String(localized: "active")) · \(time)" : time
    }

    private var replaceMessage: String {
        let name = coordinator.confirmUseAgainFor
            .flatMap { try? deps.repository.spot(id: $0) }?
            .placeName ?? String(localized: "unnamed")
        return String(format: String(localized: "replace_b_fmt"), name)
    }
}
