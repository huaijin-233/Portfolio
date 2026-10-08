import Foundation
import Photos
import UIKit

@MainActor
enum WordSheetPhotoLibrarySaver {
    enum SaveError: LocalizedError {
        case imageEncodingFailed
        case accessDenied
        case saveFailed

        var title: String {
            switch self {
            case .imageEncodingFailed:
                return "保存失败"
            case .accessDenied:
                return "需要相册权限"
            case .saveFailed:
                return "保存失败"
            }
        }

        var message: String {
            switch self {
            case .imageEncodingFailed:
                return "这一页生成失败了，请稍后再试一次。"
            case .accessDenied:
                return "请在系统设置里允许“\(WordSheetPhotoLibraryContext.appDisplayName)”保存图片到相册。"
            case .saveFailed:
                return "这张表格暂时没有保存成功，请稍后再试一次。"
            }
        }
    }

    static func save(image: UIImage) async throws {
        let status = await requestAuthorizationIfNeeded()
        guard status == .authorized || status == .limited else {
            throw SaveError.accessDenied
        }

        guard let imageData = image.pngData() else {
            throw SaveError.imageEncodingFailed
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: imageData, options: nil)
            } completionHandler: { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: SaveError.saveFailed)
                }
            }
        }
    }
}

private enum WordSheetPhotoLibraryContext {
    static let appDisplayName: String = {
        if let displayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
           !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return displayName
        }

        if let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String,
           !appName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return appName
        }

        return "这个 App"
    }()
}

private extension WordSheetPhotoLibrarySaver {
    static func requestAuthorizationIfNeeded() async -> PHAuthorizationStatus {
        let current = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        guard current == .notDetermined else {
            return current
        }

        return await PHPhotoLibrary.requestAuthorization(for: .addOnly)
    }
}
