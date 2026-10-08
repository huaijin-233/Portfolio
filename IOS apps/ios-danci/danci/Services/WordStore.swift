import Combine
import Foundation

struct BookImportResult {
    let createdBook: WordBook?
    let addedEntries: [WordEntry]
    let invalidWords: [String]
}

enum WordStoreError: LocalizedError {
    case emptyBookTitle
    case duplicateBookTitle
    case missingBook
    case insufficientBooksToMerge
    case emptyWord
    case invalidEnglishWord
    case wordTooShort
    case duplicateWord
    case missingWord

    var errorDescription: String? {
        switch self {
        case .emptyBookTitle:
            return "请先输入单词本名称。"
        case .duplicateBookTitle:
            return "这个单词本名称已经存在了，换一个更容易区分的名字吧。"
        case .missingBook:
            return "这个单词本暂时找不到了，请返回书架再试一次。"
        case .insufficientBooksToMerge:
            return "请至少选择两个单词本再合成。"
        case .emptyWord:
            return "请输入一个英文单词。"
        case .invalidEnglishWord:
            return "这里只支持英文单词，请去掉中文、数字或特殊符号。"
        case .wordTooShort:
            return "请输入至少 2 个字母的英文单词。"
        case .duplicateWord:
            return "这个单词已经在当前单词本里了。"
        case .missingWord:
            return "这个单词暂时找不到了，请返回列表再试一次。"
        }
    }
}

private struct WordStoreLoadResult {
    let books: [WordBook]
    let migratedFromLegacyWords: Bool
}

@MainActor
final class WordStore: ObservableObject {
    @Published private(set) var books: [WordBook] = []

    var totalWordCount: Int {
        books.reduce(0) { $0 + $1.words.count }
    }

    var allWords: [WordEntry] {
        books
            .flatMap(\.words)
            .sorted(by: Self.wordSort)
    }

    private let diskStore: WordDiskStore

    init(fileManager: FileManager = .default) {
        self.diskStore = WordDiskStore(fileManager: fileManager)

        Task {
            let loadResult = await diskStore.loadBooks()
            self.books = Self.sortedBooks(loadResult.books)

            if loadResult.migratedFromLegacyWords {
                persistBooks()
            }
        }
    }

    func book(with id: UUID) -> WordBook? {
        books.first(where: { $0.id == id })
    }

    func existingNotes(for rawWords: [String]) -> [String: String] {
        let normalizedTargets = Set(
            rawWords.compactMap { EnglishWordSanitizer.normalize($0, minimumLength: 2) }
        )
        guard !normalizedTargets.isEmpty else { return [:] }

        var notes: [String: String] = [:]

        for entry in books.flatMap(\.words) {
            guard normalizedTargets.contains(entry.word) else { continue }

            let sanitized = sanitizedNote(entry.note)
            guard !sanitized.isEmpty, notes[entry.word] == nil else { continue }
            notes[entry.word] = sanitized
        }

        return notes
    }

    @discardableResult
    func createManualBook(title: String) throws -> WordBook {
        let normalizedTitle = try validateBookTitle(title, excluding: nil)
        let book = WordBook(title: normalizedTitle, source: .manual)
        books.insert(book, at: 0)
        persistBooks()
        return book
    }

    @discardableResult
    func updateBook(id: UUID, title: String) throws -> WordBook {
        guard let index = books.firstIndex(where: { $0.id == id }) else {
            throw WordStoreError.missingBook
        }

        let normalizedTitle = try validateBookTitle(title, excluding: id)
        books[index].title = normalizedTitle
        books[index].updatedAt = Date()
        sortBooksInPlace()
        persistBooks()

        guard let updatedBook = book(with: id) else {
            throw WordStoreError.missingBook
        }

        return updatedBook
    }

    func deleteBook(id: UUID) {
        books.removeAll { $0.id == id }
        persistBooks()
    }

    @discardableResult
    func mergeBooks(ids: Set<UUID>) throws -> WordBook {
        guard ids.count >= 2 else {
            throw WordStoreError.insufficientBooksToMerge
        }

        let selectedBooks = books.filter { ids.contains($0.id) }
        guard selectedBooks.count == ids.count else {
            throw WordStoreError.missingBook
        }

        let mergedWords = selectedBooks.flatMap(\.words)
        let mergedBook = WordBook(
            title: uniqueMergedBookTitle(),
            source: selectedBooks.first?.source ?? .manual,
            words: mergedWords
        )

        books.removeAll { ids.contains($0.id) }
        books.insert(mergedBook, at: 0)
        persistBooks()
        return mergedBook
    }

    @discardableResult
    func addWord(toBook bookID: UUID, word: String, note: String) throws -> WordEntry {
        guard let bookIndex = books.firstIndex(where: { $0.id == bookID }) else {
            throw WordStoreError.missingBook
        }

        let normalizedWord = try validateWord(word, in: books[bookIndex], excluding: nil)
        let entry = WordEntry(
            word: normalizedWord,
            note: sanitizedNote(note),
            source: .manual
        )

        books[bookIndex].words.insert(entry, at: 0)
        books[bookIndex].updatedAt = Date()
        sortBooksInPlace()
        persistBooks()
        return entry
    }

    @discardableResult
    func updateWord(bookID: UUID, id: UUID, word: String, note: String) throws -> WordEntry {
        guard let bookIndex = books.firstIndex(where: { $0.id == bookID }) else {
            throw WordStoreError.missingBook
        }

        guard let wordIndex = books[bookIndex].words.firstIndex(where: { $0.id == id }) else {
            throw WordStoreError.missingWord
        }

        let normalizedWord = try validateWord(word, in: books[bookIndex], excluding: id)
        books[bookIndex].words[wordIndex].word = normalizedWord
        books[bookIndex].words[wordIndex].note = sanitizedNote(note)
        books[bookIndex].words[wordIndex].updatedAt = Date()
        books[bookIndex].updatedAt = Date()
        sortBooksInPlace()
        persistBooks()

        guard let updatedBook = book(with: bookID),
              let updatedWord = updatedBook.words.first(where: { $0.id == id }) else {
            throw WordStoreError.missingWord
        }

        return updatedWord
    }

    func deleteWord(bookID: UUID, id: UUID) {
        guard let bookIndex = books.firstIndex(where: { $0.id == bookID }) else {
            return
        }

        let originalCount = books[bookIndex].words.count
        books[bookIndex].words.removeAll { $0.id == id }

        guard books[bookIndex].words.count != originalCount else {
            return
        }

        books[bookIndex].updatedAt = Date()
        sortBooksInPlace()
        persistBooks()
    }

    @discardableResult
    func fillMissingNotes(bookID: UUID, translatedNotes: [String: String]) -> Int {
        guard let bookIndex = books.firstIndex(where: { $0.id == bookID }) else {
            return 0
        }

        var updatedCount = 0

        for index in books[bookIndex].words.indices {
            guard books[bookIndex].words[index].note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }

            let normalizedWord = books[bookIndex].words[index].word
            guard let translatedNote = translatedNotes[normalizedWord] else {
                continue
            }

            let sanitized = sanitizedNote(translatedNote)
            guard !sanitized.isEmpty else {
                continue
            }

            books[bookIndex].words[index].note = sanitized
            books[bookIndex].words[index].updatedAt = Date()
            updatedCount += 1
        }

        guard updatedCount > 0 else {
            return 0
        }

        books[bookIndex].updatedAt = Date()
        sortBooksInPlace()
        persistBooks()
        return updatedCount
    }

    func importScannedWords(
        _ rawWords: [String],
        translatedNotes: [String: String],
        source: WordSource
    ) -> BookImportResult {
        var addedEntries: [WordEntry] = []
        var invalidWords: [String] = []

        for rawWord in rawWords {
            guard let normalizedWord = EnglishWordSanitizer.normalize(rawWord, minimumLength: 2) else {
                invalidWords.append(rawWord)
                continue
            }

            let entry = WordEntry(
                word: normalizedWord,
                note: sanitizedNote(translatedNotes[normalizedWord] ?? ""),
                source: source
            )
            addedEntries.append(entry)
        }

        guard !addedEntries.isEmpty else {
            return BookImportResult(
                createdBook: nil,
                addedEntries: [],
                invalidWords: invalidWords
            )
        }

        let book = WordBook(
            title: uniqueScanBookTitle(for: source),
            source: source,
            words: addedEntries
        )

        books.insert(book, at: 0)
        let correctedEntries = correctImportedWords(inBook: book.id, entryIDs: addedEntries.map(\.id))
        persistBooks()

        return BookImportResult(
            createdBook: self.book(with: book.id),
            addedEntries: correctedEntries,
            invalidWords: invalidWords
        )
    }

    private func correctImportedWords(inBook bookID: UUID, entryIDs: [UUID]) -> [WordEntry] {
        guard let bookIndex = books.firstIndex(where: { $0.id == bookID }) else {
            return []
        }

        var targetIDs = Set(entryIDs)
        guard !targetIDs.isEmpty else { return [] }

        var changed = false
        var words = books[bookIndex].words

        for entryID in entryIDs {
            guard let index = words.firstIndex(where: { $0.id == entryID }) else {
                continue
            }

            let entry = words[index]
            guard targetIDs.contains(entry.id) else { continue }

            let correctedWord = EnglishWordAutoCorrector.correctIfNeeded(entry.word)
            guard correctedWord != entry.word else { continue }

            if let conflictIndex = words.firstIndex(where: {
                $0.id != entry.id && $0.word == correctedWord
            }) {
                let incomingNote = sanitizedNote(entry.note)
                let existingNote = sanitizedNote(words[conflictIndex].note)

                if existingNote.isEmpty, !incomingNote.isEmpty {
                    words[conflictIndex].note = incomingNote
                    words[conflictIndex].updatedAt = Date()
                }

                words.remove(at: index)
                targetIDs.remove(entry.id)
                changed = true
                continue
            }

            words[index].word = correctedWord
            words[index].updatedAt = Date()
            changed = true
        }

        if changed {
            books[bookIndex].words = words
            books[bookIndex].updatedAt = Date()
        }

        return words.filter { targetIDs.contains($0.id) }
    }

    private func validateBookTitle(_ rawTitle: String, excluding id: UUID?) throws -> String {
        let trimmed = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            throw WordStoreError.emptyBookTitle
        }

        let normalizedTitle = normalizedBookTitle(trimmed)
        if books.contains(where: { $0.id != id && normalizedBookTitle($0.title) == normalizedTitle }) {
            throw WordStoreError.duplicateBookTitle
        }

        return trimmed
    }

    private func validateWord(_ rawWord: String, in book: WordBook, excluding id: UUID?) throws -> String {
        let trimmed = rawWord.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            throw WordStoreError.emptyWord
        }

        guard EnglishWordSanitizer.normalize(trimmed) != nil else {
            throw WordStoreError.invalidEnglishWord
        }

        guard let normalized = EnglishWordSanitizer.normalize(trimmed, minimumLength: 2) else {
            throw WordStoreError.wordTooShort
        }

        if book.words.contains(where: { $0.id != id && $0.word == normalized }) {
            throw WordStoreError.duplicateWord
        }

        return normalized
    }

    private func sanitizedNote(_ note: String) -> String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedBookTitle(_ title: String) -> String {
        title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func uniqueScanBookTitle(for source: WordSource) -> String {
        let baseTitle = "\(source.title) \(Self.scanTitleFormatter.string(from: Date()))"
        var candidate = baseTitle
        var suffix = 2

        while books.contains(where: { normalizedBookTitle($0.title) == normalizedBookTitle(candidate) }) {
            candidate = "\(baseTitle) \(suffix)"
            suffix += 1
        }

        return candidate
    }

    private func uniqueMergedBookTitle() -> String {
        let baseTitle = "合成单词本 \(Self.scanTitleFormatter.string(from: Date()))"
        var candidate = baseTitle
        var suffix = 2

        while books.contains(where: { normalizedBookTitle($0.title) == normalizedBookTitle(candidate) }) {
            candidate = "\(baseTitle) \(suffix)"
            suffix += 1
        }

        return candidate
    }

    private func sortBooksInPlace() {
        books = Self.sortedBooks(books)
    }

    private func persistBooks() {
        let snapshot = books

        Task.detached(priority: .utility) { [diskStore] in
            await diskStore.saveBooks(snapshot)
        }
    }

    private static func sortedBooks(_ books: [WordBook]) -> [WordBook] {
        books
            .map { book in
                var normalizedBook = book
                normalizedBook.words.sort(by: wordSort)
                return normalizedBook
            }
            .sorted { lhs, rhs in
                if lhs.updatedAt == rhs.updatedAt {
                    return lhs.createdAt > rhs.createdAt
                }

                return lhs.updatedAt > rhs.updatedAt
            }
    }

    private static func wordSort(lhs: WordEntry, rhs: WordEntry) -> Bool {
        if lhs.updatedAt == rhs.updatedAt {
            return lhs.createdAt > rhs.createdAt
        }

        return lhs.updatedAt > rhs.updatedAt
    }

    private static let scanTitleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter
    }()
}

private actor WordDiskStore {
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager) {
        self.fileManager = fileManager

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func loadBooks() -> WordStoreLoadResult {
        let booksURL = makeSaveURL(fileName: "books.json")

        if let data = try? Data(contentsOf: booksURL),
           let books = try? decoder.decode([WordBook].self, from: data) {
            return WordStoreLoadResult(books: books, migratedFromLegacyWords: false)
        }

        let legacyWordsURL = makeSaveURL(fileName: "words.json")
        if let data = try? Data(contentsOf: legacyWordsURL),
           let legacyWords = try? decoder.decode([WordEntry].self, from: data),
           !legacyWords.isEmpty {
            let sortedWords = legacyWords.sorted { lhs, rhs in
                if lhs.updatedAt == rhs.updatedAt {
                    return lhs.createdAt > rhs.createdAt
                }

                return lhs.updatedAt > rhs.updatedAt
            }

            let migratedBook = WordBook(
                title: "历史单词本",
                createdAt: sortedWords.last?.createdAt ?? Date(),
                updatedAt: sortedWords.first?.updatedAt ?? Date(),
                source: .manual,
                words: sortedWords
            )

            return WordStoreLoadResult(books: [migratedBook], migratedFromLegacyWords: true)
        }

        return WordStoreLoadResult(books: [], migratedFromLegacyWords: false)
    }

    func saveBooks(_ books: [WordBook]) {
        let saveURL = makeSaveURL(fileName: "books.json")

        do {
            let data = try encoder.encode(books)
            try data.write(to: saveURL, options: .atomic)
        } catch {
            print("Failed to persist books: \(error)")
        }
    }

    private func makeSaveURL(fileName: String) -> URL {
        let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory

        let folderURL = baseDirectory.appendingPathComponent("ShengliWords", isDirectory: true)
        try? fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        return folderURL.appendingPathComponent(fileName)
    }
}
