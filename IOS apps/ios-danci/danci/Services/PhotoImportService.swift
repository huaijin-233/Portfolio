import Photos
import PhotosUI
import SwiftUI
import UIKit

enum PhotoImportService {
    static func loadImage(from item: PhotosPickerItem, maxDimension: CGFloat = 2600) async -> UIImage? {
        if let image = await loadDownsampledImage(from: item, maxDimension: maxDimension) {
            return image
        }

        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            return nil
        }

        return image.preparedForScanInput(maxDimension: maxDimension)
    }
}

private extension PhotoImportService {
    static func loadDownsampledImage(from item: PhotosPickerItem, maxDimension: CGFloat) async -> UIImage? {
        guard let identifier = item.itemIdentifier else { return nil }

        let result = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = result.firstObject else { return nil }

        let targetSize = targetSize(for: asset, maxDimension: maxDimension)
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false

        return await withCheckedContinuation { continuation in
            let resumeBox = PhotoImportContinuationBox()
            let requestID = PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) == true
                if isDegraded {
                    return
                }

                resumeBox.resumeIfNeeded(
                    continuation,
                    returning: image?.preparedForScanInput(maxDimension: maxDimension)
                )
            }

            Task {
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                guard resumeBox.markTimeoutIfNeeded() else { return }

                PHImageManager.default().cancelImageRequest(requestID)
                continuation.resume(returning: nil)
            }
        }
    }

    static func targetSize(for asset: PHAsset, maxDimension: CGFloat) -> CGSize {
        let width = CGFloat(asset.pixelWidth)
        let height = CGFloat(asset.pixelHeight)
        let longestSide = max(width, height)

        guard longestSide > maxDimension, longestSide > 0 else {
            return CGSize(width: max(width, 1), height: max(height, 1))
        }

        let scale = maxDimension / longestSide
        return CGSize(width: max(width * scale, 1), height: max(height * scale, 1))
    }
}

private final class PhotoImportContinuationBox: @unchecked Sendable {
    private let lock = NSLock()
    private var didResume = false

    func resumeIfNeeded(
        _ continuation: CheckedContinuation<UIImage?, Never>,
        returning image: UIImage?
    ) {
        lock.lock()
        guard !didResume else {
            lock.unlock()
            return
        }

        didResume = true
        lock.unlock()
        continuation.resume(returning: image)
    }

    func markTimeoutIfNeeded() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard !didResume else { return false }
        didResume = true
        return true
    }
}
