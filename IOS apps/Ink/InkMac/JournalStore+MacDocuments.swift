#if os(macOS)
//
//  JournalStore+MacDocuments.swift
//  Ink
//
//  Created by Codex on 3/14/26.
//

import Foundation

extension JournalStore {
    func exportDocument(for entryID: UUID) throws -> InkJournalDocument {
        guard let entry = entry(for: entryID) else {
            throw CocoaError(.fileNoSuchFile)
        }

        var embeddedAttachments: [String: Data] = [:]

        for attachment in entry.attachments {
            embeddedAttachments[attachment.filename] = try attachmentLibrary.data(for: attachment, entryID: entryID)
            if let audioData = try attachmentLibrary.audioData(for: attachment, entryID: entryID),
               let audioFilename = attachment.audioFilename {
                embeddedAttachments[audioFilename] = audioData
            }
        }

        return InkJournalDocument(entry: entry, embeddedAttachments: embeddedAttachments)
    }

    func prepareDocument(for entryID: UUID) async throws -> InkJournalDocument {
        guard let entry = entry(for: entryID) else {
            throw CocoaError(.fileNoSuchFile)
        }

        let entrySnapshot = entry
        let attachmentRootDirectory = attachmentRootDirectory

        return try await Task.detached(priority: .userInitiated) {
            let library = JournalAttachmentLibrary(
                fileManager: .default,
                rootDirectory: attachmentRootDirectory
            )
            var embeddedAttachments: [String: Data] = [:]

            for attachment in entrySnapshot.attachments {
                embeddedAttachments[attachment.filename] = try library.data(for: attachment, entryID: entryID)
                if let audioData = try library.audioData(for: attachment, entryID: entryID),
                   let audioFilename = attachment.audioFilename {
                    embeddedAttachments[audioFilename] = audioData
                }
            }

            return InkJournalDocument(entry: entrySnapshot, embeddedAttachments: embeddedAttachments)
        }.value
    }
}
#endif
