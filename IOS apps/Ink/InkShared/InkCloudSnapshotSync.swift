//
//  InkCloudSnapshotSync.swift
//  Ink
//
//  Created by Codex on 3/14/26.
//

import CloudKit
import Foundation

nonisolated struct InkCloudSyncState: Codable, Sendable {
    var lastLocalMutationAt: Date
    var lastResolvedCloudModifiedAt: Date?

    init(
        lastLocalMutationAt: Date = .distantPast,
        lastResolvedCloudModifiedAt: Date? = nil
    ) {
        self.lastLocalMutationAt = lastLocalMutationAt
        self.lastResolvedCloudModifiedAt = lastResolvedCloudModifiedAt
    }
}

nonisolated struct InkLibrarySnapshot: Sendable {
    let modifiedAt: Date
    let entries: [JournalEntry]
    let attachmentFiles: [String: Data]
}

nonisolated struct InkLibrarySnapshotManifest: Codable, Sendable {
    let modifiedAt: Date
    let entries: [JournalEntry]
}

enum InkCloudLibraryArchiveError: LocalizedError {
    case invalidArchive

    var errorDescription: String? {
        switch self {
        case .invalidArchive:
            return "The downloaded Ink5 library snapshot is invalid."
        }
    }
}

nonisolated enum InkCloudTemporaryArchiveCleaner {
    private static let archivePrefix = "InkCloudSnapshot-"
    private static let archiveExtension = "inksync"

    @discardableResult
    static func removeTemporaryArchives(
        olderThan maximumAge: TimeInterval = 6 * 60 * 60,
        in temporaryDirectory: URL = FileManager.default.temporaryDirectory,
        fileManager: FileManager = .default
    ) throws -> Int {
        let archiveURLs = try fileManager.contentsOfDirectory(
            at: temporaryDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        let cutoffDate = Date().addingTimeInterval(-maximumAge)
        var removedCount = 0

        for archiveURL in archiveURLs
            where archiveURL.lastPathComponent.hasPrefix(archivePrefix)
                && archiveURL.pathExtension == archiveExtension {
            let modifiedAt = try archiveURL.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate ?? .distantPast

            guard modifiedAt <= cutoffDate else {
                continue
            }

            try fileManager.removeItem(at: archiveURL)
            removedCount += 1
        }

        return removedCount
    }
}

nonisolated enum InkCloudLibraryArchive {
    private static let manifestFilename = "manifest.json"
    private static let attachmentsDirectoryName = "Attachments"

    static func makeArchive(
        entries: [JournalEntry],
        attachmentRootDirectory: URL,
        modifiedAt: Date
    ) async throws -> URL {
        try await Task.detached(priority: .utility) {
            try InkCloudTemporaryArchiveCleaner.removeTemporaryArchives()

            let manifest = InkLibrarySnapshotManifest(
                modifiedAt: modifiedAt,
                entries: entries
            )

            let manifestData = try JSONEncoder().encode(manifest)
            var rootChildren: [String: FileWrapper] = [
                manifestFilename: FileWrapper(regularFileWithContents: manifestData)
            ]

            let attachmentsWrapper = try attachmentsDirectoryWrapper(
                entries: entries,
                attachmentRootDirectory: attachmentRootDirectory
            )
            rootChildren[attachmentsDirectoryName] = attachmentsWrapper

            let rootWrapper = FileWrapper(directoryWithFileWrappers: rootChildren)
            let archiveData = try NSKeyedArchiver.archivedData(
                withRootObject: rootWrapper,
                requiringSecureCoding: true
            )

            let archiveURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("InkCloudSnapshot-\(UUID().uuidString)")
                .appendingPathExtension("inksync")
            try archiveData.write(to: archiveURL, options: [.atomic])
            return archiveURL
        }.value
    }

    static func loadArchive(from archiveURL: URL) async throws -> InkLibrarySnapshot {
        try await Task.detached(priority: .utility) {
            let archiveData = try Data(contentsOf: archiveURL, options: [.mappedIfSafe])
            guard let rootWrapper = try NSKeyedUnarchiver.unarchivedObject(
                ofClass: FileWrapper.self,
                from: archiveData
            ),
            let manifestWrapper = rootWrapper.fileWrappers?[manifestFilename],
            let manifestData = manifestWrapper.regularFileContents else {
                throw InkCloudLibraryArchiveError.invalidArchive
            }

            let manifest = try JSONDecoder().decode(InkLibrarySnapshotManifest.self, from: manifestData)

            var attachmentFiles: [String: Data] = [:]
            if let attachmentsWrapper = rootWrapper.fileWrappers?[attachmentsDirectoryName] {
                collectFiles(
                    from: attachmentsWrapper,
                    basePath: "",
                    into: &attachmentFiles
                )
            }

            return InkLibrarySnapshot(
                modifiedAt: manifest.modifiedAt,
                entries: manifest.entries,
                attachmentFiles: attachmentFiles
            )
        }.value
    }

    static func applySnapshot(
        _ snapshot: InkLibrarySnapshot,
        storageURL: URL,
        attachmentRootDirectory: URL
    ) async throws {
        try await Task.detached(priority: .utility) {
            let fileManager = FileManager.default
            let storageDirectory = storageURL.deletingLastPathComponent()

            try fileManager.createDirectory(
                at: storageDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )

            if fileManager.fileExists(atPath: attachmentRootDirectory.path) {
                try fileManager.removeItem(at: attachmentRootDirectory)
            }

            try fileManager.createDirectory(
                at: attachmentRootDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )

            for (relativePath, data) in snapshot.attachmentFiles {
                let destinationURL = attachmentRootDirectory
                    .appendingPathComponent(relativePath)
                try fileManager.createDirectory(
                    at: destinationURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                try data.write(to: destinationURL, options: [.atomic])
            }

            let entriesData = try JSONEncoder().encode(snapshot.entries)
            try entriesData.write(to: storageURL, options: [.atomic])
        }.value
    }

    private static func attachmentsDirectoryWrapper(
        entries: [JournalEntry],
        attachmentRootDirectory: URL
    ) throws -> FileWrapper {
        var entryDirectories: [String: FileWrapper] = [:]

        for entry in entries where !entry.attachments.isEmpty {
            let entryDirectoryURL = attachmentRootDirectory
                .appendingPathComponent(entry.id.uuidString, isDirectory: true)

            var attachmentWrappers: [String: FileWrapper] = [:]
            for attachment in entry.attachments {
                let attachmentURL = entryDirectoryURL.appendingPathComponent(attachment.filename)
                let attachmentData = try Data(contentsOf: attachmentURL, options: [.mappedIfSafe])
                attachmentWrappers[attachment.filename] = FileWrapper(regularFileWithContents: attachmentData)

                if let audioFilename = attachment.audioFilename {
                    let audioURL = entryDirectoryURL.appendingPathComponent(audioFilename)
                    if FileManager.default.fileExists(atPath: audioURL.path) {
                        let audioData = try Data(contentsOf: audioURL, options: [.mappedIfSafe])
                        attachmentWrappers[audioFilename] = FileWrapper(regularFileWithContents: audioData)
                    }
                }
            }

            entryDirectories[entry.id.uuidString] = FileWrapper(
                directoryWithFileWrappers: attachmentWrappers
            )
        }

        return FileWrapper(directoryWithFileWrappers: entryDirectories)
    }

    private static func collectFiles(
        from wrapper: FileWrapper,
        basePath: String,
        into files: inout [String: Data]
    ) {
        if wrapper.isRegularFile,
           let contents = wrapper.regularFileContents {
            files[basePath] = contents
            return
        }

        guard let children = wrapper.fileWrappers else {
            return
        }

        for (name, child) in children {
            let childPath = basePath.isEmpty ? name : "\(basePath)/\(name)"
            collectFiles(from: child, basePath: childPath, into: &files)
        }
    }
}

nonisolated struct InkRemoteLibrarySnapshot: Sendable {
    let modifiedAt: Date
    let assetURL: URL
}

actor InkCloudSnapshotService {
    private enum Constants {
        static let containerIdentifier = "iCloud.com.zhuhuaijin.Ink"
        static let recordType = "InkLibrarySnapshot"
        static let recordName = "PrivateLibrary"
        static let modifiedAtKey = "modifiedAt"
        static let assetKey = "libraryAsset"
    }

    private let database: CKDatabase
    private let recordID = CKRecord.ID(recordName: Constants.recordName)

    init(containerIdentifier: String = Constants.containerIdentifier) {
        database = CKContainer(identifier: containerIdentifier).privateCloudDatabase
    }

    func fetchSnapshot() async throws -> InkRemoteLibrarySnapshot? {
        do {
            let record = try await fetchRecord(withID: recordID)
            guard let modifiedAt = record[Constants.modifiedAtKey] as? Date,
                  let asset = record[Constants.assetKey] as? CKAsset,
                  let assetURL = asset.fileURL else {
                return nil
            }

            return InkRemoteLibrarySnapshot(
                modifiedAt: modifiedAt,
                assetURL: assetURL
            )
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    func uploadSnapshot(archiveURL: URL, modifiedAt: Date) async throws {
        let record: CKRecord
        if let existingRecord = try await fetchSnapshotRecordIfPresent() {
            record = existingRecord
        } else {
            record = CKRecord(recordType: Constants.recordType, recordID: recordID)
        }

        record[Constants.modifiedAtKey] = modifiedAt as NSDate
        record[Constants.assetKey] = CKAsset(fileURL: archiveURL)
        _ = try await saveRecord(record)
    }

    private func fetchSnapshotRecordIfPresent() async throws -> CKRecord? {
        do {
            return try await fetchRecord(withID: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    private func fetchRecord(withID recordID: CKRecord.ID) async throws -> CKRecord {
        try await withCheckedThrowingContinuation { continuation in
            database.fetch(withRecordID: recordID) { record, error in
                if let record {
                    continuation.resume(returning: record)
                } else if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(throwing: CKError(.unknownItem))
                }
            }
        }
    }

    private func saveRecord(_ record: CKRecord) async throws -> CKRecord {
        try await withCheckedThrowingContinuation { continuation in
            database.save(record) { savedRecord, error in
                if let savedRecord {
                    continuation.resume(returning: savedRecord)
                } else if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(throwing: CKError(.internalError))
                }
            }
        }
    }
}
