import SwiftUI
import UIKit

struct DocumentScannerView: UIViewControllerRepresentable {
    let onCancel: () -> Void
    let onComplete: ([UIImage]) -> Void
    let onError: (Error) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.delegate = context.coordinator
        controller.sourceType = .camera
        controller.cameraCaptureMode = .photo
        controller.modalPresentationStyle = .fullScreen
        controller.allowsEditing = false
        return controller
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
}

extension DocumentScannerView {
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: DocumentScannerView
        private var hasCompleted = false

        init(parent: DocumentScannerView) {
            self.parent = parent
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            guard markCompletedIfNeeded() else { return }

            picker.dismiss(animated: true) {
                self.parent.onCancel()
            }
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard markCompletedIfNeeded() else { return }

            guard let originalImage = info[.originalImage] as? UIImage else {
                let error = NSError(
                    domain: "DocumentScannerView",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to capture image."]
                )
                picker.dismiss(animated: true) {
                    self.parent.onError(error)
                }
                return
            }

            let scanImage = originalImage.preparedForScanInput()
            picker.dismiss(animated: true) {
                self.parent.onComplete([scanImage])
            }
        }

        private func markCompletedIfNeeded() -> Bool {
            guard !hasCompleted else { return false }
            hasCompleted = true
            return true
        }
    }
}
