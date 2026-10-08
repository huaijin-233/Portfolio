import CoreGraphics
import Foundation

struct WordSheetRowLayout: Identifiable, Hashable {
    let index: Int
    let normalizedWordFrame: CGRect
    let normalizedMeaningFrame: CGRect

    var id: Int { index }

    func wordFrame(in canvasSize: CGSize) -> CGRect {
        normalizedWordFrame.scaled(to: canvasSize)
    }

    func meaningFrame(in canvasSize: CGSize) -> CGRect {
        normalizedMeaningFrame.scaled(to: canvasSize)
    }
}

struct WordSheetTemplate: Identifiable, Hashable {
    let id: String
    let title: String
    let assetName: String
    let canvasSize: CGSize
    let rows: [WordSheetRowLayout]

    var wordsPerPage: Int {
        rows.count
    }

    var previewWordFontSize: CGFloat {
        switch id {
        case "big", "dictation", "date", "example":
            return 6
        default:
            return 15
        }
    }

    var previewMeaningFontSize: CGFloat {
        switch id {
        case "big", "dictation", "date", "example":
            return 6
        default:
            return 15
        }
    }

    var exportWordFontSize: CGFloat {
        switch id {
        case "big", "dictation", "date", "example":
            return 80
        default:
            return 20
        }
    }

    var exportMeaningFontSize: CGFloat {
        switch id {
        case "big", "dictation", "date", "example":
            return 80
        default:
            return 20
        }
    }
}

extension WordSheetTemplate {
    static let blue = WordSheetTemplate(
        id: "blue",
        title: "小表格蓝",
        assetName: "WordFormBlue",
        canvasSize: CGSize(width: 975, height: 975),
        rows: rows(for: .blue, canvasSize: CGSize(width: 975, height: 975))
    )

    static let green = WordSheetTemplate(
        id: "green",
        title: "小表格绿",
        assetName: "WordFormGreen",
        canvasSize: CGSize(width: 975, height: 975),
        rows: rows(for: .green, canvasSize: CGSize(width: 975, height: 975))
    )

    static let pink = WordSheetTemplate(
        id: "pink",
        title: "小表格粉",
        assetName: "WordFormPink",
        canvasSize: CGSize(width: 975, height: 975),
        rows: rows(for: .pink, canvasSize: CGSize(width: 975, height: 975))
    )

    static let white = WordSheetTemplate(
        id: "white",
        title: "小表格",
        assetName: "WordFormWhite",
        canvasSize: CGSize(width: 927, height: 921),
        rows: rows(for: .white, canvasSize: CGSize(width: 927, height: 921))
    )

    static let big = WordSheetTemplate(
        id: "big",
        title: "表格",
        assetName: "WordFormBig",
        canvasSize: CGSize(width: 4762, height: 6735),
        rows: rows(for: .big, canvasSize: CGSize(width: 4762, height: 6735))
    )

    static let date = WordSheetTemplate(
        id: "date",
        title: "日期表格",
        assetName: "WordFormDate",
        canvasSize: CGSize(width: 4762, height: 6735),
        rows: rows(for: .date, canvasSize: CGSize(width: 4762, height: 6735))
    )

    static let dictation = WordSheetTemplate(
        id: "dictation",
        title: "默写表格",
        assetName: "WordFormBig",
        canvasSize: CGSize(width: 4762, height: 6735),
        rows: rows(for: .dictation, canvasSize: CGSize(width: 4762, height: 6735))
    )

    static let example = WordSheetTemplate(
        id: "example",
        title: "例句表格",
        assetName: "WordFormExample",
        canvasSize: CGSize(width: 4762, height: 6735),
        rows: rows(for: .example, canvasSize: CGSize(width: 4762, height: 6735))
    )

    static let all: [WordSheetTemplate] = [
        .big,
        .date,
        .dictation,
        .example,
        .white,
        .blue,
        .green,
        .pink,
    ]
}

private extension WordSheetTemplate {
    enum TemplateKey {
        case blue
        case green
        case pink
        case white
        case big
        case dictation
        case date
        case example
    }

    static func rows(for key: TemplateKey, canvasSize: CGSize) -> [WordSheetRowLayout] {
        switch key {
        case .blue:
            return makeRows(
                columnPairs: [(21, 486, 950)],
                rowBoundaries: [100, 188, 275, 361, 446, 532, 618, 705, 791, 878, 965],
                canvasSize: canvasSize
            )
        case .green:
            return makeRows(
                columnPairs: [(23, 488, 952)],
                rowBoundaries: [99, 187, 273, 359, 445, 530, 616, 702, 787, 873, 961],
                canvasSize: canvasSize
            )
        case .pink:
            return makeRows(
                columnPairs: [(11, 486, 963)],
                rowBoundaries: [105, 193, 278, 364, 449, 534, 619, 704, 789, 875, 967],
                canvasSize: canvasSize
            )
        case .white:
            return makeRows(
                columnPairs: [(0, 462, 926)],
                rowBoundaries: [78, 163, 248, 331, 415, 499, 584, 667, 751, 835, 918],
                canvasSize: canvasSize
            )
        case .big:
            return makeRows(
                columnPairs: [
                    (227, 1190, 2381),
                    (2381, 3571, 4535)
                ],
                rowBoundaries: [
                    705, 891, 1076, 1262, 1448, 1633, 1819,
                    2004, 2190, 2376, 2561, 2747, 2932, 3118, 3304,
                    3489, 3675, 3860, 4046, 4232, 4417, 4603, 4788,
                    4974, 5160, 5345, 5531, 5716, 5902, 6088, 6273
                ],
                canvasSize: canvasSize,
                wordPixelOffset: CGPoint(x: 66, y: -32),
                meaningPixelOffset: CGPoint(x: 44, y: -32)
            )
        case .dictation:
            return makeRows(
                columnPairs: [(227, 1190, 2381)],
                rowBoundaries: [
                    705, 891, 1076, 1262, 1448, 1633, 1819,
                    2004, 2190, 2376, 2561, 2747, 2932, 3118, 3304,
                    3489, 3675, 3860, 4046, 4232, 4417, 4603, 4788,
                    4974, 5160, 5345, 5531, 5716, 5902, 6088, 6273
                ],
                canvasSize: canvasSize,
                wordPixelOffset: CGPoint(x: 66, y: -32),
                meaningPixelOffset: CGPoint(x: 44, y: -32)
            )
        case .date:
            return makeRows(
                columnPairs: [(227, 1190, 2381)],
                rowBoundaries: [
                    705, 891, 1076, 1262, 1448, 1633, 1819,
                    2004, 2190, 2376, 2561, 2747, 2932, 3118, 3304,
                    3489, 3675, 3860, 4046, 4232, 4417, 4603, 4788,
                    4974, 5160, 5345, 5531, 5716, 5902, 6088, 6273
                ],
                canvasSize: canvasSize,
                wordPixelOffset: CGPoint(x: 66, y: -32),
                meaningPixelOffset: CGPoint(x: 44, y: -32)
            )
        case .example:
            return makeRows(
                columnPairs: [(227, 1190, 2381)],
                rowBoundaries: [
                    705, 891, 1076, 1262, 1448, 1633, 1819,
                    2004, 2190, 2376, 2561, 2747, 2932, 3118, 3304,
                    3489, 3675, 3860, 4046, 4232, 4417, 4603, 4788,
                    4974, 5160, 5345, 5531, 5716, 5902, 6088, 6273
                ],
                canvasSize: canvasSize,
                wordPixelOffset: CGPoint(x: 66, y: -32),
                meaningPixelOffset: CGPoint(x: 44, y: -32)
            )
        }
    }

    static func makeRows(
        columnPairs: [(leftBorder: CGFloat, centerDivider: CGFloat, rightBorder: CGFloat)],
        rowBoundaries: [CGFloat],
        canvasSize: CGSize,
        wordPixelOffset: CGPoint = .zero,
        meaningPixelOffset: CGPoint = .zero
    ) -> [WordSheetRowLayout] {
        guard rowBoundaries.count >= 2, canvasSize.width > 0, canvasSize.height > 0 else {
            return []
        }

        let normalizedBoundaries = rowBoundaries.map { $0 / canvasSize.height }
        let rowCount = normalizedBoundaries.count - 1

        return columnPairs.enumerated().flatMap { pairIndex, pair in
            let normalizedLeftBorder = pair.leftBorder / canvasSize.width
            let normalizedCenterDivider = pair.centerDivider / canvasSize.width
            let normalizedRightBorder = pair.rightBorder / canvasSize.width
            let wordColumnWidth = normalizedCenterDivider - normalizedLeftBorder
            let meaningColumnWidth = normalizedRightBorder - normalizedCenterDivider
            let normalizedWordXOffset = wordPixelOffset.x / canvasSize.width
            let normalizedWordYOffset = wordPixelOffset.y / canvasSize.height
            let normalizedMeaningXOffset = meaningPixelOffset.x / canvasSize.width
            let normalizedMeaningYOffset = meaningPixelOffset.y / canvasSize.height

            return (0..<rowCount).map { rowIndex in
                let rowTop = normalizedBoundaries[rowIndex]
                let rowBottom = normalizedBoundaries[rowIndex + 1]
                let rowHeight = rowBottom - rowTop
                let horizontalPadding = 20.0 / canvasSize.width
                let verticalPadding = min(
                    max(rowHeight * 0.16, 10.0 / canvasSize.height),
                    15.0 / canvasSize.height
                )
                let wordFrameTop = rowTop + verticalPadding
                let wordFrameHeight = max(rowHeight - (verticalPadding * 2), 0)

                let normalizedWordFrame = CGRect(
                    x: normalizedLeftBorder + horizontalPadding + normalizedWordXOffset,
                    y: wordFrameTop + normalizedWordYOffset,
                    width: wordColumnWidth - (horizontalPadding * 2),
                    height: wordFrameHeight
                )

                let normalizedMeaningFrame = CGRect(
                    x: normalizedCenterDivider + horizontalPadding + normalizedMeaningXOffset,
                    y: wordFrameTop + normalizedMeaningYOffset,
                    width: meaningColumnWidth - (horizontalPadding * 2),
                    height: wordFrameHeight
                )

                return WordSheetRowLayout(
                    index: pairIndex * rowCount + rowIndex,
                    normalizedWordFrame: normalizedWordFrame,
                    normalizedMeaningFrame: normalizedMeaningFrame
                )
            }
        }
    }
}

private extension CGRect {
    func scaled(to size: CGSize) -> CGRect {
        CGRect(
            x: origin.x * size.width,
            y: origin.y * size.height,
            width: width * size.width,
            height: height * size.height
        )
    }
}
