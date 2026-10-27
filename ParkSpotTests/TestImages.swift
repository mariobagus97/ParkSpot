import UIKit

extension UIImage {
    /// A flat-colour bitmap of exactly `w` x `h` pixels (scale 1, standard colour range).
    static func solid(_ w: Int = 10, _ h: Int = 10, _ color: UIColor = .red) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: CGSize(width: w, height: h), format: format).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: w, height: h))
        }
    }
}

/// True when `a` is within `tolerance` of `b` on each of the red, green and blue channels (both 0xRRGGBB).
func near(_ a: Int?, _ b: Int, tolerance: Int = 2) -> Bool {
    guard let a else { return false }
    return [16, 8, 0].allSatisfy { shift in
        abs(((a >> shift) & 0xFF) - ((b >> shift) & 0xFF)) <= tolerance
    }
}
