//
//  InkJournalDocument.swift
//  Ink
//
//  Created by Codex on 3/13/26.
//

import SwiftUI
import UniformTypeIdentifiers

nonisolated struct InkJournalDocument: FileDocument, Sendable {
    static var readableContentTypes: [UTType] = [.inkJournal]

    var entry: JournalEntry
    private var embeddedAttachments: [String: Data]

    init(entry: JournalEntry = JournalEntry(), embeddedAttachments: [String: Data] = [:]) {
        self.entry = entry
        self.embeddedAttachments = embeddedAttachments
    }

    init(configuration: ReadConfiguration) throws {
        let decoder = JSONDecoder()

        if let data = configuration.file.regularFileContents {
            if let payload = try? decoder.decode(Payload.self, from: data) {
                entry = payload.entry
            } else {
                entry = try decoder.decode(JournalEntry.self, from: data)
            }

            embeddedAttachments = [:]
            return
        }

        guard configuration.file.isDirectory,
              let fileWrappers = configuration.file.fileWrappers,
              let entryData = fileWrappers["entry.json"]?.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }

        if let payload = try? decoder.decode(Payload.self, from: entryData) {
            entry = payload.entry
        } else {
            entry = try decoder.decode(JournalEntry.self, from: entryData)
        }

        let attachmentWrappers = fileWrappers["Attachments"]?.fileWrappers ?? [:]
        embeddedAttachments = [:]

        for attachment in entry.attachments {
            embeddedAttachments[attachment.filename] = attachmentWrappers[attachment.filename]?.regularFileContents
            if let audioFilename = attachment.audioFilename {
                embeddedAttachments[audioFilename] = attachmentWrappers[audioFilename]?.regularFileContents
            }
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let payload = Payload(entry: entry)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let entryData = try encoder.encode(payload)

        var fileWrappers: [String: FileWrapper] = [
            "entry.json": FileWrapper(regularFileWithContents: entryData)
        ]

        if !entry.attachments.isEmpty {
            var attachmentWrappers: [String: FileWrapper] = [:]

            for attachment in entry.attachments {
                guard let data = embeddedAttachments[attachment.filename] else {
                    continue
                }

                attachmentWrappers[attachment.filename] = FileWrapper(regularFileWithContents: data)

                if let audioFilename = attachment.audioFilename,
                   let audioData = embeddedAttachments[audioFilename] {
                    attachmentWrappers[audioFilename] = FileWrapper(regularFileWithContents: audioData)
                }
            }

            fileWrappers["Attachments"] = FileWrapper(directoryWithFileWrappers: attachmentWrappers)
        }

        return FileWrapper(directoryWithFileWrappers: fileWrappers)
    }

    var suggestedFilename: String {
        entry.documentFilename
    }

    func data(for attachment: JournalAttachment) -> Data? {
        embeddedAttachments[attachment.filename]
    }

    func audioData(for attachment: JournalAttachment) -> Data? {
        guard let audioFilename = attachment.audioFilename else {
            return nil
        }

        return embeddedAttachments[audioFilename]
    }

    mutating func addAttachment(_ payload: JournalAttachmentImportPayload) {
        embeddedAttachments[payload.attachment.filename] = payload.data
        if let companionAudio = payload.companionAudio,
           let audioFilename = payload.attachment.audioFilename {
            embeddedAttachments[audioFilename] = companionAudio.data
        }
        entry.attachments.append(payload.attachment)
        entry.updatedAt = .now
    }

    mutating func removeAttachment(_ attachmentID: UUID) {
        guard let attachmentIndex = entry.attachments.firstIndex(where: { $0.id == attachmentID }) else {
            return
        }

        let attachment = entry.attachments.remove(at: attachmentIndex)
        embeddedAttachments.removeValue(forKey: attachment.filename)
        if let audioFilename = attachment.audioFilename {
            embeddedAttachments.removeValue(forKey: audioFilename)
        }
        entry.updatedAt = .now
    }
}

private extension InkJournalDocument {
    nonisolated struct Payload: Codable, Sendable {
        let version: Int
        var entry: JournalEntry

        init(version: Int = 2, entry: JournalEntry) {
            self.version = version
            self.entry = entry
        }
    }
}
