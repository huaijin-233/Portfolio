import Foundation

enum EnglishWordSanitizer {
    nonisolated private static let looseRegex = try? NSRegularExpression(
        pattern: #"[A-Za-z]+(?:['’\-][A-Za-z]+)*"#
    )
    nonisolated private static let strictRegex = try? NSRegularExpression(
        pattern: #"^[A-Za-z]+(?:['’\-][A-Za-z]+)*$"#
    )

    nonisolated static func matches(in text: String) -> [NSTextCheckingResult] {
        guard let looseRegex else { return [] }

        return looseRegex.matches(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text))
    }

    nonisolated static func normalize(_ rawWord: String, minimumLength: Int = 2) -> String? {
        let trimmed = rawWord
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")

        guard !trimmed.isEmpty else { return nil }

        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        guard let strictRegex else { return nil }
        guard strictRegex.firstMatch(in: trimmed, range: range)?.range == range else {
            return nil
        }

        let normalized = trimmed.lowercased()
        guard letterCount(in: normalized) >= minimumLength else {
            return nil
        }

        return normalized
    }

    nonisolated private static func letterCount(in text: String) -> Int {
        text.unicodeScalars.reduce(into: 0) { partialResult, scalar in
            if CharacterSet.letters.contains(scalar) {
                partialResult += 1
            }
        }
    }
}
