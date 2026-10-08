import Foundation

struct WordEntry: Identifiable, Codable, Hashable {
    let id: UUID
    var word: String
    var note: String
    let createdAt: Date
    var updatedAt: Date
    var source: WordSource

    init(
        id: UUID = UUID(),
        word: String,
        note: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        source: WordSource = .manual
    ) {
        self.id = id
        self.word = word
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.source = source
    }
}

extension WordEntry {
    static let mock = WordEntry(
        word: "effort",
        note: "to use physical or mental energy",
        source: .normalScan
    )
}
