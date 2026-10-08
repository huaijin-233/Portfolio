import SwiftUI

enum WordSheetFontStyle: String, CaseIterable, Identifiable {
    case `default`
    case timesNewRoman
    case arialItalic
    case helveticaBold

    var id: String { rawValue }

    var title: String {
        switch self {
        case .default:
            return "默认字体"
        case .timesNewRoman:
            return "Times New Roman"
        case .arialItalic:
            return "Arial Italic"
        case .helveticaBold:
            return "Helvetica Bold"
        }
    }
}

struct WordSheetRenderedPageView: View {
    let page: WordSheetPage
    let renderSize: CGSize
    let wordFontSize: CGFloat
    let meaningFontSize: CGFloat
    let fontStyle: WordSheetFontStyle

    init(
        page: WordSheetPage,
        renderSize: CGSize,
        wordFontSize: CGFloat = 15,
        meaningFontSize: CGFloat = 15,
        fontStyle: WordSheetFontStyle = .default
    ) {
        self.page = page
        self.renderSize = renderSize
        self.wordFontSize = wordFontSize
        self.meaningFontSize = meaningFontSize
        self.fontStyle = fontStyle
    }

    var body: some View {
        ZStack {
            Image(page.template.assetName)
                .resizable()
                .interpolation(.high)
                .frame(width: renderSize.width, height: renderSize.height)

            ForEach(Array(page.template.rows.enumerated()), id: \.offset) { index, row in
                if let wordValue = page.displayWord(at: index) {
                    wordText(wordValue, in: row.wordFrame(in: renderSize))
                }

                if let meaningValue = page.displayMeaning(at: index), !meaningValue.isEmpty {
                    meaningText(meaningValue, in: row.meaningFrame(in: renderSize))
                }
            }
        }
        .frame(width: renderSize.width, height: renderSize.height)
    }
}

private extension WordSheetRenderedPageView {
    func wordText(_ text: String, in frame: CGRect) -> some View {
        Text(text)
            .font(wordFont)
            .foregroundStyle(AppColors.primaryText)
            .multilineTextAlignment(.leading)
            .lineLimit(1)
            .minimumScaleFactor(0.42)
            .allowsTightening(true)
            .frame(width: frame.width, height: frame.height, alignment: .leading)
            .position(x: frame.midX, y: frame.midY)
    }

    func meaningText(_ text: String, in frame: CGRect) -> some View {
        Text(text)
            .font(meaningFont)
            .foregroundStyle(AppColors.primaryText)
            .multilineTextAlignment(.leading)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
            .frame(width: frame.width, height: frame.height, alignment: .leading)
            .position(x: frame.midX, y: frame.midY)
    }

    var wordFont: Font {
        font(for: wordFontSize)
    }

    var meaningFont: Font {
        font(for: meaningFontSize)
    }

    func font(for size: CGFloat) -> Font {
        switch fontStyle {
        case .default:
            return .system(size: size, weight: .semibold, design: .rounded)
        case .timesNewRoman:
            return .custom("TimesNewRomanPSMT", size: size)
        case .arialItalic:
            return .custom("Arial-ItalicMT", size: size)
        case .helveticaBold:
            return .custom("Helvetica-Bold", size: size)
        }
    }
}
