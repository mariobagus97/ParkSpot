import ImageIO
import UIKit

@MainActor protocol PhotoStoring: AnyObject {
    /// Stores `image` as a JPEG and returns its file name (`<uuid>.jpg`). Creates the directory if needed; throws if it can't write.
    func save(_ image: UIImage) throws -> String
    func image(named: String) -> UIImage?
    func thumbnail(named: String, maxPixel: Int) -> UIImage?
    func delete(named: String)
}

enum PhotoStoreError: Error {
    case encodingFailed
}

/// Keeps spot photos as JPEG files in one directory.
@MainActor final class PhotoStore: PhotoStoring {
    static let maxPixel: CGFloat = 2048
    static let jpegQuality: CGFloat = 0.8

    private let directory: URL

    init(directory: URL) {
        self.directory = directory
    }

    /// Application Support/Photos.
    static func live() -> PhotoStore {
        PhotoStore(directory: URL.applicationSupportDirectory.appending(path: "Photos", directoryHint: .isDirectory))
    }

    func save(_ image: UIImage) throws -> String {
        guard let data = Self.downscaled(image).jpegData(compressionQuality: Self.jpegQuality) else {
            throw PhotoStoreError.encodingFailed
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = "\(UUID().uuidString).jpg"
        try data.write(to: fileURL(name), options: .atomic)
        return name
    }

    func image(named name: String) -> UIImage? {
        UIImage(contentsOfFile: fileURL(name).path)
    }

    func thumbnail(named name: String, maxPixel: Int) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(fileURL(name) as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: thumbnail)
    }

    func delete(named name: String) {
        try? FileManager.default.removeItem(at: fileURL(name))
    }

    private func fileURL(_ name: String) -> URL {
        directory.appending(path: name)
    }

    /// Draws `image` upright at scale 1 with its longest side at most `maxPixel` pixels. Never upscales.
    private static func downscaled(_ image: UIImage) -> UIImage {
        let width = image.size.width * image.scale
        let height = image.size.height * image.scale
        let factor = min(1, maxPixel / max(width, height))
        let size = CGSize(width: max(1, (width * factor).rounded()), height: max(1, (height * factor).rounded()))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.preferredRange = .standard     // an 8-bit JPEG does not need an extended-range bitmap
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
