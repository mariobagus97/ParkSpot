import AVFoundation
import UIKit

enum CameraStatus: Sendable { case notDetermined, denied, authorized, unavailable }

@MainActor protocol CameraAuthorizing: AnyObject {
    func status() -> CameraStatus
    func request() async -> Bool
}

/// Camera permission through `AVCaptureDevice`; `.unavailable` where there is no camera (the simulator).
@MainActor final class CameraAccess: CameraAuthorizing {
    func status() -> CameraStatus {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { return .unavailable }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined: return .notDetermined
        case .authorized: return .authorized
        case .denied, .restricted: return .denied
        @unknown default: return .denied
        }
    }

    func request() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }
}
