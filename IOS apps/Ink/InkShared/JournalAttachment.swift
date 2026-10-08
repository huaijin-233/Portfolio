//
//  JournalAttachment.swift
//  Ink
//
//  Created by Codex on 3/13/26.
//

import Foundation
import UniformTypeIdentifiers

enum JournalAttachmentKind: String, Codable, Hashable, Sendable {
    case image
    case video

    var contentType: UTType {
        switch self {
        case .image:
            return .image
        case .video:
            return .movie
        }
    }
}

nonisolated struct JournalAttachment: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let kind: JournalAttachmentKind
    let fileExtension: String
    let audioFileExtension: String?
    let originalFilename: String?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        kind: JournalAttachmentKind,
        fileExtension: String,
        audioFileExtension: String? = nil,
        originalFilename: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.kind = kind
        self.fileExtension = fileExtension
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .lowercased()
        self.audioFileExtension = audioFileExtension?
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .lowercased()
        self.originalFilename = originalFilename
        self.createdAt = createdAt
    }

    var filename: String {
        "\(id.uuidString).\(fileExtension)"
    }

    var displayName: String {
        if let originalFilename,
           !originalFilename.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return originalFilename
        }

        return filename
    }

    var audioFilename: String? {
        guard let audioFileExtension else {
            return nil
        }

        return "\(id.uuidString)-audio.\(audioFileExtension)"
    }
}
