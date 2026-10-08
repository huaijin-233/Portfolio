import Combine
import Foundation

@MainActor
final class VocabularyViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var isPresentingNewBook = false

    func prepareForNewBook() {
        isPresentingNewBook = true
    }
}
