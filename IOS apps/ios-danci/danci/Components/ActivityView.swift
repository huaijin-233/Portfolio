import SwiftUI
import UIKit

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> ActivityPresenterViewController {
        let controller = ActivityPresenterViewController()
        controller.activityItems = activityItems
        return controller
    }

    func updateUIViewController(_ uiViewController: ActivityPresenterViewController, context: Context) {
        uiViewController.activityItems = activityItems
    }
}

final class ActivityPresenterViewController: UIViewController {
    var activityItems: [Any] = []

    private var hasPresentedActivity = false

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard !hasPresentedActivity else { return }
        hasPresentedActivity = true

        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )

        if let popover = controller.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(
                x: view.bounds.midX,
                y: view.bounds.midY,
                width: 1,
                height: 1
            )
            popover.permittedArrowDirections = []
        }

        controller.completionWithItemsHandler = { [weak self] _, _, _, _ in
            self?.dismiss(animated: true)
        }

        present(controller, animated: true)
    }
}
