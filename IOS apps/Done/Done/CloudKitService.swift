//
//  CloudKitService.swift
//  Done
//
//  Created by Codex on 3/12/26.
//

import CloudKit
import Foundation

enum DoneCloudKitSchema {
    static let containerIdentifier = "iCloud.com.zhuhuaijin.Done"

    static let userProfileRecordType = "DoneUserProfile"
    static let groupRecordType = "DoneGroup"
    static let groupMemberRecordType = "DoneGroupMember"
    static let groupTaskRecordType = "DoneGroupTask"

    static let groupCodesField = "groupCodes"
    static let updatedAtField = "updatedAt"
    static let displayNameField = "displayName"

    static let nameField = "name"
    static let detailsField = "details"
    static let ownerUserRecordNameField = "ownerUserRecordName"
    static let createdAtField = "createdAt"
    static let joinedAtField = "joinedAt"
    static let isOwnerField = "isOwner"
    static let memberUserRecordNameField = "memberUserRecordName"

    static let taskUUIDField = "taskUUID"
    static let titleField = "title"
    static let notesField = "notes"
    static let dueDateField = "dueDate"
    static let isCompletedField = "isCompleted"
    static let groupCodeField = "groupCode"
    static let groupNameField = "groupName"
    static let creatorUserRecordNameField = "creatorUserRecordName"
}

enum CloudKitServiceError: Error {
    case missingRecord
}

final class CloudKitService {
    let container: CKContainer
    let publicDatabase: CKDatabase

    init(containerIdentifier: String = DoneCloudKitSchema.containerIdentifier) {
        container = CKContainer(identifier: containerIdentifier)
        publicDatabase = container.publicCloudDatabase
    }

    func fetchCurrentUserRecordName() async throws -> String {
        let recordID = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKRecord.ID, Error>) in
            container.fetchUserRecordID { recordID, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let recordID else {
                    continuation.resume(throwing: CloudKitServiceError.missingRecord)
                    return
                }

                continuation.resume(returning: recordID)
            }
        }

        return recordID.recordName
    }

    func save(record: CKRecord) async throws -> CKRecord {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKRecord, Error>) in
            publicDatabase.save(record) { record, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let record else {
                    continuation.resume(throwing: CloudKitServiceError.missingRecord)
                    return
                }

                continuation.resume(returning: record)
            }
        }
    }

    func fetch(recordID: CKRecord.ID) async throws -> CKRecord {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKRecord, Error>) in
            publicDatabase.fetch(withRecordID: recordID) { record, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let record else {
                    continuation.resume(throwing: CloudKitServiceError.missingRecord)
                    return
                }

                continuation.resume(returning: record)
            }
        }
    }

    func delete(recordID: CKRecord.ID) async throws {
        _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKRecord.ID?, Error>) in
            publicDatabase.delete(withRecordID: recordID) { recordID, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: recordID)
            }
        } as CKRecord.ID?
    }

    func fetchRecords(recordIDs: [CKRecord.ID], ignoringUnknownItems: Bool = false) async throws -> [CKRecord] {
        guard !recordIDs.isEmpty else { return [] }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[CKRecord], Error>) in
            var fetchedRecords: [CKRecord] = []
            var firstError: Error?

            let operation = CKFetchRecordsOperation(recordIDs: recordIDs)
            operation.perRecordResultBlock = { _, result in
                switch result {
                case .success(let record):
                    fetchedRecords.append(record)
                case .failure(let error):
                    if ignoringUnknownItems,
                       let cloudError = error as? CKError,
                       cloudError.code == .unknownItem {
                        return
                    }
                    if firstError == nil {
                        firstError = error
                    }
                }
            }
            operation.fetchRecordsResultBlock = { result in
                if let firstError {
                    continuation.resume(throwing: firstError)
                    return
                }

                switch result {
                case .success:
                    continuation.resume(returning: fetchedRecords)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            publicDatabase.add(operation)
        }
    }

    func query(
        recordType: String,
        predicate: NSPredicate,
        sortDescriptors: [NSSortDescriptor] = [],
        resultsLimit: Int? = nil
    ) async throws -> [CKRecord] {
        let query = CKQuery(recordType: recordType, predicate: predicate)
        query.sortDescriptors = sortDescriptors
        return try await fetchAllRecords(matching: query, resultsLimit: resultsLimit)
    }

    private func fetchAllRecords(
        matching query: CKQuery,
        resultsLimit: Int? = nil
    ) async throws -> [CKRecord] {
        var allRecords: [CKRecord] = []
        var nextCursor: CKQueryOperation.Cursor?

        repeat {
            let page = try await fetchPage(query: nextCursor == nil ? query : nil, cursor: nextCursor, resultsLimit: resultsLimit)
            allRecords.append(contentsOf: page.records)
            nextCursor = page.cursor
        } while nextCursor != nil

        return allRecords
    }

    private func fetchPage(
        query: CKQuery?,
        cursor: CKQueryOperation.Cursor?,
        resultsLimit: Int?
    ) async throws -> (records: [CKRecord], cursor: CKQueryOperation.Cursor?) {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(records: [CKRecord], cursor: CKQueryOperation.Cursor?), Error>) in
            var matchedRecords: [CKRecord] = []
            var firstError: Error?

            let operation: CKQueryOperation
            if let cursor {
                operation = CKQueryOperation(cursor: cursor)
            } else if let query {
                operation = CKQueryOperation(query: query)
            } else {
                continuation.resume(throwing: CloudKitServiceError.missingRecord)
                return
            }

            if let resultsLimit {
                operation.resultsLimit = resultsLimit
            }

            operation.recordMatchedBlock = { _, result in
                switch result {
                case .success(let record):
                    matchedRecords.append(record)
                case .failure(let error):
                    if firstError == nil {
                        firstError = error
                    }
                }
            }

            operation.queryResultBlock = { result in
                if let firstError {
                    continuation.resume(throwing: firstError)
                    return
                }

                switch result {
                case .success(let cursor):
                    continuation.resume(returning: (matchedRecords, cursor))
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            publicDatabase.add(operation)
        }
    }
}
