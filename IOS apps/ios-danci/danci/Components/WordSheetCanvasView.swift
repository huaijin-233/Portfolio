import SwiftUI

struct WordSheetCanvasView: View {
    let page: WordSheetPage
    let fontStyle: WordSheetFontStyle

    var body: some View {
        GeometryReader { proxy in
            let templateSize = page.template.canvasSize
            let scale = min(
                proxy.size.width / max(templateSize.width, 1),
                proxy.size.height / max(templateSize.height, 1)
            )
            let canvasSize = CGSize(
                width: templateSize.width * scale,
                height: templateSize.height * scale
            )

            WordSheetRenderedPageView(
                page: page,
                renderSize: canvasSize,
                wordFontSize: page.template.previewWordFontSize,
                meaningFontSize: page.template.previewMeaningFontSize,
                fontStyle: fontStyle
            )
                .frame(width: canvasSize.width, height: canvasSize.height)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}

#Preview {
    let sampleEntries = [
        WordEntry(word: "benefit", note: "好处"),
        WordEntry(word: "effort", note: "努力")
    ]

    WordSheetCanvasView(
        page: WordSheetPage(
            template: .blue,
            pageIndex: 0,
            totalPageCount: 1,
            entries: sampleEntries
        ),
        fontStyle: .default
    )
    .padding()
    .background(AppColors.background)
}
