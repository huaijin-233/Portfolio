import Combine
import Foundation

@MainActor
final class StudySessionViewModel: ObservableObject {
    @Published private(set) var selectedWordID: UUID?
    @Published var isMeaningVisible = false

    func sync(with words: [WordEntry]) {
        guard !words.isEmpty else {
            selectedWordID = nil
            isMeaningVisible = false
            return
        }

        if let selectedWordID,
           words.contains(where: { $0.id == selectedWordID }) {
            return
        }

        selectedWordID = words.first?.id
        isMeaningVisible = false
    }

    func currentWord(in words: [WordEntry]) -> WordEntry? {
        guard let selectedWordID else {
            return words.first
        }

        return words.first(where: { $0.id == selectedWordID }) ?? words.first
    }

    func currentIndex(in words: [WordEntry]) -> Int? {
        guard let currentWord = currentWord(in: words) else {
            return nil
        }

        return words.firstIndex(where: { $0.id == currentWord.id })
    }

    func canGoPrevious(in words: [WordEntry]) -> Bool {
        guard let currentIndex = currentIndex(in: words) else {
            return false
        }

        return currentIndex > 0
    }

    func canGoNext(in words: [WordEntry]) -> Bool {
        guard let currentIndex = currentIndex(in: words) else {
            return false
        }

        return currentIndex < words.count - 1
    }

    func goPrevious(in words: [WordEntry]) {
        guard let currentIndex = currentIndex(in: words),
              currentIndex > 0 else {
            return
        }

        selectedWordID = words[currentIndex - 1].id
        isMeaningVisible = false
    }

    func goNext(in words: [WordEntry]) {
        guard let currentIndex = currentIndex(in: words),
              currentIndex < words.count - 1 else {
            return
        }

        selectedWordID = words[currentIndex + 1].id
        isMeaningVisible = false
    }
}
