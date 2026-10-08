//
//  GroupStore.swift
//  Done
//
//  Created by Codex on 3/12/26.
//

import CloudKit
import Combine
import CryptoKit
import Foundation

enum GroupStoreError: Error {
    case missingName
    case missingMemberName
    case missingInviteCode
    case invalidInviteCode
    case accountUnavailable
    case deleteFailed
    case operationFailed
}

@MainActor
final class GroupStore: ObservableObject {
    @Published private(set) var groups: [TaskGroup] = []
    @Published private(set) var membersByGroupCode: [String: [GroupMember]] = [:]
    @Published private(set) var currentUserRecordName: String?
    @Published private(set) var isLoading = false
    @Published private(set) var loadError: GroupStoreError?

    private let cloudKit: CloudKitService
    private var lastSuccessfulRefreshAt: Date?

    init(cloudKit: CloudKitService) {
        self.cloudKit = cloudKit

        Task {
            await refresh()
        }
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let userRecordName = try await cloudKit.fetchCurrentUserRecordName()
            currentUserRecordName = userRecordName

            let profile = try await fetchOrCreateProfile(for: userRecordName)
            let groupCodes = (profile[DoneCloudKitSchema.groupCodesField] as? [String] ?? []).sorted()

            let records = try await cloudKit.fetchRecords(
                recordIDs: groupCodes.map { CKRecord.ID(recordName: $0) },
                ignoringUnknownItems: true
            )

            let foundCodes = Set(records.map { $0.recordID.recordName })
            let missingCodes = Set(groupCodes).subtracting(foundCodes)
            if !missingCodes.isEmpty {
                try await removeGroupCodes(missingCodes, from: profile)
            }

            let loadedGroups = records
                .compactMap { record in
                    group(from: record, currentUserRecordName: userRecordName)
                }
                .sorted { lhs, rhs in
                    if lhs.createdAt == rhs.createdAt {
                        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                    }
                    return lhs.createdAt > rhs.createdAt
                }

            groups = loadedGroups
            do {
                membersByGroupCode = try await loadMembers(
                    for: loadedGroups,
                    currentUserRecordName: userRecordName,
                    profile: profile
                )
            } catch {
                // Keep existing member data visible even if member metadata is temporarily unavailable.
                membersByGroupCode = Dictionary(
                    uniqueKeysWithValues: loadedGroups.map { group in
                        (group.inviteCode, membersByGroupCode[group.inviteCode] ?? [])
                    }
                )
            }
            loadError = nil
            lastSuccessfulRefreshAt = Date()
        } catch {
            loadError = normalized(error)
        }
    }

    func refreshIfNeeded(maxAge: TimeInterval = 20) async {
        guard !isLoading else { return }
        if let lastSuccessfulRefreshAt, Date().timeIntervalSince(lastSuccessfulRefreshAt) < maxAge {
            return
        }
        await refresh()
    }

    func deleteGroup(_ group: TaskGroup) async throws {
        let userRecordName = try await ensuredCurrentUserRecordName()
        let profile = try await fetchOrCreateProfile(for: userRecordName)

        do {
            if group.isOwnedByCurrentUser {
                let taskRecords = try await cloudKit.query(
                    recordType: DoneCloudKitSchema.groupTaskRecordType,
                    predicate: NSPredicate(format: "%K == %@", DoneCloudKitSchema.groupCodeField, group.inviteCode)
                )

                for taskRecord in taskRecords {
                    try await cloudKit.delete(recordID: taskRecord.recordID)
                }

                let memberRecords = try await cloudKit.query(
                    recordType: DoneCloudKitSchema.groupMemberRecordType,
                    predicate: NSPredicate(format: "%K == %@", DoneCloudKitSchema.groupCodeField, group.inviteCode)
                )

                for memberRecord in memberRecords {
                    try await cloudKit.delete(recordID: memberRecord.recordID)
                }

                try await cloudKit.delete(recordID: CKRecord.ID(recordName: group.inviteCode))
            } else {
                try await deleteMemberRecord(groupCode: group.inviteCode, userRecordName: userRecordName)
            }

            try await removeGroupCodes([group.inviteCode], from: profile)
            await refresh()
        } catch let error as CKError where error.code == .unknownItem {
            try await removeGroupCodes([group.inviteCode], from: profile)
            await refresh()
        } catch {
            throw normalized(error)
        }
    }

    func createGroup(name: String, details: String, ownerDisplayName: String) async throws -> TaskGroup {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanOwnerDisplayName = ownerDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            throw GroupStoreError.missingName
        }
        guard !cleanOwnerDisplayName.isEmpty else {
            throw GroupStoreError.missingMemberName
        }

        let userRecordName = try await ensuredCurrentUserRecordName()
        let profile = try await fetchOrCreateProfile(for: userRecordName)

        var createdGroup: TaskGroup?

        for _ in 0..<12 where createdGroup == nil {
            let inviteCode = Self.generateInviteCode()
            let recordID = CKRecord.ID(recordName: inviteCode)

            do {
                let groupRecord = CKRecord(recordType: DoneCloudKitSchema.groupRecordType, recordID: recordID)
                groupRecord[DoneCloudKitSchema.nameField] = cleanName
                groupRecord[DoneCloudKitSchema.detailsField] = cleanDetails
                groupRecord[DoneCloudKitSchema.ownerUserRecordNameField] = userRecordName
                groupRecord[DoneCloudKitSchema.createdAtField] = Date()

                let savedGroup = try await cloudKit.save(record: groupRecord)
                do {
                    try await upsertMemberRecord(
                        groupCode: inviteCode,
                        userRecordName: userRecordName,
                        displayName: cleanOwnerDisplayName,
                        isOwner: true
                    )
                    try await updateProfile(
                        profile,
                        displayName: cleanOwnerDisplayName,
                        addingGroupCode: inviteCode
                    )
                } catch {
                    await rollbackCreatedGroup(inviteCode: inviteCode, userRecordName: userRecordName)
                    throw error
                }
                createdGroup = group(from: savedGroup, currentUserRecordName: userRecordName)
            } catch let error as CKError where error.code == .serverRecordChanged || error.code == .batchRequestFailed {
                continue
            } catch {
                throw normalized(error)
            }
        }

        guard let createdGroup else {
            throw GroupStoreError.operationFailed
        }

        await refresh()
        return createdGroup
    }

    func joinGroup(inviteCode: String, displayName: String) async throws -> TaskGroup {
        let cleanCode = inviteCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        let cleanDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanCode.isEmpty else {
            throw GroupStoreError.missingInviteCode
        }
        guard !cleanDisplayName.isEmpty else {
            throw GroupStoreError.missingMemberName
        }

        let userRecordName = try await ensuredCurrentUserRecordName()
        let profile = try await fetchOrCreateProfile(for: userRecordName)

        do {
            let groupRecord = try await cloudKit.fetch(recordID: CKRecord.ID(recordName: cleanCode))
            let isOwner = (groupRecord[DoneCloudKitSchema.ownerUserRecordNameField] as? String) == userRecordName
            try await updateProfileDisplayName(cleanDisplayName, on: profile)
            try await addGroupCode(cleanCode, to: profile)
            try await upsertMemberRecord(
                groupCode: cleanCode,
                userRecordName: userRecordName,
                displayName: cleanDisplayName,
                isOwner: isOwner
            )
            await refresh()

            guard let group = group(from: groupRecord, currentUserRecordName: userRecordName) else {
                throw GroupStoreError.invalidInviteCode
            }

            return group
        } catch let error as CKError where error.code == .unknownItem {
            throw GroupStoreError.invalidInviteCode
        } catch let error as GroupStoreError {
            throw error
        } catch {
            throw normalized(error)
        }
    }

    private func fetchOrCreateProfile(for userRecordName: String) async throws -> CKRecord {
        do {
            return try await cloudKit.fetch(recordID: CKRecord.ID(recordName: userRecordName))
        } catch let error as CKError where error.code == .unknownItem {
            let profile = CKRecord(
                recordType: DoneCloudKitSchema.userProfileRecordType,
                recordID: CKRecord.ID(recordName: userRecordName)
            )
            profile[DoneCloudKitSchema.groupCodesField] = [String]()
            profile[DoneCloudKitSchema.updatedAtField] = Date()
            return try await cloudKit.save(record: profile)
        } catch {
            throw normalized(error)
        }
    }

    func members(for group: TaskGroup) -> [GroupMember] {
        membersByGroupCode[group.inviteCode] ?? []
    }

    func memberCount(for group: TaskGroup) -> Int {
        members(for: group).count
    }

    private func addGroupCode(_ inviteCode: String, to profile: CKRecord) async throws {
        var groupCodes = Set(profile[DoneCloudKitSchema.groupCodesField] as? [String] ?? [])
        groupCodes.insert(inviteCode)
        profile[DoneCloudKitSchema.groupCodesField] = Array(groupCodes).sorted()
        profile[DoneCloudKitSchema.updatedAtField] = Date()
        _ = try await cloudKit.save(record: profile)
    }

    private func updateProfileDisplayName(_ displayName: String, on profile: CKRecord) async throws {
        profile[DoneCloudKitSchema.displayNameField] = displayName
        profile[DoneCloudKitSchema.updatedAtField] = Date()
        _ = try await cloudKit.save(record: profile)
    }

    private func updateProfile(_ profile: CKRecord, displayName: String, addingGroupCode inviteCode: String) async throws {
        var groupCodes = Set(profile[DoneCloudKitSchema.groupCodesField] as? [String] ?? [])
        groupCodes.insert(inviteCode)
        profile[DoneCloudKitSchema.groupCodesField] = Array(groupCodes).sorted()
        profile[DoneCloudKitSchema.displayNameField] = displayName
        profile[DoneCloudKitSchema.updatedAtField] = Date()
        _ = try await cloudKit.save(record: profile)
    }

    private func removeGroupCodes<S: Sequence>(_ inviteCodes: S, from profile: CKRecord) async throws where S.Element == String {
        let codesToRemove = Set(inviteCodes)
        var groupCodes = Set(profile[DoneCloudKitSchema.groupCodesField] as? [String] ?? [])
        groupCodes.subtract(codesToRemove)
        profile[DoneCloudKitSchema.groupCodesField] = Array(groupCodes).sorted()
        profile[DoneCloudKitSchema.updatedAtField] = Date()
        _ = try await cloudKit.save(record: profile)
    }

    private func ensuredCurrentUserRecordName() async throws -> String {
        if let currentUserRecordName {
            return currentUserRecordName
        }

        let userRecordName = try await cloudKit.fetchCurrentUserRecordName()
        currentUserRecordName = userRecordName
        return userRecordName
    }

    private func group(from record: CKRecord, currentUserRecordName: String) -> TaskGroup? {
        guard record.recordType == DoneCloudKitSchema.groupRecordType,
              let name = record[DoneCloudKitSchema.nameField] as? String,
              let ownerUserRecordName = record[DoneCloudKitSchema.ownerUserRecordNameField] as? String else {
            return nil
        }

        let details = record[DoneCloudKitSchema.detailsField] as? String ?? ""
        let createdAt = record[DoneCloudKitSchema.createdAtField] as? Date ?? .now
        let inviteCode = record.recordID.recordName

        return TaskGroup(
            id: inviteCode,
            name: name,
            details: details,
            inviteCode: inviteCode,
            ownerUserRecordName: ownerUserRecordName,
            createdAt: createdAt,
            isOwnedByCurrentUser: ownerUserRecordName == currentUserRecordName
        )
    }

    private func loadMembers(
        for groups: [TaskGroup],
        currentUserRecordName: String,
        profile: CKRecord
    ) async throws -> [String: [GroupMember]] {
        let groupCodes = groups.map(\.inviteCode)
        guard !groupCodes.isEmpty else { return [:] }

        let groupByCode = Dictionary(uniqueKeysWithValues: groups.map { ($0.inviteCode, $0) })
        let existingRecords = try await cloudKit.query(
            recordType: DoneCloudKitSchema.groupMemberRecordType,
            predicate: NSPredicate(format: "%K IN %@", DoneCloudKitSchema.groupCodeField, groupCodes),
            sortDescriptors: [NSSortDescriptor(key: DoneCloudKitSchema.joinedAtField, ascending: true)]
        )

        var existingKeys = Set(
            existingRecords.compactMap { record -> String? in
                guard let groupCode = record[DoneCloudKitSchema.groupCodeField] as? String,
                      let memberUserRecordName = record[DoneCloudKitSchema.memberUserRecordNameField] as? String else {
                    return nil
                }
                return membershipKey(groupCode: groupCode, userRecordName: memberUserRecordName)
            }
        )

        var didBackfillCurrentUser = false
        let currentUserDisplayName = profileDisplayName(
            from: profile,
            defaultName: "Member"
        )

        for group in groups {
            let key = membershipKey(groupCode: group.inviteCode, userRecordName: currentUserRecordName)
            if existingKeys.contains(key) {
                continue
            }

            try await upsertMemberRecord(
                groupCode: group.inviteCode,
                userRecordName: currentUserRecordName,
                displayName: group.isOwnedByCurrentUser ? profileDisplayName(from: profile, defaultName: "Owner") : currentUserDisplayName,
                isOwner: group.isOwnedByCurrentUser
            )
            existingKeys.insert(key)
            didBackfillCurrentUser = true
        }

        let memberRecords: [CKRecord]
        if didBackfillCurrentUser {
            memberRecords = try await cloudKit.query(
                recordType: DoneCloudKitSchema.groupMemberRecordType,
                predicate: NSPredicate(format: "%K IN %@", DoneCloudKitSchema.groupCodeField, groupCodes),
                sortDescriptors: [NSSortDescriptor(key: DoneCloudKitSchema.joinedAtField, ascending: true)]
            )
        } else {
            memberRecords = existingRecords
        }

        var grouped: [String: [GroupMember]] = [:]
        for record in memberRecords {
            guard let groupCode = record[DoneCloudKitSchema.groupCodeField] as? String,
                  let group = groupByCode[groupCode],
                  let member = member(from: record, ownerUserRecordName: group.ownerUserRecordName) else {
                continue
            }

            grouped[groupCode, default: []].append(member)
        }

        for code in groupCodes {
            grouped[code] = (grouped[code] ?? []).sorted { lhs, rhs in
                if lhs.isOwner != rhs.isOwner {
                    return lhs.isOwner && !rhs.isOwner
                }
                if lhs.joinedAt == rhs.joinedAt {
                    return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
                }
                return lhs.joinedAt < rhs.joinedAt
            }
        }

        return grouped
    }

    private func member(
        from record: CKRecord,
        ownerUserRecordName: String
    ) -> GroupMember? {
        guard record.recordType == DoneCloudKitSchema.groupMemberRecordType,
              let groupCode = record[DoneCloudKitSchema.groupCodeField] as? String,
              let userRecordName = record[DoneCloudKitSchema.memberUserRecordNameField] as? String else {
            return nil
        }

        let joinedAt = record[DoneCloudKitSchema.joinedAtField] as? Date ?? .now
        let displayName = (record[DoneCloudKitSchema.displayNameField] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackIsOwner = userRecordName == ownerUserRecordName
        let isOwner = (record[DoneCloudKitSchema.isOwnerField] as? Bool) ?? fallbackIsOwner

        return GroupMember(
            id: record.recordID.recordName,
            groupCode: groupCode,
            userRecordName: userRecordName,
            displayName: displayName?.isEmpty == false ? displayName! : (isOwner ? "Owner" : "Member"),
            joinedAt: joinedAt,
            isOwner: isOwner
        )
    }

    private func upsertMemberRecord(
        groupCode: String,
        userRecordName: String,
        displayName: String,
        isOwner: Bool
    ) async throws {
        let recordID = memberRecordID(groupCode: groupCode, userRecordName: userRecordName)
        let record: CKRecord

        do {
            record = try await cloudKit.fetch(recordID: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            record = CKRecord(recordType: DoneCloudKitSchema.groupMemberRecordType, recordID: recordID)
            record[DoneCloudKitSchema.joinedAtField] = Date()
        }

        record[DoneCloudKitSchema.groupCodeField] = groupCode
        record[DoneCloudKitSchema.memberUserRecordNameField] = userRecordName
        record[DoneCloudKitSchema.displayNameField] = displayName
        record[DoneCloudKitSchema.isOwnerField] = isOwner
        if record[DoneCloudKitSchema.joinedAtField] == nil {
            record[DoneCloudKitSchema.joinedAtField] = Date()
        }

        _ = try await cloudKit.save(record: record)
    }

    private func deleteMemberRecord(groupCode: String, userRecordName: String) async throws {
        let recordID = memberRecordID(groupCode: groupCode, userRecordName: userRecordName)
        do {
            try await cloudKit.delete(recordID: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            return
        }
    }

    private func rollbackCreatedGroup(inviteCode: String, userRecordName: String) async {
        try? await deleteMemberRecord(groupCode: inviteCode, userRecordName: userRecordName)
        try? await cloudKit.delete(recordID: CKRecord.ID(recordName: inviteCode))
    }

    private func profileDisplayName(from profile: CKRecord, defaultName: String) -> String {
        let displayName = (profile[DoneCloudKitSchema.displayNameField] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let displayName, !displayName.isEmpty {
            return displayName
        }

        return defaultName
    }

    private func memberRecordID(groupCode: String, userRecordName: String) -> CKRecord.ID {
        let rawKey = membershipKey(groupCode: groupCode, userRecordName: userRecordName)
        let digest = SHA256.hash(data: Data(rawKey.utf8))
        let hash = digest.map { String(format: "%02x", $0) }.joined()
        return CKRecord.ID(recordName: "member_\(hash)")
    }

    private func membershipKey(groupCode: String, userRecordName: String) -> String {
        "\(groupCode)|\(userRecordName)"
    }

    private func normalized(_ error: Error) -> GroupStoreError {
        if let groupError = error as? GroupStoreError {
            return groupError
        }

        if let cloudError = error as? CKError {
            switch cloudError.code {
            case .notAuthenticated, .badContainer, .missingEntitlement, .permissionFailure:
                return .accountUnavailable
            case .unknownItem:
                return .deleteFailed
            default:
                return .operationFailed
            }
        }

        return .operationFailed
    }

    private static func generateInviteCode(length: Int = 6) -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<length).map { _ in alphabet.randomElement() ?? "A" })
    }
}
