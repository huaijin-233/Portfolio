//
//  JournalAttachmentLibrary.swift
//  Ink
//
//  Created by Codex on 3/13/26.
//

import Foundation
import UniformTypeIdentifiers

nonisolated struct JournalAttachmentImportPayload: Sendable {
    let attachment: JournalAttachment
    let data: Data
    let companionAudio: JournalAttachmentCompanionAudioPayload?
}

nonisolated struct JournalAttachmentCompanionAudioPayload: Sendable {
    let fileExtension: String
    let data: Data
}

enum JournalAttachmentLibraryError: LocalizedError {
    case unsupportedFile
    case unreadableData

    var errorDescription: String? {
        switch self {
        case .unsupportedFile:
            return "Unsupported file type."
        case .unreadableData:
            return "Unable to read the selected media."
        }
    }
}

nonisolated struct JournalAttachmentLibrary {
    let fileManager: FileManager
    let rootDirectory: URL

    init(fileManager: FileManager = .default, rootDirectory: URL) {
        self.fileManager = fileManager
        self.rootDirectory = rootDirectory
    }

    func url(for attachment: JournalAttachment, entryID: UUID) -> URL {
        directory(for: entryID).appendingPathComponent(attachment.filename)
    }

    func audioURL(for attachment: JournalAttachment, entryID: UUID) -> URL? {
        guard let audioFilename = attachment.audioFilename else {
            return nil
        }

        return directory(for: entryID).appendingPathComponent(audioFilename)
    }

    func data(for attachment: JournalAttachment, entryID: UUID) throws -> Data {
        try Data(contentsOf: url(for: attachment, entryID: entryID), options: [.mappedIfSafe])
    }

    func audioData(for attachment: JournalAttachment, entryID: UUID) throws -> Data? {
        guard let audioURL = audioURL(for: attachment, entryID: entryID),
              fileManager.fileExists(atPath: audioURL.path) else {
            return nil
        }

        return try Data(contentsOf: audioURL, options: [.mappedIfSafe])
    }

    @discardableResult
    func importFile(at sourceURL: URL, for entryID: UUID) throws -> JournalAttachment {
        try importFile(at: sourceURL, companionAudioAt: nil, for: entryID)
    }

    @discardableResult
    func importFile(at sourceURL: URL, companionAudioAt audioURL: URL?, for entryID: UUID) throws -> JournalAttachment {
        let attachment = try Self.makeAttachment(for: sourceURL, companionAudioAt: audioURL)
        try ensureDirectory(for: entryID)
        try copyFile(from: sourceURL, to: url(for: attachment, entryID: entryID))

        if let audioURL,
           let destinationAudioURL = self.audioURL(for: attachment, entryID: entryID) {
            try copyFile(from: audioURL, to: destinationAudioURL)
        }

        return attachment
    }

    @discardableResult
    func importData(
        _ data: Data,
        fileExtension: String,
        kind: JournalAttachmentKind,
        for entryID: UUID,
        originalFilename: String? = nil
    ) throws -> JournalAttachment {
        let payload = Self.payload(
            data: data,
            fileExtension: fileExtension,
            kind: kind,
            originalFilename: originalFilename
        )
        return try importPayload(payload, for: entryID)
    }

    @discardableResult
    func importPayload(_ payload: JournalAttachmentImportPayload, for entryID: UUID) throws -> JournalAttachment {
        let destinationURL = url(for: payload.attachment, entryID: entryID)

        try ensureDirectory(for: entryID)
        try payload.data.write(to: destinationURL, options: [.atomic])

        if let companionAudio = payload.companionAudio,
           let destinationAudioURL = audioURL(for: payload.attachment, entryID: entryID) {
            try companionAudio.data.write(to: destinationAudioURL, options: [.atomic])
        }

        return payload.attachment
    }

    func remove(_ attachment: JournalAttachment, from entryID: UUID) throws {
        let attachmentURL = url(for: attachment, entryID: entryID)

        guard fileManager.fileExists(atPath: attachmentURL.path) else {
            return
        }

        try fileManager.removeItem(at: attachmentURL)

        if let audioURL = audioURL(for: attachment, entryID: entryID),
           fileManager.fileExists(atPath: audioURL.path) {
            try fileManager.removeItem(at: audioURL)
        }
    }

    func removeAllAttachments(for entryID: UUID) throws {
        let directoryURL = directory(for: entryID)

        guard fileManager.fileExists(atPath: directoryURL.path) else {
            return
        }

        try fileManager.removeItem(at: directoryURL)
    }

    static func makeAttachment(for sourceURL: URL, companionAudioAt audioURL: URL? = nil) throws -> JournalAttachment {
        let kind = try kind(for: sourceURL)
        let fileExtension = normalizedFileExtension(for: sourceURL, kind: kind)
        let audioFileExtension = audioURL.map(Self.normalizedAudioFileExtension(for:))

        return JournalAttachment(
            kind: kind,
            fileExtension: fileExtension,
            audioFileExtension: audioFileExtension,
            originalFilename: sourceURL.lastPathComponent
        )
    }

    static func payload(from sourceURL: URL) throws -> JournalAttachmentImportPayload {
        try payload(from: sourceURL, companionAudioAt: nil)
    }

    static func payload(from sourceURL: URL, companionAudioAt audioURL: URL?) throws -> JournalAttachmentImportPayload {
        let attachment = try makeAttachment(for: sourceURL, companionAudioAt: audioURL)
        let data = try Data(contentsOf: sourceURL, options: [.mappedIfSafe])

        guard !data.isEmpty else {
            throw JournalAttachmentLibraryError.unreadableData
        }

        let companionAudio: JournalAttachmentCompanionAudioPayload?
        if let audioURL {
            let audioData = try Data(contentsOf: audioURL, options: [.mappedIfSafe])
            guard !audioData.isEmpty else {
                throw JournalAttachmentLibraryError.unreadableData
            }

            companionAudio = JournalAttachmentCompanionAudioPayload(
                fileExtension: normalizedAudioFileExtension(for: audioURL),
                data: audioData
            )
        } else {
            companionAudio = nil
        }

        return JournalAttachmentImportPayload(
            attachment: attachment,
            data: data,
            companionAudio: companionAudio
        )
    }

    static func payload(
        data: Data,
        fileExtension: String,
        kind: JournalAttachmentKind,
        originalFilename: String? = nil,
        companionAudio: JournalAttachmentCompanionAudioPayload? = nil
    ) -> JournalAttachmentImportPayload {
        let attachment = JournalAttachment(
            kind: kind,
            fileExtension: normalizedFileExtension(fileExtension, kind: kind),
            audioFileExtension: companionAudio?.fileExtension,
            originalFilename: originalFilename
        )

        return JournalAttachmentImportPayload(
            attachment: attachment,
            data: data,
            companionAudio: companionAudio
        )
    }

    private func ensureDirectory(for entryID: UUID) throws {
        try fileManager.createDirectory(
            at: directory(for: entryID),
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    private func directory(for entryID: UUID) -> URL {
        rootDirectory.appendingPathComponent(entryID.uuidString, isDirectory: true)
    }

    private func copyFile(from sourceURL: URL, to destinationURL: URL) throws {
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.copyItem(at: sourceURL, to: destinationURL)
    }

    private static func kind(for sourceURL: URL) throws -> JournalAttachmentKind {
        let contentType = try sourceURL.resourceValues(forKeys: [.contentTypeKey]).contentType
            ?? UTType(filenameExtension: sourceURL.pathExtension)

        guard let contentType else {
            throw JournalAttachmentLibraryError.unsupportedFile
        }

        if contentType.conforms(to: .image) {
            return .image
        }

        if contentType.conforms(to: .movie) || contentType.conforms(to: .audiovisualContent) {
            return .video
        }

        throw JournalAttachmentLibraryError.unsupportedFile
    }

    private static func normalizedFileExtension(for sourceURL: URL, kind: JournalAttachmentKind) -> String {
        normalizedFileExtension(sourceURL.pathExtension, kind: kind)
    }

    private static func normalizedAudioFileExtension(for sourceURL: URL) -> String {
        let trimmed = sourceURL.pathExtension
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .lowercased()

        return trimmed.isEmpty ? "m4a" : trimmed
    }

    private static func normalizedFileExtension(_ fileExtension: String, kind: JournalAttachmentKind) -> String {
        let trimmed = fileExtension
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .lowercased()

        guard !trimmed.isEmpty else {
            return kind == .image ? "png" : "mov"
        }

        return trimmed
    }
}
