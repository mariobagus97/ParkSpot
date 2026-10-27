import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// The average colour of a photo, used to tint a spot's row and card.
enum PhotoTint {
    private static let maxSide: CGFloat = 64

    /// The average colour of `image` as 0xRRGGBB in sRGB, or nil when the image cannot be read.
    static func average(of image: UIImage) -> Int? {
        let small = downscaled(image)
        guard let input = CIImage(image: small), !input.extent.isEmpty else { return nil }
        let filter = CIFilter.areaAverage()
        filter.inputImage = input
        filter.extent = input.extent
        guard let output = filter.outputImage else { return nil }

        // No working colour space, so the filter averages the sRGB values as stored.
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(output, toBitmap: &pixel, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
        return Int(pixel[0]) << 16 | Int(pixel[1]) << 8 | Int(pixel[2])
    }

    /// A copy of `image` whose longest side is at most `maxSide` pixels, drawn as standard-range sRGB.
    private static func downscaled(_ image: UIImage) -> UIImage {
        let width = image.size.width * image.scale
        let height = image.size.height * image.scale
        let factor = min(1, maxSide / max(width, height))
        let size = CGSize(width: max(1, (width * factor).rounded()), height: max(1, (height * factor).rounded()))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
