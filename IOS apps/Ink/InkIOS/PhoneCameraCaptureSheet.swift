//
//  PhoneCameraCaptureSheet.swift
//  Ink
//
//  Created by Codex on 3/14/26.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

enum PhoneCameraCaptureResult: Sendable {
    case photo(Data)
    case video(URL)
}

struct PhoneCameraCaptureSheet: UIViewControllerRepresentable {
    let onCapture: @MainActor (PhoneCameraCaptureResult) -> Void
    let onCancel: @MainActor () -> Void
    let onError: @MainActor (Error) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onCancel: onCancel, onError: onError)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = [UTType.image.identifier, UTType.movie.identifier]
        picker.videoQuality = .typeMedium
        picker.cameraCaptureMode = .photo
        picker.modalPresentationStyle = .fullScreen
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onCapture: @MainActor (PhoneCameraCaptureResult) -> Void
        private let onCancel: @MainActor () -> Void
        private let onError: @MainActor (Error) -> Void

        init(
            onCapture: @escaping @MainActor (PhoneCameraCaptureResult) -> Void,
            onCancel: @escaping @MainActor () -> Void,
            onError: @escaping @MainActor (Error) -> Void
        ) {
            self.onCapture = onCapture
            self.onCancel = onCancel
            self.onError = onError
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true) {
                Task { @MainActor in
                    self.onCancel()
                }
            }
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let result: Result<PhoneCameraCaptureResult, Error>

            if let mediaType = info[.mediaType] as? String, mediaType == UTType.movie.identifier {
                if let url = info[.mediaURL] as? URL {
                    result = .success(.video(url))
                } else {
                    result = .failure(PhoneCameraCaptureError.missingVideoFile)
                }
            } else if let image = info[.originalImage] as? UIImage,
                      let jpegData = image.jpegData(compressionQuality: 0.92) {
                result = .success(.photo(jpegData))
            } else {
                result = .failure(PhoneCameraCaptureError.unreadablePhoto)
            }

            picker.dismiss(animated: true) {
                Task { @MainActor in
                    switch result {
                    case .success(let capture):
                        self.onCapture(capture)
                    case .failure(let error):
                        self.onError(error)
                    }
                }
            }
        }
    }
}

private enum PhoneCameraCaptureError: LocalizedError {
    case unreadablePhoto
    case missingVideoFile

    var errorDescription: String? {
        switch self {
        case .unreadablePhoto:
            return "Ink5 couldn't read this photo capture."
        case .missingVideoFile:
            return "Ink5 couldn't find the recorded video file."
        }
    }
}
