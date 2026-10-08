import Foundation
import UIKit

@MainActor
enum EnglishWordAutoCorrector {
    static func correctIfNeeded(_ word: String) -> String {
        guard word.count >= 4 else { return word }
        guard let normalized = EnglishWordSanitizer.normalize(word, minimumLength: 2) else {
            return word
        }

        let checker = UITextChecker()
        let nsRange = NSRange(location: 0, length: normalized.utf16.count)
        let misspelledRange = checker.rangeOfMisspelledWord(
            in: normalized,
            range: nsRange,
            startingAt: 0,
            wrap: false,
            language: "en_US"
        )

        guard misspelledRange.location != NSNotFound else {
            return normalized
        }

        let guesses = checker.guesses(
            forWordRange: nsRange,
            in: normalized,
            language: "en_US"
        ) ?? []

        for guess in guesses {
            guard let candidate = EnglishWordSanitizer.normalize(guess, minimumLength: 2) else {
                continue
            }

            if candidate == normalized {
                return normalized
            }

            let maxDistance = normalized.count >= 8 ? 2 : 1
            guard levenshteinDistance(between: normalized, and: candidate) <= maxDistance else {
                continue
            }

            return candidate
        }

        return normalized
    }

    private static func levenshteinDistance(between lhs: String, and rhs: String) -> Int {
        let lhsChars = Array(lhs)
        let rhsChars = Array(rhs)

        guard !lhsChars.isEmpty else { return rhsChars.count }
        guard !rhsChars.isEmpty else { return lhsChars.count }

        var previous = Array(0...rhsChars.count)
        var current = Array(repeating: 0, count: rhsChars.count + 1)

        for (lhsIndex, lhsChar) in lhsChars.enumerated() {
            current[0] = lhsIndex + 1

            for (rhsIndex, rhsChar) in rhsChars.enumerated() {
                let substitutionCost = lhsChar == rhsChar ? 0 : 1
                current[rhsIndex + 1] = min(
                    previous[rhsIndex + 1] + 1,
                    current[rhsIndex] + 1,
                    previous[rhsIndex] + substitutionCost
                )
            }

            swap(&previous, &current)
        }

        return previous[rhsChars.count]
    }
}
