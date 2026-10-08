//
//  JournalStore.swift
//  Ink
//
//  Created by Codex on 3/13/26.
//

import Combine
import Foundation

@MainActor
final class JournalStore: ObservableObject {
    @Published private(set) var entries: [JournalEntry] = []
    @Published var selectedEntryID: UUID?
    @Published private(set) var activelyEditingBodyEntryIDs: Set<UUID> = []

    private let fileManager: FileManager
    private let storageURL: URL
    private let syncStateURL: URL
    let attachmentRootDirectory: URL
    let attachmentLibrary: JournalAttachmentLibrary
    private let decoder = JSONDecoder()
    private let persistenceCoordinator = JournalPersistenceCoordinator()
    private let cloudSyncCoordinator: JournalCloudSyncCoordinator?
    private let cloudSyncService: InkCloudSnapshotService?
    private var syncState = InkCloudSyncState()
    private var cachedBodyTextByEntryID: [UUID: String] = [:]

    init(
        fileManager: FileManager = .default,
        storageURL: URL? = nil,
        enablesCloudSync: Bool = true,
        cloudSyncService: InkCloudSnapshotService? = nil
    ) {
        self.fileManager = fileManager

        let resolvedURL: URL
        if let storageURL {
            resolvedURL = storageURL
        } else {
            let appSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            resolvedURL = appSupportDirectory
                .appendingPathComponent("Ink", isDirectory: true)
                .appendingPathComponent("journals.json")
        }

        self.storageURL = resolvedURL
        let hadPersistedLibrary = fileManager.fileExists(atPath: resolvedURL.path)
        self.syncStateURL = resolvedURL
            .deletingLastPathComponent()
            .appendingPathComponent("sync-state.json")
        self.attachmentRootDirectory = resolvedURL
            .deletingLastPathComponent()
            .appendingPathComponent("Attachments", isDirectory: true)
        self.attachmentLibrary = JournalAttachmentLibrary(
            fileManager: fileManager,
            rootDirectory: attachmentRootDirectory
        )
        self.cloudSyncCoordinator = enablesCloudSync ? JournalCloudSyncCoordinator() : nil
        self.cloudSyncService = enablesCloudSync ? (cloudSyncService ?? InkCloudSnapshotService()) : nil

        if enablesCloudSync {
            _ = try? InkCloudTemporaryArchiveCleaner.removeTemporaryArchives(olderThan: 10 * 60)
        }

        load()
        rebuildBodyCache()
        loadSyncState(preferringCloudRestoreOnFirstLaunch: !hadPersistedLibrary)

        if !fileManager.fileExists(atPath: resolvedURL.path) {
            persist(shouldScheduleCloudSync: false)
        }

        scheduleCloudSync(immediate: true)
    }

    var selectedEntry: JournalEntry? {
        entry(for: selectedEntryID)
    }

    func entry(for id: UUID?) -> JournalEntry? {
        guard let id else {
            return nil
        }

        return entries.first(where: { $0.id == id })
    }

    func bodyText(for id: UUID) -> String {
        entry(for: id)?.body ?? cachedBodyTextByEntryID[id] ?? ""
    }

    @discardableResult
    func createEntry() -> UUID {
        let newEntry = JournalEntry()
        entries.insert(newEntry, at: 0)
        selectedEntryID = newEntry.id
        noteLocalMutation(at: newEntry.updatedAt)
        persist()
        return newEntry.id
    }

    func moveEntry(_ id: UUID, to destinationIndex: Int) {
        guard let sourceIndex = entries.firstIndex(where: { $0.id == id }) else {
            return
        }

        var reorderedEntries = entries
        let movedEntry = reorderedEntries.remove(at: sourceIndex)
        let clampedDestination = max(0, min(destinationIndex, reorderedEntries.count))

        guard clampedDestination != sourceIndex else {
            return
        }

        reorderedEntries.insert(movedEntry, at: clampedDestination)
        entries = reorderedEntries
        noteLocalMutation()
        persist()
    }

    func deleteEntry(_ id: UUID) {
        guard let entry = entry(for: id) else {
            return
        }

        activelyEditingBodyEntryIDs.remove(id)
        cachedBodyTextByEntryID.removeValue(forKey: id)

        let attachmentRootDirectory = attachmentRootDirectory
        Task.detached(priority: .utility) {
            let library = JournalAttachmentLibrary(
                fileManager: .default,
                rootDirectory: attachmentRootDirectory
            )
            try? library.removeAllAttachments(for: entry.id)
        }

        entries.removeAll { $0.id == id }

        if selectedEntryID == id {
            selectedEntryID = entries.first?.id
        }

        noteLocalMutation()
        persist()
    }

    func deleteSelectedEntry() {
        guard let selectedEntryID else {
            return
        }

        deleteEntry(selectedEntryID)

        if let nextEntry = entries.first {
            self.selectedEntryID = nextEntry.id
        } else {
            self.selectedEntryID = nil
            createEntry()
        }
    }

    func updateTitle(_ title: String, for id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else {
            return
        }

        entries[index].title = title
        entries[index].updatedAt = .now
        noteLocalMutation(at: entries[index].updatedAt)
        persist()
    }

    func updateBody(_ body: String, for id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else {
            cachedBodyTextByEntryID[id] = body
            return
        }

        entries[index].body = body
        entries[index].updatedAt = .now
        cachedBodyTextByEntryID[id] = body
        noteLocalMutation(at: entries[index].updatedAt)
        persist()
    }

    func setBodyEditing(_ isEditing: Bool, for id: UUID) {
        if isEditing {
            activelyEditingBodyEntryIDs.insert(id)
        } else {
            activelyEditingBodyEntryIDs.remove(id)
        }
    }

    func attachmentURL(for attachment: JournalAttachment, entryID: UUID) -> URL {
        attachmentLibrary.url(for: attachment, entryID: entryID)
    }

    func audioAttachmentURL(for attachment: JournalAttachment, entryID: UUID) -> URL? {
        attachmentLibrary.audioURL(for: attachment, entryID: entryID)
    }

    func addAttachment(from sourceURL: URL, to entryID: UUID) throws {
        guard let index = entries.firstIndex(where: { $0.id == entryID }) else {
            return
        }

        let attachment = try attachmentLibrary.importFile(at: sourceURL, for: entryID)
        entries[index].attachments.append(attachment)
        entries[index].updatedAt = .now
        noteLocalMutation(at: entries[index].updatedAt)
        persist()
    }

    func importAttachment(from sourceURL: URL, to entryID: UUID) async throws {
        guard entries.contains(where: { $0.id == entryID }) else {
            return
        }

        let attachmentRootDirectory = attachmentRootDirectory
        let attachment = try await Task.detached(priority: .userInitiated) {
            let library = JournalAttachmentLibrary(
                fileManager: .default,
                rootDirectory: attachmentRootDirectory
            )

            return try library.importFile(at: sourceURL, for: entryID)
        }.value

        guard let index = entries.firstIndex(where: { $0.id == entryID }) else {
            return
        }

        entries[index].attachments.append(attachment)
        entries[index].updatedAt = .now
        noteLocalMutation(at: entries[index].updatedAt)
        persist()
    }

    func importRecordedAttachment(
        videoAt videoURL: URL,
        audioAt audioURL: URL?,
        to entryID: UUID
    ) async throws {
        guard entries.contains(where: { $0.id == entryID }) else {
            return
        }

        let attachmentRootDirectory = attachmentRootDirectory
        let attachment = try await Task.detached(priority: .userInitiated) {
            let library = JournalAttachmentLibrary(
                fileManager: .default,
                rootDirectory: attachmentRootDirectory
            )

            return try library.importFile(at: videoURL, companionAudioAt: audioURL, for: entryID)
        }.value

        guard let index = entries.firstIndex(where: { $0.id == entryID }) else {
            return
        }

        entries[index].attachments.append(attachment)
        entries[index].updatedAt = .now
        noteLocalMutation(at: entries[index].updatedAt)
        persist()
    }

    func addAttachment(
        data: Data,
        fileExtension: String,
        kind: JournalAttachmentKind,
        originalFilename: String? = nil,
        to entryID: UUID
    ) throws {
        guard let index = entries.firstIndex(where: { $0.id == entryID }) else {
            return
        }

        let attachment = try attachmentLibrary.importData(
            data,
            fileExtension: fileExtension,
            kind: kind,
            for: entryID,
            originalFilename: originalFilename
        )
        entries[index].attachments.append(attachment)
        entries[index].updatedAt = .now
        noteLocalMutation(at: entries[index].updatedAt)
        persist()
    }

    func importAttachment(
        data: Data,
        fileExtension: String,
        kind: JournalAttachmentKind,
        originalFilename: String? = nil,
        to entryID: UUID
    ) async throws {
        guard entries.contains(where: { $0.id == entryID }) else {
            return
        }

        let attachmentRootDirectory = attachmentRootDirectory
        let attachment = try await Task.detached(priority: .userInitiated) {
            let library = JournalAttachmentLibrary(
                fileManager: .default,
                rootDirectory: attachmentRootDirectory
            )

            return try library.importData(
                data,
                fileExtension: fileExtension,
                kind: kind,
                for: entryID,
                originalFilename: originalFilename
            )
        }.value

        guard let index = entries.firstIndex(where: { $0.id == entryID }) else {
            return
        }

        entries[index].attachments.append(attachment)
        entries[index].updatedAt = .now
        noteLocalMutation(at: entries[index].updatedAt)
        persist()
    }

    func removeAttachment(_ attachmentID: UUID, from entryID: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == entryID }),
              let attachmentIndex = entries[index].attachments.firstIndex(where: { $0.id == attachmentID }) else {
            return
        }

        let attachment = entries[index].attachments.remove(at: attachmentIndex)
        entries[index].updatedAt = .now
        noteLocalMutation(at: entries[index].updatedAt)
        persist()

        let attachmentRootDirectory = attachmentRootDirectory
        Task.detached(priority: .utility) {
            let library = JournalAttachmentLibrary(
                fileManager: .default,
                rootDirectory: attachmentRootDirectory
            )
            try? library.remove(attachment, from: entryID)
        }
    }

    private func load() {
        do {
            let data = try Data(contentsOf: storageURL, options: [.mappedIfSafe])
            let loadedEntries = try decoder.decode([JournalEntry].self, from: data)
            entries = loadedEntries.sorted { $0.createdAt > $1.createdAt }
            selectedEntryID = entries.first?.id
        } catch {
            let entry = JournalEntry()
            entries = [entry]
            selectedEntryID = entry.id
        }
    }

    private func rebuildBodyCache() {
        cachedBodyTextByEntryID = Dictionary(
            uniqueKeysWithValues: entries.map { ($0.id, $0.body) }
        )
    }

    private func persist(shouldScheduleCloudSync: Bool = true) {
        let entriesSnapshot = entries
        let storageURL = storageURL
        let persistenceCoordinator = persistenceCoordinator

        Task(priority: .utility) {
            await persistenceCoordinator.schedulePersist(entries: entriesSnapshot, to: storageURL)
        }

        if shouldScheduleCloudSync {
            self.scheduleCloudSync()
        }
    }

    private func noteLocalMutation(at date: Date = .now) {
        syncState.lastLocalMutationAt = max(syncState.lastLocalMutationAt, date)
        saveSyncState()
    }

    private func loadSyncState(preferringCloudRestoreOnFirstLaunch: Bool) {
        do {
            let data = try Data(contentsOf: syncStateURL, options: [.mappedIfSafe])
            syncState = try decoder.decode(InkCloudSyncState.self, from: data)
        } catch {
            let fallbackDate = entries.map(\.updatedAt).max() ?? .now
            syncState = InkCloudSyncState(
                lastLocalMutationAt: preferringCloudRestoreOnFirstLaunch ? .distantPast : fallbackDate
            )
        }

        let latestEntryDate = entries.map(\.updatedAt).max() ?? .distantPast
        let isAwaitingInitialCloudResolution =
            syncState.lastResolvedCloudModifiedAt == nil &&
            syncState.lastLocalMutationAt == .distantPast

        if !preferringCloudRestoreOnFirstLaunch,
           !isAwaitingInitialCloudResolution,
           latestEntryDate > syncState.lastLocalMutationAt {
            syncState.lastLocalMutationAt = latestEntryDate
        }
        saveSyncState()
    }

    private func saveSyncState() {
        let syncState = syncState
        let syncStateURL = syncStateURL

        Task.detached(priority: .utility) {
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

                try FileManager.default.createDirectory(
                    at: syncStateURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true,
                    attributes: nil
                )

                let data = try encoder.encode(syncState)
                try data.write(to: syncStateURL, options: [.atomic])
            } catch {
                return
            }
        }
    }

    private func scheduleCloudSync(immediate: Bool = false) {
        guard let cloudSyncCoordinator else {
            return
        }

        Task {
            await cloudSyncCoordinator.scheduleSync(store: self, immediate: immediate)
        }
    }

    func performCloudSync() async {
        guard let cloudSyncService else {
            return
        }

        let localModifiedAt = syncState.lastLocalMutationAt
        let lastResolvedCloudModifiedAt = syncState.lastResolvedCloudModifiedAt ?? .distantPast

        do {
            let remoteSnapshot = try await cloudSyncService.fetchSnapshot()

            if let remoteSnapshot,
               remoteSnapshot.modifiedAt > localModifiedAt,
               remoteSnapshot.modifiedAt > lastResolvedCloudModifiedAt {
                let snapshot = try await InkCloudLibraryArchive.loadArchive(from: remoteSnapshot.assetURL)
                try await InkCloudLibraryArchive.applySnapshot(
                    snapshot,
                    storageURL: storageURL,
                    attachmentRootDirectory: attachmentRootDirectory
                )

                let preferredSelection = selectedEntryID
                entries = mergedEntriesPreservingActiveBodyEdits(from: snapshot.entries)
                    .sorted { $0.createdAt > $1.createdAt }
                rebuildBodyCache()
                if let preferredSelection,
                   entries.contains(where: { $0.id == preferredSelection }) {
                    selectedEntryID = preferredSelection
                } else {
                    selectedEntryID = entries.first?.id
                }

                syncState.lastLocalMutationAt = remoteSnapshot.modifiedAt
                syncState.lastResolvedCloudModifiedAt = remoteSnapshot.modifiedAt
                saveSyncState()
                return
            }

            if let remoteSnapshot,
               localModifiedAt <= remoteSnapshot.modifiedAt {
                syncState.lastResolvedCloudModifiedAt = remoteSnapshot.modifiedAt
                saveSyncState()
                return
            }

            let effectiveLocalModifiedAt: Date
            if localModifiedAt == .distantPast, !entries.isEmpty {
                effectiveLocalModifiedAt = entries.map(\.updatedAt).max() ?? .now
                syncState.lastLocalMutationAt = effectiveLocalModifiedAt
                saveSyncState()
            } else {
                effectiveLocalModifiedAt = localModifiedAt
            }

            let archiveURL = try await InkCloudLibraryArchive.makeArchive(
                entries: entries,
                attachmentRootDirectory: attachmentRootDirectory,
                modifiedAt: effectiveLocalModifiedAt
            )

            defer {
                try? fileManager.removeItem(at: archiveURL)
            }

            try await cloudSyncService.uploadSnapshot(
                archiveURL: archiveURL,
                modifiedAt: effectiveLocalModifiedAt
            )

            syncState.lastResolvedCloudModifiedAt = effectiveLocalModifiedAt
            saveSyncState()
        } catch {
            #if DEBUG
            print("Ink Cloud sync failed: \(error.localizedDescription)")
            #endif
        }
    }

    private func mergedEntriesPreservingActiveBodyEdits(from remoteEntries: [JournalEntry]) -> [JournalEntry] {
        guard !activelyEditingBodyEntryIDs.isEmpty else {
            return remoteEntries
        }

        let localEntriesByID = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
        var mergedEntries = remoteEntries

        for index in mergedEntries.indices {
            let remoteEntry = mergedEntries[index]
            guard activelyEditingBodyEntryIDs.contains(remoteEntry.id),
                  let localEntry = localEntriesByID[remoteEntry.id] else {
                continue
            }

            mergedEntries[index].body = localEntry.body
            mergedEntries[index].updatedAt = max(remoteEntry.updatedAt, localEntry.updatedAt)
        }

        let mergedIDs = Set(mergedEntries.map(\.id))
        for localEntry in entries where activelyEditingBodyEntryIDs.contains(localEntry.id) && !mergedIDs.contains(localEntry.id) {
            mergedEntries.append(localEntry)
        }

        return mergedEntries
    }
}

actor JournalPersistenceCoordinator {
    private var pendingTask: Task<Void, Never>?

    func schedulePersist(entries: [JournalEntry], to storageURL: URL) {
        pendingTask?.cancel()
        pendingTask = Task(priority: .utility) {
            do {
                try await Task.sleep(for: .milliseconds(250))
                try Task.checkCancellation()
                try self.persistNow(entries: entries, to: storageURL)
            } catch is CancellationError {
                return
            } catch {
                assertionFailure("Failed to save journals: \(error.localizedDescription)")
            }
        }
    }

    private func persistNow(entries: [JournalEntry], to storageURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        try FileManager.default.createDirectory(
            at: storageURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )

        let data = try encoder.encode(entries)
        try data.write(to: storageURL, options: [.atomic])
    }
}

actor JournalCloudSyncCoordinator {
    private var pendingTask: Task<Void, Never>?

    func scheduleSync(store: JournalStore, immediate: Bool) {
        pendingTask?.cancel()
        pendingTask = Task(priority: .utility) {
            do {
                if !immediate {
                    try await Task.sleep(for: .seconds(2))
                }
                try Task.checkCancellation()
                await store.performCloudSync()
            } catch is CancellationError {
                return
            } catch {
                return
            }
        }
    }
}

extension JournalStore {
    static var previewStore: JournalStore {
        let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent("InkPreview-\(UUID().uuidString).json")
        let store = JournalStore(storageURL: temporaryURL, enablesCloudSync: false)
        store.entries = [
            JournalEntry(
                createdAt: .now.addingTimeInterval(-3600),
                updatedAt: .now.addingTimeInterval(-900),
                title: "Quiet afternoon",
                body: "Today felt slower in a good way. I want Write to stay this calm every time it opens."
            ),
            JournalEntry(
                createdAt: .now.addingTimeInterval(-86_400),
                updatedAt: .now.addingTimeInterval(-86_000),
                title: "Idea for tomorrow",
                body: "Keep the interface simple: left list, right editor, and a clean save-as flow."
            )
        ]
        store.selectedEntryID = store.entries.first?.id
        return store
    }
}
