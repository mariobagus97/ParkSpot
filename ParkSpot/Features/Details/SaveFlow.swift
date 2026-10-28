import OSLog
import SwiftUI
import UIKit

extension View {
    /// Attaches everything the save flow presents: its alerts, the camera or camera-denied cover and the details
    /// sheet. All of it is driven by `coordinator`; nothing here decides what happens next.
    func saveFlow(_ coordinator: SaveCoordinator, deps: AppDependencies, saver: SpotSaver) -> some View {
        modifier(SaveFlowModifier(coordinator: coordinator, deps: deps, saver: saver))
    }
}

extension SaveCoordinator.Cover: Identifiable {
    var id: String {
        switch self {
        case .camera: "camera"
        case .cameraDenied: "cameraDenied"
        }
    }
}

private struct SaveFlowModifier: ViewModifier {
    let coordinator: SaveCoordinator
    let deps: AppDependencies
    let saver: SpotSaver

    /// The sheet's model, built when the coordinator reports a saved spot. It lives here, not in the sheet, so a
    /// swipe-down and the Done button can both write the floor and note.
    @State private var details: SpotDetailsViewModel?

    func body(content: Content) -> some View {
        content
            .alert(alertTitle, isPresented: .constant(coordinator.alert != nil), presenting: coordinator.alert) { alert in
                alertActions(alert)
            } message: { alert in
                alertMessage(alert)
            }
            .fullScreenCover(item: .constant(coordinator.cover)) { cover in
                coverContent(cover)
            }
            .sheet(item: detailsBinding) { viewModel in
                SpotDetailsSheet(viewModel: viewModel, photos: deps.photos, onDone: finishDetails)
            }
            .onChange(of: coordinator.detailsSpotID) { _, id in
                openDetails(for: id)
            }
    }

    // MARK: Alerts

    private var alertTitle: LocalizedStringKey {
        switch coordinator.alert {
        case .confirmReplace: "replace_t"
        case .photoRequired: "photo_required_t"
        case .saveFailed: "save_failed_t"
        case nil: ""
        }
    }

    @ViewBuilder
    private func alertActions(_ alert: SaveCoordinator.Alert) -> some View {
        switch alert {
        case .confirmReplace:
            Button("replace", role: .destructive) { coordinator.confirmReplace() }
            Button("cancel", role: .cancel) { coordinator.cancel() }
        case .photoRequired:
            Button("take_photo") { coordinator.retakePhoto() }
            Button("cancel", role: .cancel) { coordinator.cancel() }
        case .saveFailed:
            Button("done") { coordinator.cancel() }
        }
    }

    @ViewBuilder
    private func alertMessage(_ alert: SaveCoordinator.Alert) -> some View {
        switch alert {
        case .confirmReplace:
            let name = coordinator.replacingPlaceName ?? String(localized: "unnamed")
            Text(verbatim: String(format: String(localized: "replace_b_fmt"), name))
        case .photoRequired:
            EmptyView()
        case .saveFailed:
            Text("save_failed_b")
        }
    }

    // MARK: Covers

    @ViewBuilder
    private func coverContent(_ cover: SaveCoordinator.Cover) -> some View {
        switch cover {
        case .camera:
            camera(chipText: lockedChip,
                   onPhoto: coordinator.photoTaken,
                   onCancel: coordinator.cameraCancelled)
        case .cameraDenied:
            PermissionView(titleKey: "cam_t", bodyKey: "cam_b", onNotNow: coordinator.cancel)
        }
    }

    /// "Location locked · ±8 m" once there is a position; before that the camera shows no claim.
    /// The system camera on a device; a stand-in screen in the simulator, which has no camera at all.
    @ViewBuilder
    private func camera(chipText: String?, onPhoto: @escaping (UIImage) -> Void,
                        onCancel: @escaping () -> Void) -> some View {
        #if DEBUG
        if !UIImagePickerController.isSourceTypeAvailable(.camera) {
            MockCameraView(chipText: chipText, onPhoto: onPhoto, onCancel: onCancel)
                .ignoresSafeArea()
        } else {
            systemCamera(chipText: chipText, onPhoto: onPhoto, onCancel: onCancel)
        }
        #else
        systemCamera(chipText: chipText, onPhoto: onPhoto, onCancel: onCancel)
        #endif
    }

    private func systemCamera(chipText: String?, onPhoto: @escaping (UIImage) -> Void,
                              onCancel: @escaping () -> Void) -> some View {
        CameraPicker(chipText: chipText, onPhoto: onPhoto, onCancel: onCancel)
            .ignoresSafeArea()
            .background(Theme.black)
    }

    private var lockedChip: String? {
        guard let accuracy = saver.currentAccuracy else { return nil }
        return String(format: String(localized: "loc_locked_fmt"), Formatting.accuracy(accuracy, locale: .current))
    }

    // MARK: Details

    /// Setting it to nil is the user swiping the sheet away.
    private var detailsBinding: Binding<SpotDetailsViewModel?> {
        Binding(get: { details }, set: { if $0 == nil { finishDetails() } })
    }

    private func openDetails(for id: UUID?) {
        guard let id else {
            details = nil   // the coordinator ended the details (`finishDetails` has already cleared it)
            return
        }
        if let spot = try? deps.repository.spot(id: id) {
            details = SpotDetailsViewModel(spot: spot, saver: saver, repository: deps.repository, location: deps.location)
        } else {
            coordinator.detailsDone()   // nothing to describe: don't leave the flow open
        }
    }

    /// Done button or swipe-down. The spot is already stored, so a failed write of floor and note is not an error
    /// worth stopping for: they stay pending in the context and the next save retries them.
    private func finishDetails() {
        guard let viewModel = details else { return }
        do {
            try viewModel.done()
        } catch {
            Logger(subsystem: "com.mariobagus.parkspot", category: "save")
                .error("floor/note not saved: \(error, privacy: .public); the spot itself is stored")
        }
        details = nil
        coordinator.detailsDone()
    }
}

extension SpotDetailsViewModel: Identifiable {}
