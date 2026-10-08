import Foundation

struct WordBook: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    let createdAt: Date
    var updatedAt: Date
    var source: WordSource
    var words: [WordEntry]

    nonisolated init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        source: WordSource = .manual,
        words: [WordEntry] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.source = source
        self.words = words
    }
}

extension WordBook {
    nonisolated var wordCount: Int {
        words.count
    }

    nonisolated var previewWords: [String] {
        Array(words.prefix(3).map(\.word))
    }

    static let mock = WordBook(
        title: "英语阅读摘录",
        source: .normalScan,
        words: [
            .mock,
            WordEntry(word: "mentor", note: "a trusted adviser", source: .manual),
            WordEntry(word: "outline", note: "the main shape", source: .normalScan)
        ]
    )
}
