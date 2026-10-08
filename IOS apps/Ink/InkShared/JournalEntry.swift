//
//  JournalEntry.swift
//  Ink
//
//  Created by Codex on 3/13/26.
//

import Foundation

nonisolated struct JournalEntry: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let createdAt: Date
    var updatedAt: Date
    var title: String
    var body: String
    var attachments: [JournalAttachment]

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        title: String = "",
        body: String = "",
        attachments: [JournalAttachment] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.title = title
        self.body = body
        self.attachments = attachments
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled" : trimmed
    }

    var previewText: String {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Start writing..." : trimmed
    }

    var attachmentCount: Int {
        attachments.count
    }

    var wordCount: Int {
        body.split { $0.isWhitespace || $0.isNewline }.count
    }

    var documentFilename: String {
        let safeTitle = displayTitle
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        return "\(safeTitle).inkjournal"
    }
}
