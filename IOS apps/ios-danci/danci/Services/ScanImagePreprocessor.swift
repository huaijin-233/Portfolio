import UIKit

extension UIImage {
    nonisolated func preparedForScanInput(maxDimension: CGFloat = 2600) -> UIImage {
        let longestSide = max(size.width, size.height)
        let needsResize = longestSide > maxDimension
        let needsNormalization = imageOrientation != .up

        guard needsResize || needsNormalization else {
            return self
        }

        let targetSize: CGSize
        if needsResize {
            let scaleRatio = maxDimension / longestSide
            targetSize = CGSize(width: size.width * scaleRatio, height: size.height * scaleRatio)
        } else {
            targetSize = size
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false

        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
