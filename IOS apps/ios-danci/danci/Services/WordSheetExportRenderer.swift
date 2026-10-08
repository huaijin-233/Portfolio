import SwiftUI
import UIKit

@MainActor
enum WordSheetExportRenderer {
    static func render(
        page: WordSheetPage,
        fontStyle: WordSheetFontStyle = .default
    ) -> UIImage? {
        let size = page.template.canvasSize
        let content = WordSheetRenderedPageView(
            page: page,
            renderSize: size,
            wordFontSize: page.template.exportWordFontSize,
            meaningFontSize: page.template.exportMeaningFontSize,
            fontStyle: fontStyle
        )
            .frame(width: size.width, height: size.height)
            .background(Color.white)

        let renderer = ImageRenderer(content: content)
        renderer.scale = max(size.longestSide > 3000 ? 1 : 3, 1)
        renderer.proposedSize = ProposedViewSize(size)
        return renderer.uiImage
    }
}

private extension CGSize {
    var longestSide: CGFloat {
        max(width, height)
    }
}
