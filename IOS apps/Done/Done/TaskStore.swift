//
//  TaskStore.swift
//  Done
//
//  Created by Codex on 3/11/26.
//

import Combine
import CloudKit
import Foundation
import UserNotifications

enum TaskStoreError: Error {
    case cloudUnavailable
    case saveFailed
}

@MainActor
final class TaskStore: ObservableObject {
    @Published private(set) var tasks: [Assignment] = []
    @Published private(set) var currentUserRecordName: String?
    @Published private(set) var isSyncingGroupTasks = false
    @Published private(set) var groupTaskError: TaskStoreError?

    private let storageKey = "done.assignments.v1"
    private let notificationCenter = UNUserNotificationCenter.current()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let cloudKit: CloudKitService
    private var localTasks: [Assignment] = []
    private var groupTasks: [Assignment] = []
    private var language: AppLanguage = .english
    private var cancellables: Set<AnyCancellable> = []
    private var notificationSignatures: [String: String] = [:]
    private var currentGroupCodes: [String] = []
    private var groupTaskPollingTask: Task<Void, Never>?

    private let groupTaskPollingInterval: Duration = .seconds(8)

    init(cloudKit: CloudKitService, groupStore: GroupStore) {
        self.cloudKit = cloudKit
        loadTasks()
        requestNotificationPermission()

        groupStore.$currentUserRecordName
            .receive(on: DispatchQueue.main)
            .sink { [weak self] userRecordName in
                self?.currentUserRecordName = userRecordName
            }
            .store(in: &cancellables)

        groupStore.$groups
            .map { groups in
                groups.map(\.inviteCode).sorted()
            }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] groupCodes in
                guard let self else { return }
                self.currentGroupCodes = groupCodes
                self.configureGroupTaskPolling(for: groupCodes)
                Task {
                    await self.reloadGroupTasks(forGroupCodes: groupCodes, force: true)
                }
            }
            .store(in: &cancellables)

        rebuildTasks()
        syncNotifications(forceAll: true)
    }

    var incompleteTasksSorted: [Assignment] {
        tasks
            .filter { !$0.isCompleted }
            .sorted { $0.dueDate < $1.dueDate }
    }

    func addTask(title: String, notes: String, dueDate: Date, group: TaskGroup?) async throws {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }

        let cleanNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        if let group {
            let userRecordName = try await ensuredCurrentUserRecordName()
            let task = Assignment(
                id: UUID(),
                title: cleanTitle,
                notes: cleanNotes,
                dueDate: dueDate,
                isCompleted: false,
                createdAt: Date(),
                groupCode: group.inviteCode,
                groupName: group.name,
                cloudRecordName: nil,
                creatorUserRecordName: userRecordName
            )

            do {
                let savedTask = try await saveGroupTask(task, for: group)
                groupTasks.append(savedTask)
                rebuildTasks()
                syncNotifications()
            } catch let error as TaskStoreError {
                groupTaskError = error
                throw error
            } catch {
                groupTaskError = .saveFailed
                throw TaskStoreError.saveFailed
            }
        } else {
            let task = Assignment(title: cleanTitle, notes: cleanNotes, dueDate: dueDate)
            localTasks.append(task)
            persistTasks()
            rebuildTasks()
            syncNotifications()
        }
    }

    func toggleCompletion(for id: UUID) async {
        if let index = localTasks.firstIndex(where: { $0.id == id }) {
            localTasks[index].isCompleted.toggle()
            persistTasks()
            rebuildTasks()
            syncNotifications()
            return
        }

        guard let index = groupTasks.firstIndex(where: { $0.id == id }),
              canModify(groupTasks[index]),
              let recordName = groupTasks[index].cloudRecordName else {
            return
        }

        do {
            let record = try await cloudKit.fetch(recordID: CKRecord.ID(recordName: recordName))
            let nextValue = !groupTasks[index].isCompleted
            record[DoneCloudKitSchema.isCompletedField] = nextValue
            let savedRecord = try await cloudKit.save(record: record)
            groupTasks[index] = assignment(from: savedRecord)
            rebuildTasks()
            syncNotifications()
        } catch {
            groupTaskError = .saveFailed
        }
    }

    func deleteTask(_ id: UUID) async {
        if localTasks.contains(where: { $0.id == id }) {
            localTasks.removeAll { $0.id == id }
            persistTasks()
            rebuildTasks()
            syncNotifications()
            return
        }

        guard let task = groupTasks.first(where: { $0.id == id }),
              canModify(task),
              let recordName = task.cloudRecordName else {
            return
        }

        do {
            try await cloudKit.delete(recordID: CKRecord.ID(recordName: recordName))
            groupTasks.removeAll { $0.id == id }
            rebuildTasks()
            cancelNotifications(for: id)
        } catch {
            groupTaskError = .saveFailed
        }
    }

    func updateLanguage(_ language: AppLanguage) {
        self.language = language
        syncNotifications(forceAll: true)
    }

    func refreshGroupTasksNow() async {
        await reloadGroupTasks(forGroupCodes: currentGroupCodes, force: true)
    }

    func tasks(on day: Date, includeCompleted: Bool = true) -> [Assignment] {
        let calendar = Calendar.current
        return tasks
            .filter { includeCompleted || !$0.isCompleted }
            .filter { calendar.isDate($0.dueDate, inSameDayAs: day) }
            .sorted { $0.dueDate < $1.dueDate }
    }

    func canModify(_ task: Assignment) -> Bool {
        if !task.isGroupTask {
            return true
        }

        return task.creatorUserRecordName == currentUserRecordName
    }

    private func rebuildTasks() {
        tasks = (localTasks + groupTasks).sorted { lhs, rhs in
            if lhs.dueDate == rhs.dueDate {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.dueDate < rhs.dueDate
        }
    }

    private func persistTasks() {
        guard let data = try? encoder.encode(localTasks) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func loadTasks() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let savedTasks = try? decoder.decode([Assignment].self, from: data) else {
            localTasks = []
            return
        }

        localTasks = savedTasks.sorted { $0.dueDate < $1.dueDate }
    }

    private func requestNotificationPermission() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    private func syncNotifications(forceAll: Bool = false) {
        let activeTasks = tasks.filter { !$0.isCompleted }
        var desiredSignatures: [String: String] = [:]

        for task in activeTasks {
            let signature = notificationSignature(for: task)
            for identifier in notificationIdentifiers(for: task.id) {
                desiredSignatures[identifier] = signature
            }
        }

        let staleIdentifiers = Set(notificationSignatures.keys).subtracting(desiredSignatures.keys)
        if !staleIdentifiers.isEmpty {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: Array(staleIdentifiers))
        }

        for task in activeTasks {
            let identifiers = notificationIdentifiers(for: task.id)
            let shouldReschedule = forceAll || identifiers.contains { notificationSignatures[$0] != desiredSignatures[$0] }
            guard shouldReschedule else { continue }

            notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
            scheduleNotifications(for: task)
        }

        notificationSignatures = desiredSignatures
    }

    private func scheduleNotifications(for task: Assignment) {
        guard !task.isCompleted else { return }

        let now = Date()
        let calendar = Calendar.current

        if let morningReminderDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: task.dueDate),
           morningReminderDate > now {
            scheduleNotification(
                for: task,
                suffix: "morning",
                title: language.morningReminderTitle,
                body: language.morningReminderBody(for: task.title, dueDate: task.dueDate),
                date: morningReminderDate
            )
        }

        let sixHoursBefore = task.dueDate.addingTimeInterval(-6 * 60 * 60)
        if sixHoursBefore > now {
            scheduleNotification(
                for: task,
                suffix: "6h",
                title: language.hoursReminderTitle(hours: 6),
                body: language.hoursReminderBody(for: task.title, hours: 6),
                date: sixHoursBefore
            )
        }

        let oneHourBefore = task.dueDate.addingTimeInterval(-1 * 60 * 60)
        if oneHourBefore > now {
            scheduleNotification(
                for: task,
                suffix: "1h",
                title: language.hoursReminderTitle(hours: 1),
                body: language.hoursReminderBody(for: task.title, hours: 1),
                date: oneHourBefore
            )
        }
    }

    private func scheduleNotification(
        for task: Assignment,
        suffix: String,
        title: String,
        body: String,
        date: Date
    ) {
        let identifier = "task-\(task.id)-\(suffix)"
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let dateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        notificationCenter.add(request) { _ in }
    }

    private func cancelNotifications(for id: UUID) {
        let identifiers = notificationIdentifiers(for: id)
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        identifiers.forEach { notificationSignatures.removeValue(forKey: $0) }
    }

    private func notificationIdentifiers(for id: UUID) -> [String] {
        [
            "task-\(id)-morning",
            "task-\(id)-6h",
            "task-\(id)-1h"
        ]
    }

    private func notificationSignature(for task: Assignment) -> String {
        [
            task.title,
            String(task.dueDate.timeIntervalSince1970),
            language.rawValue
        ].joined(separator: "|")
    }

    private func ensuredCurrentUserRecordName() async throws -> String {
        if let currentUserRecordName {
            return currentUserRecordName
        }

        do {
            let userRecordName = try await cloudKit.fetchCurrentUserRecordName()
            currentUserRecordName = userRecordName
            return userRecordName
        } catch {
            throw TaskStoreError.cloudUnavailable
        }
    }

    private func saveGroupTask(_ task: Assignment, for group: TaskGroup) async throws -> Assignment {
        guard let userRecordName = task.creatorUserRecordName else {
            throw TaskStoreError.cloudUnavailable
        }

        let recordID = CKRecord.ID(recordName: task.id.uuidString)
        let record = CKRecord(recordType: DoneCloudKitSchema.groupTaskRecordType, recordID: recordID)
        record[DoneCloudKitSchema.taskUUIDField] = task.id.uuidString
        record[DoneCloudKitSchema.titleField] = task.title
        record[DoneCloudKitSchema.notesField] = task.notes
        record[DoneCloudKitSchema.dueDateField] = task.dueDate
        record[DoneCloudKitSchema.isCompletedField] = task.isCompleted
        record[DoneCloudKitSchema.createdAtField] = task.createdAt
        record[DoneCloudKitSchema.groupCodeField] = group.inviteCode
        record[DoneCloudKitSchema.groupNameField] = group.name
        record[DoneCloudKitSchema.creatorUserRecordNameField] = userRecordName

        do {
            let savedRecord = try await cloudKit.save(record: record)
            return assignment(from: savedRecord)
        } catch let error as CKError where error.code == .notAuthenticated || error.code == .missingEntitlement || error.code == .badContainer {
            throw TaskStoreError.cloudUnavailable
        } catch {
            throw TaskStoreError.saveFailed
        }
    }

    private func configureGroupTaskPolling(for codes: [String]) {
        groupTaskPollingTask?.cancel()
        guard !codes.isEmpty else { return }

        groupTaskPollingTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: groupTaskPollingInterval)
                } catch {
                    return
                }

                guard !Task.isCancelled else { return }
                await self?.refreshGroupTasksNow()
            }
        }
    }

    private func reloadGroupTasks(forGroupCodes codes: [String], force: Bool = false) async {
        guard !codes.isEmpty else {
            let hadGroupTasks = !groupTasks.isEmpty
            groupTasks = []
            groupTaskError = nil
            if hadGroupTasks {
                rebuildTasks()
                syncNotifications()
            }
            return
        }

        guard force || !isSyncingGroupTasks else { return }

        isSyncingGroupTasks = true
        defer { isSyncingGroupTasks = false }

        do {
            let records = try await cloudKit.query(
                recordType: DoneCloudKitSchema.groupTaskRecordType,
                predicate: NSPredicate(format: "%K IN %@", DoneCloudKitSchema.groupCodeField, codes),
                sortDescriptors: [NSSortDescriptor(key: DoneCloudKitSchema.dueDateField, ascending: true)]
            )

            let loadedTasks = records.map(assignment(from:)).sorted { $0.dueDate < $1.dueDate }
            let didTasksChange = loadedTasks != groupTasks

            if didTasksChange {
                groupTasks = loadedTasks
                rebuildTasks()
                syncNotifications()
            }
            groupTaskError = nil
        } catch let error as CKError where error.code == .notAuthenticated || error.code == .missingEntitlement || error.code == .badContainer {
            groupTaskError = .cloudUnavailable
            let hadGroupTasks = !groupTasks.isEmpty
            groupTasks = []
            if hadGroupTasks {
                rebuildTasks()
                syncNotifications()
            }
        } catch {
            groupTaskError = .saveFailed
            let hadGroupTasks = !groupTasks.isEmpty
            groupTasks = []
            if hadGroupTasks {
                rebuildTasks()
                syncNotifications()
            }
        }
    }

    private func assignment(from record: CKRecord) -> Assignment {
        let idString = record[DoneCloudKitSchema.taskUUIDField] as? String ?? record.recordID.recordName
        let id = UUID(uuidString: idString) ?? UUID()

        return Assignment(
            id: id,
            title: record[DoneCloudKitSchema.titleField] as? String ?? "",
            notes: record[DoneCloudKitSchema.notesField] as? String ?? "",
            dueDate: record[DoneCloudKitSchema.dueDateField] as? Date ?? .now,
            isCompleted: record[DoneCloudKitSchema.isCompletedField] as? Bool ?? false,
            createdAt: record[DoneCloudKitSchema.createdAtField] as? Date ?? .now,
            groupCode: record[DoneCloudKitSchema.groupCodeField] as? String,
            groupName: record[DoneCloudKitSchema.groupNameField] as? String,
            cloudRecordName: record.recordID.recordName,
            creatorUserRecordName: record[DoneCloudKitSchema.creatorUserRecordNameField] as? String
        )
    }
}
