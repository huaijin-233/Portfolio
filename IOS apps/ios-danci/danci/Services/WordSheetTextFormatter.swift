import Foundation

enum WordSheetTextFormatter {
    static func word(_ text: String) -> String {
        normalized(text)
    }

    static func meaning(_ text: String) -> String {
        let cleaned = normalized(text)
        guard !cleaned.isEmpty else {
            return ""
        }

        let strongSeparators = CharacterSet(charactersIn: "\n;；/|")
        let firstClause = cleaned
            .components(separatedBy: strongSeparators)
            .first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? cleaned

        if firstClause.count <= 16 {
            return firstClause
        }

        let softerSeparators = CharacterSet(charactersIn: "，,、")
        let softClause = firstClause
            .components(separatedBy: softerSeparators)
            .first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? firstClause

        if softClause.count <= 16 {
            return softClause
        }

        return softClause.truncated(maxLength: 16)
    }
}

private extension WordSheetTextFormatter {
    static func normalized(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .collapsedSpaces()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension String {
    func collapsedSpaces() -> String {
        replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    func truncated(maxLength: Int) -> String {
        guard count > maxLength, maxLength > 1 else {
            return self
        }

        return String(prefix(maxLength - 1)) + "…"
    }
}
