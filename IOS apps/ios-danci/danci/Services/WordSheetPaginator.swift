import Foundation

enum WordSheetPaginator {
    static func paginate(
        entries: [WordEntry],
        template: WordSheetTemplate
    ) -> [WordSheetPage] {
        let wordsPerPage = max(template.wordsPerPage, 1)
        let chunks = entries.chunked(into: wordsPerPage)

        guard !chunks.isEmpty else {
            return [
                WordSheetPage(
                    template: template,
                    pageIndex: 0,
                    totalPageCount: 1,
                    entries: []
                )
            ]
        }

        return chunks.enumerated().map { index, chunk in
            WordSheetPage(
                template: template,
                pageIndex: index,
                totalPageCount: chunks.count,
                entries: chunk
            )
        }
    }

    static func paginate(
        book: WordBook,
        template: WordSheetTemplate
    ) -> [WordSheetPage] {
        paginate(entries: book.words, template: template)
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0, !isEmpty else {
            return isEmpty ? [] : [self]
        }

        var result: [[Element]] = []
        var startIndex = 0

        while startIndex < count {
            let endIndex = Swift.min(startIndex + size, count)
            result.append(Array(self[startIndex..<endIndex]))
            startIndex += size
        }

        return result
    }
}
