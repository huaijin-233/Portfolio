import Foundation

struct WordSheetPage: Identifiable, Hashable {
    let template: WordSheetTemplate
    let pageIndex: Int
    let totalPageCount: Int
    let entries: [WordEntry]

    var id: String {
        "\(template.id)-\(pageIndex)"
    }

    var pageNumber: Int {
        pageIndex + 1
    }

    var isFirstPage: Bool {
        pageIndex == 0
    }

    var isLastPage: Bool {
        pageNumber == totalPageCount
    }

    subscript(rowIndex: Int) -> WordEntry? {
        guard entries.indices.contains(rowIndex) else {
            return nil
        }

        return entries[rowIndex]
    }

    func displayWord(at rowIndex: Int) -> String? {
        guard let entry = self[rowIndex] else {
            return nil
        }

        return WordSheetTextFormatter.word(entry.word)
    }

    func displayMeaning(at rowIndex: Int) -> String? {
        guard let entry = self[rowIndex] else {
            return nil
        }

        return WordSheetTextFormatter.meaning(entry.note)
    }
}
