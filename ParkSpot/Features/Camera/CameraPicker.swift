import SwiftUI
import UIKit

/// The system camera with the standard controls and a read-only overlay: the "location locked" chip and a hint.
/// Taking a photo reports it through `onPhoto`; the Cancel button reports `onCancel`. Closing the cover is up to
/// the caller.
///
/// In DEBUG builds, where there is no camera (the simulator), it falls back to the photo library so the flow can
/// still be run. Release builds always ask for the camera.
struct CameraPicker: UIViewControllerRepresentable {
    /// "Location locked · ±8 m"; nil hides the chip until there is a position to report.
    let chipText: String?
    let onPhoto: (UIImage) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPhoto: onPhoto, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = OverlayPicker()
        picker.sourceType = Self.sourceType
        picker.delegate = context.coordinator
        if picker.sourceType == .camera {
            picker.cameraCaptureMode = .photo
            picker.showsCameraControls = true
            let overlay = context.coordinator.overlay
            overlay.rootView = CameraOverlay(chipText: chipText)
            overlay.view.backgroundColor = .clear
            overlay.view.isUserInteractionEnabled = false   // taps go to the system controls underneath
            picker.cameraOverlayView = overlay.view
            picker.overlay = overlay.view
        }
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {
        context.coordinator.onPhoto = onPhoto
        context.coordinator.onCancel = onCancel
        context.coordinator.overlay.rootView = CameraOverlay(chipText: chipText)
    }

    private static var sourceType: UIImagePickerController.SourceType {
        #if DEBUG
        UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        #else
        .camera
        #endif
    }

    @MainActor final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var onPhoto: (UIImage) -> Void
        var onCancel: () -> Void
        fileprivate let overlay = UIHostingController(rootView: CameraOverlay(chipText: nil))

        init(onPhoto: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onPhoto = onPhoto
            self.onCancel = onCancel
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onPhoto(image)
            } else {
                onCancel()   // nothing usable came back: same as no photo
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}

/// Keeps the overlay as large as the picker whatever size UIKit first gives it.
private final class OverlayPicker: UIImagePickerController {
    /// The camera overlay, kept here because reading `cameraOverlayView` throws unless the source is the camera.
    var overlay: UIView?

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        overlay?.frame = view.bounds
    }
}

/// The part of the screen that is ours: the chip and the hint, stacked at the top of the preview so they stay
/// clear of the system's flash row above it and its zoom and shutter controls below.
private struct CameraOverlay: View {
    let chipText: String?

    var body: some View {
        VStack(spacing: 10) {
            if let chipText {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 7, height: 7)
                    Text(verbatim: chipText)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.text1)
                }
                .padding(.horizontal, 13)
                .frame(minHeight: 30)
                .background(Theme.black.opacity(0.6), in: Capsule())
            }
            Text("photo_hint")
                .font(.callout.weight(.bold))
                .foregroundStyle(Theme.text1)
                .multilineTextAlignment(.center)
                .shadow(color: Theme.black.opacity(0.7), radius: 3, y: 1)
                .padding(.horizontal, 18)
        }
        .padding(.top, 72)   // below the system's top bar, where the preview starts
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
    }
}
