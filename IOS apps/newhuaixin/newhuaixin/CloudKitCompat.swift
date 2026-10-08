import Foundation
import CloudKit
import CryptoKit

typealias AuthStateDidChangeListenerHandle = UUID

final class Timestamp: NSObject, Codable {
    let date: Date

    init(date: Date) {
        self.date = date
    }

    func dateValue() -> Date {
        date
    }
}

final class FieldValueOperation {
    enum Kind {
        case increment(Int64)
        case delete
        case serverTimestamp
    }

    let kind: Kind

    init(kind: Kind) {
        self.kind = kind
    }
}

enum FieldValue {
    static func increment(_ amount: Int64) -> FieldValueOperation {
        FieldValueOperation(kind: .increment(amount))
    }

    static func delete() -> FieldValueOperation {
        FieldValueOperation(kind: .delete)
    }

    static func serverTimestamp() -> FieldValueOperation {
        FieldValueOperation(kind: .serverTimestamp)
    }
}

final class UserProfileChangeRequest {
    private let user: User
    var displayName: String?

    init(user: User) {
        self.user = user
        self.displayName = user.displayName
    }

    func commitChanges(completion: ((Error?) -> Void)? = nil) {
        let value = displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        user.displayName = value.isEmpty ? nil : value
        if let uid = user.uid.nonEmpty {
            CloudKitStore.shared.ensureUserDocument(uid: uid, displayName: user.displayName, email: user.email) { error in
                completion?(error)
            }
        } else {
            completion?(nil)
        }
    }
}

final class User {
    let uid: String
    var email: String?
    var displayName: String?

    init(uid: String, email: String?, displayName: String?) {
        self.uid = uid
        self.email = email
        self.displayName = displayName
    }

    func createProfileChangeRequest() -> UserProfileChangeRequest {
        UserProfileChangeRequest(user: self)
    }

    func updatePassword(to _: String, completion: @escaping (Error?) -> Void) {
        let error = NSError(
            domain: "CloudKitAuth",
            code: 301,
            userInfo: [NSLocalizedDescriptionKey: LT("Password login is no longer used on this app.", "このアプリではパスワードログインは使用しません。", "這個 App 已不再使用密碼登入。")]
        )
        completion(error)
    }

    func delete(completion: @escaping (Error?) -> Void) {
        CloudKitStore.shared.deleteAllData(for: uid) { error in
            if error == nil {
                Auth.auth().handleDeletedCurrentUser(uid: self.uid)
            }
            completion(error)
        }
    }
}

struct AuthDataResult {
    let user: User
}

final class Auth {
    static let shared = Auth()

    static func auth() -> Auth {
        shared
    }

    private(set) var currentUser: User?
    private var listeners: [UUID: (Auth, User?) -> Void] = [:]
    private let queue = DispatchQueue(label: "CloudKitAuth.queue", qos: .userInitiated)
    private var hasBootstrapped = false
    private var isRefreshing = false
    private var lastError: Error?

    private init() {}

    func bootstrapIfNeeded() {
        queue.async {
            guard !self.hasBootstrapped else { return }
            self.hasBootstrapped = true
            self.refreshSession(forceNotify: true, completion: nil)
        }
    }

    func refreshSession(forceNotify: Bool = false, completion: ((Error?) -> Void)? = nil) {
        queue.async {
            if self.isRefreshing {
                DispatchQueue.main.async { completion?(self.lastError) }
                return
            }
            self.isRefreshing = true
            CloudKitStore.shared.fetchCurrentUser { result in
                self.isRefreshing = false
                switch result {
                case .success(let user):
                    self.lastError = nil
                    self.currentUser = user
                    self.notifyListeners(force: forceNotify)
                    DispatchQueue.main.async { completion?(nil) }
                case .failure(let error):
                    self.lastError = error
                    self.currentUser = nil
                    self.notifyListeners(force: forceNotify)
                    DispatchQueue.main.async { completion?(error) }
                }
            }
        }
    }

    func addStateDidChangeListener(_ listener: @escaping (Auth, User?) -> Void) -> AuthStateDidChangeListenerHandle {
        let handle = UUID()
        listeners[handle] = listener
        DispatchQueue.main.async {
            listener(self, self.currentUser)
        }
        bootstrapIfNeeded()
        return handle
    }

    func removeStateDidChangeListener(_ handle: AuthStateDidChangeListenerHandle) {
        listeners.removeValue(forKey: handle)
    }

    func createUser(withEmail email: String, password _: String, completion: @escaping (AuthDataResult?, Error?) -> Void) {
        let error = NSError(
            domain: "CloudKitAuth",
            code: 302,
            userInfo: [NSLocalizedDescriptionKey: LT("Email registration has been removed. This app now uses your Apple/iCloud account directly.", "メール登録は廃止されました。このアプリは Apple / iCloud アカウントを直接使用します。", "郵箱註冊已移除，這個 App 現在直接使用你的 Apple / iCloud 賬戶。")]
        )
        refreshSession(forceNotify: true) { refreshError in
            if let user = self.currentUser, refreshError == nil {
                user.email = email
                completion(AuthDataResult(user: user), nil)
            } else {
                completion(nil, refreshError ?? error)
            }
        }
    }

    func signIn(withEmail email: String, password _: String, completion: @escaping (AuthDataResult?, Error?) -> Void) {
        refreshSession(forceNotify: true) { error in
            if let user = self.currentUser, error == nil {
                user.email = email
                completion(AuthDataResult(user: user), nil)
            } else {
                completion(nil, error)
            }
        }
    }

    func signOut() throws {
        currentUser = nil
        notifyListeners(force: true)
    }

    func handleDeletedCurrentUser(uid: String) {
        guard currentUser?.uid == uid else { return }
        currentUser = nil
        notifyListeners(force: true)
    }

    private func notifyListeners(force _: Bool) {
        let current = currentUser
        DispatchQueue.main.async {
            self.listeners.values.forEach { $0(self, current) }
        }
    }
}

final class ListenerRegistration {
    private let removeHandler: () -> Void
    private var isRemoved = false

    init(removeHandler: @escaping () -> Void) {
        self.removeHandler = removeHandler
    }

    func remove() {
        guard !isRemoved else { return }
        isRemoved = true
        removeHandler()
    }
}

final class DocumentSnapshot {
    let reference: DocumentReference
    let exists: Bool
    private let storedData: [String: Any]?

    init(reference: DocumentReference, exists: Bool, data: [String: Any]?) {
        self.reference = reference
        self.exists = exists
        self.storedData = data
    }

    var documentID: String {
        reference.documentID
    }

    func data() -> [String: Any]? {
        storedData
    }
}

final class QuerySnapshot {
    let documents: [DocumentSnapshot]

    init(documents: [DocumentSnapshot]) {
        self.documents = documents
    }
}

final class Firestore {
    static let shared = Firestore()

    static func firestore() -> Firestore {
        shared
    }

    func collection(_ path: String) -> CollectionReference {
        CollectionReference(path: path, store: CloudKitStore.shared)
    }

    func batch() -> WriteBatch {
        WriteBatch(store: CloudKitStore.shared)
    }

    func runTransaction(_ updateBlock: @escaping (Transaction, NSErrorPointer) -> Any?, completion: @escaping (Any?, Error?) -> Void) {
        let transaction = Transaction(store: CloudKitStore.shared)
        DispatchQueue.global(qos: .userInitiated).async {
            var nsError: NSError?
            let result = updateBlock(transaction, &nsError)
            if let nsError {
                DispatchQueue.main.async { completion(nil, nsError) }
                return
            }
            transaction.commit { error in
                DispatchQueue.main.async {
                    completion(result, error)
                }
            }
        }
    }
}

class Query {
    fileprivate let path: String
    fileprivate let store: CloudKitStore
    fileprivate var orderField: String?
    fileprivate var orderDescending = false
    fileprivate var limitValue: Int?
    fileprivate var limitToLastValue: Int?

    init(path: String, store: CloudKitStore) {
        self.path = path
        self.store = store
    }

    func order(by field: String, descending: Bool = false) -> Self {
        orderField = field
        orderDescending = descending
        return self
    }

    func limit(to value: Int) -> Self {
        limitValue = value
        limitToLastValue = nil
        return self
    }

    func limit(toLast value: Int) -> Self {
        limitToLastValue = value
        limitValue = nil
        return self
    }

    func getDocuments(completion: @escaping (QuerySnapshot?, Error?) -> Void) {
        store.fetchDocuments(inCollectionPath: path) { result in
            switch result {
            case .success(let docs):
                let snapshots = self.applyQueryModifiers(to: docs).map {
                    DocumentSnapshot(reference: DocumentReference(path: $0.path, store: self.store), exists: true, data: $0.data)
                }
                DispatchQueue.main.async {
                    completion(QuerySnapshot(documents: snapshots), nil)
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(nil, error)
                }
            }
        }
    }

    func addSnapshotListener(_ listener: @escaping (QuerySnapshot?, Error?) -> Void) -> ListenerRegistration {
        store.addQueryListener(query: self, listener: listener)
    }

    fileprivate func applyQueryModifiers(to docs: [StoredDocument]) -> [StoredDocument] {
        var output = docs
        if let field = orderField {
            output.sort { lhs, rhs in
                CloudKitStore.compare(lhs.data[field], rhs.data[field], descending: orderDescending)
            }
        } else {
            output.sort { lhs, rhs in lhs.path < rhs.path }
        }
        if let limitValue {
            output = Array(output.prefix(limitValue))
        } else if let limitToLastValue {
            output = Array(output.suffix(limitToLastValue))
        }
        return output
    }
}

final class CollectionReference: Query {
    func document(_ documentID: String) -> DocumentReference {
        DocumentReference(path: "\(path)/\(documentID)", store: store)
    }

    @discardableResult
    func addDocument(data: [String: Any], completion: ((Error?) -> Void)? = nil) -> DocumentReference {
        let ref = document(UUID().uuidString)
        ref.setData(data, completion: completion)
        return ref
    }
}

final class DocumentReference {
    let path: String
    fileprivate let store: CloudKitStore

    init(path: String, store: CloudKitStore) {
        self.path = path
        self.store = store
    }

    var documentID: String {
        path.split(separator: "/").last.map(String.init) ?? path
    }

    func collection(_ path: String) -> CollectionReference {
        CollectionReference(path: "\(self.path)/\(path)", store: store)
    }

    func setData(_ data: [String: Any], completion: ((Error?) -> Void)? = nil) {
        setData(data, merge: false, completion: completion)
    }

    func setData(_ data: [String: Any], merge: Bool, completion: ((Error?) -> Void)? = nil) {
        store.saveDocument(path: path, data: data, merge: merge, completion: completion)
    }

    func updateData(_ fields: [String: Any], completion: ((Error?) -> Void)? = nil) {
        store.updateDocument(path: path, fields: fields, completion: completion)
    }

    func delete(completion: ((Error?) -> Void)? = nil) {
        store.deleteDocument(path: path, completion: completion)
    }

    func getDocument(completion: @escaping (DocumentSnapshot?, Error?) -> Void) {
        store.fetchDocument(path: path) { result in
            switch result {
            case .success(let stored):
                let snapshot = DocumentSnapshot(reference: self, exists: stored != nil, data: stored?.data)
                DispatchQueue.main.async {
                    completion(snapshot, nil)
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(nil, error)
                }
            }
        }
    }

    func getDocument() async throws -> DocumentSnapshot {
        try await withCheckedThrowingContinuation { cont in
            getDocument { snapshot, error in
                if let error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume(returning: snapshot ?? DocumentSnapshot(reference: self, exists: false, data: nil))
                }
            }
        }
    }

    func addSnapshotListener(_ listener: @escaping (DocumentSnapshot?, Error?) -> Void) -> ListenerRegistration {
        store.addDocumentListener(reference: self, listener: listener)
    }
}

final class WriteBatch {
    private let store: CloudKitStore
    private var deletePaths: [String] = []

    init(store: CloudKitStore) {
        self.store = store
    }

    func deleteDocument(_ reference: DocumentReference) {
        deletePaths.append(reference.path)
    }

    func commit(completion: ((Error?) -> Void)? = nil) {
        let group = DispatchGroup()
        var firstError: Error?
        for path in deletePaths {
            group.enter()
            store.deleteDocument(path: path) { error in
                if firstError == nil {
                    firstError = error
                }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            completion?(firstError)
        }
    }
}

final class Transaction {
    private enum Operation {
        case set(DocumentReference, [String: Any], Bool)
        case update(DocumentReference, [String: Any])
    }

    private let store: CloudKitStore
    private var operations: [Operation] = []

    init(store: CloudKitStore) {
        self.store = store
    }

    func getDocument(_ reference: DocumentReference) throws -> DocumentSnapshot {
        let semaphore = DispatchSemaphore(value: 0)
        var output: Result<DocumentSnapshot, Error>!
        store.fetchDocument(path: reference.path) { result in
            switch result {
            case .success(let stored):
                output = .success(DocumentSnapshot(reference: reference, exists: stored != nil, data: stored?.data))
            case .failure(let error):
                output = .failure(error)
            }
            semaphore.signal()
        }
        semaphore.wait()
        return try output.get()
    }

    func setData(_ data: [String: Any], forDocument reference: DocumentReference) {
        operations.append(.set(reference, data, false))
    }

    func setData(_ data: [String: Any], forDocument reference: DocumentReference, merge: Bool) {
        operations.append(.set(reference, data, merge))
    }

    func updateData(_ data: [String: Any], forDocument reference: DocumentReference) {
        operations.append(.update(reference, data))
    }

    func commit(completion: @escaping (Error?) -> Void) {
        commitNext(index: 0, completion: completion)
    }

    private func commitNext(index: Int, completion: @escaping (Error?) -> Void) {
        guard index < operations.count else {
            completion(nil)
            return
        }

        let op = operations[index]
        switch op {
        case let .set(reference, data, merge):
            store.saveDocument(path: reference.path, data: data, merge: merge) { error in
                if let error {
                    completion(error)
                } else {
                    self.commitNext(index: index + 1, completion: completion)
                }
            }
        case let .update(reference, data):
            store.updateDocument(path: reference.path, fields: data) { error in
                if let error {
                    completion(error)
                } else {
                    self.commitNext(index: index + 1, completion: completion)
                }
            }
        }
    }
}

struct StoredDocument {
    let path: String
    let collectionPath: String
    let documentID: String
    let data: [String: Any]
    let updatedAt: Date
}

final class CloudKitStore {
    static let shared = CloudKitStore()

    private let container: CKContainer
    private let database: CKDatabase
    private let queryQueue = DispatchQueue(label: "CloudKitStore.query", qos: .userInitiated)
    private let listenerQueue = DispatchQueue(label: "CloudKitStore.listener", qos: .utility)
    private let notificationCenter = NotificationCenter.default
    private let mutationNotification = Notification.Name("CloudKitStore.didMutate")
    private let recordType = "AppDocument"
    private let containerIdentifier = "iCloud.com.zhuhuaijin.newhuaixin"

    private init() {
        container = CKContainer(identifier: containerIdentifier)
        database = container.publicCloudDatabase
    }

    func fetchCurrentUser(completion: @escaping (Result<User, Error>) -> Void) {
        let defaultContainer = CKContainer(identifier: containerIdentifier)
        defaultContainer.accountStatus { status, error in
            if let error {
                completion(.failure(error))
                return
            }

            guard status == .available else {
                let message = LT("Please sign in to iCloud on this device before using the app.", "このアプリを使う前に、この端末で iCloud にサインインしてください。", "使用這個 App 前，請先在此裝置登入 iCloud。")
                let error = NSError(domain: "CloudKitAuth", code: 101, userInfo: [NSLocalizedDescriptionKey: message])
                completion(.failure(error))
                return
            }

            defaultContainer.fetchUserRecordID { recordID, error in
                if let error {
                    completion(.failure(error))
                    return
                }
                guard let recordID else {
                    let error = NSError(domain: "CloudKitAuth", code: 102, userInfo: [NSLocalizedDescriptionKey: LT("Failed to resolve the iCloud account.", "iCloud アカウントを取得できませんでした。", "無法取得 iCloud 賬戶。")])
                    completion(.failure(error))
                    return
                }

                let uid = recordID.recordName
                self.fetchDocument(path: "users/\(uid)") { result in
                    let existingData = (try? result.get())?.data
                    let displayName = existingData?["username"] as? String
                    let email = existingData?["email"] as? String
                    let user = User(uid: uid, email: email, displayName: displayName)
                    self.ensureUserDocument(uid: uid, displayName: displayName, email: email) { ensureError in
                        if let ensureError {
                            completion(.failure(ensureError))
                        } else {
                            completion(.success(user))
                        }
                    }
                }
            }
        }
    }

    func ensureUserDocument(uid: String, displayName: String?, email: String?, completion: ((Error?) -> Void)? = nil) {
        fetchDocument(path: "users/\(uid)") { result in
            switch result {
            case .failure(let error):
                DispatchQueue.main.async { completion?(error) }
            case .success(let stored):
                var base: [String: Any] = stored?.data ?? [:]
                let defaultName = displayName?.nonEmpty ?? base["username"] as? String ?? localizedDefaultUserName()
                if base["username"] == nil { base["username"] = defaultName }
                if let email = email?.nonEmpty ?? (base["email"] as? String)?.nonEmpty {
                    base["email"] = email
                }
                if base["freeMessageCount"] == nil { base["freeMessageCount"] = 100 }
                if base["createdAt"] == nil { base["createdAt"] = Timestamp(date: Date()) }
                self.saveDocument(path: "users/\(uid)", data: base, merge: false, completion: completion)
            }
        }
    }

    func deleteAllData(for uid: String, completion: @escaping (Error?) -> Void) {
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(format: "fsPath BEGINSWITH %@", "users/\(uid)"))
        fetchAllRecords(for: query, desiredKeys: ["fsPath"]) { result in
            switch result {
            case .failure(let error):
                DispatchQueue.main.async { completion(error) }
            case .success(let records):
                let ids = records.map(\.recordID)
                guard !ids.isEmpty else {
                    DispatchQueue.main.async { completion(nil) }
                    return
                }
                let op = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: ids)
                op.modifyRecordsResultBlock = { result in
                    switch result {
                    case .success:
                        self.broadcastMutation(paths: ["users/\(uid)"])
                        DispatchQueue.main.async { completion(nil) }
                    case .failure(let error):
                        DispatchQueue.main.async { completion(error) }
                    }
                }
                self.database.add(op)
            }
        }
    }

    func fetchDocument(path: String, completion: @escaping (Result<StoredDocument?, Error>) -> Void) {
        let recordID = CKRecord.ID(recordName: Self.recordName(for: path))
        database.fetch(withRecordID: recordID) { record, error in
            if let ckError = error as? CKError, ckError.code == .unknownItem {
                completion(.success(nil))
                return
            }
            if let error {
                completion(.failure(error))
                return
            }
            guard let record else {
                completion(.success(nil))
                return
            }
            do {
                completion(.success(try self.makeStoredDocument(from: record)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func fetchDocuments(inCollectionPath path: String, completion: @escaping (Result<[StoredDocument], Error>) -> Void) {
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(format: "collectionPath == %@", path))
        fetchAllRecords(for: query, desiredKeys: ["fsPath", "collectionPath", "documentId", "payloadData", "updatedAt"]) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let records):
                do {
                    let docs = try records.map { try self.makeStoredDocument(from: $0) }
                    completion(.success(docs))
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }

    func saveDocument(path: String, data: [String: Any], merge: Bool, completion: ((Error?) -> Void)? = nil) {
        fetchDocument(path: path) { result in
            switch result {
            case .failure(let error):
                DispatchQueue.main.async { completion?(error) }
            case .success(let stored):
                let finalData = merge ? Self.merge(base: stored?.data ?? [:], incoming: data) : Self.resolveFieldOperations(in: data, base: stored?.data ?? [:], allowDeletes: false)
                do {
                    try self.saveResolvedDocument(path: path, data: finalData, completion: completion)
                } catch {
                    DispatchQueue.main.async { completion?(error) }
                }
            }
        }
    }

    func updateDocument(path: String, fields: [String: Any], completion: ((Error?) -> Void)? = nil) {
        fetchDocument(path: path) { result in
            switch result {
            case .failure(let error):
                DispatchQueue.main.async { completion?(error) }
            case .success(let stored):
                let finalData = Self.resolveFieldOperations(in: fields, base: stored?.data ?? [:], allowDeletes: true)
                do {
                    try self.saveResolvedDocument(path: path, data: finalData, completion: completion)
                } catch {
                    DispatchQueue.main.async { completion?(error) }
                }
            }
        }
    }

    func deleteDocument(path: String, completion: ((Error?) -> Void)? = nil) {
        let recordID = CKRecord.ID(recordName: Self.recordName(for: path))
        database.delete(withRecordID: recordID) { _, error in
            if let ckError = error as? CKError, ckError.code == .unknownItem {
                self.broadcastMutation(paths: [path])
                DispatchQueue.main.async { completion?(nil) }
                return
            }
            if let error {
                DispatchQueue.main.async { completion?(error) }
                return
            }
            self.broadcastMutation(paths: [path])
            DispatchQueue.main.async { completion?(nil) }
        }
    }

    func addQueryListener(query: Query, listener: @escaping (QuerySnapshot?, Error?) -> Void) -> ListenerRegistration {
        makeListenerRegistration {
            query.getDocuments(completion: listener)
        }
    }

    func addDocumentListener(reference: DocumentReference, listener: @escaping (DocumentSnapshot?, Error?) -> Void) -> ListenerRegistration {
        makeListenerRegistration {
            reference.getDocument(completion: listener)
        }
    }

    private func makeListenerRegistration(refresh: @escaping () -> Void) -> ListenerRegistration {
        let observer = notificationCenter.addObserver(forName: mutationNotification, object: nil, queue: .main) { _ in
            refresh()
        }

        let timer = DispatchSource.makeTimerSource(queue: listenerQueue)
        timer.schedule(deadline: .now() + 3, repeating: 3)
        timer.setEventHandler(handler: refresh)
        timer.resume()

        DispatchQueue.main.async {
            refresh()
        }

        return ListenerRegistration {
            self.notificationCenter.removeObserver(observer)
            timer.cancel()
        }
    }

    private func saveResolvedDocument(path: String, data: [String: Any], completion: ((Error?) -> Void)? = nil) throws {
        let recordID = CKRecord.ID(recordName: Self.recordName(for: path))
        let record = CKRecord(recordType: recordType, recordID: recordID)
        record["fsPath"] = path as NSString
        record["collectionPath"] = Self.collectionPath(for: path) as NSString
        record["documentId"] = Self.documentID(for: path) as NSString
        record["updatedAt"] = Date() as NSDate
        record["payloadData"] = try Self.encodePayload(data) as NSData

        let op = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
        op.savePolicy = .changedKeys
        op.modifyRecordsResultBlock = { result in
            switch result {
            case .success:
                self.broadcastMutation(paths: [path])
                DispatchQueue.main.async { completion?(nil) }
            case .failure(let error):
                DispatchQueue.main.async { completion?(error) }
            }
        }
        database.add(op)
    }

    private func fetchAllRecords(for query: CKQuery, desiredKeys: [String], completion: @escaping (Result<[CKRecord], Error>) -> Void) {
        var allRecords: [CKRecord] = []

        func run(cursor: CKQueryOperation.Cursor?) {
            let operation: CKQueryOperation
            if let cursor {
                operation = CKQueryOperation(cursor: cursor)
            } else {
                operation = CKQueryOperation(query: query)
            }
            operation.desiredKeys = desiredKeys
            operation.recordMatchedBlock = { _, result in
                if case let .success(record) = result {
                    allRecords.append(record)
                }
            }
            operation.queryResultBlock = { result in
                switch result {
                case .success(let cursor):
                    if let cursor {
                        run(cursor: cursor)
                    } else {
                        completion(.success(allRecords))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
            self.database.add(operation)
        }

        run(cursor: nil)
    }

    private func makeStoredDocument(from record: CKRecord) throws -> StoredDocument {
        let path = record["fsPath"] as? String ?? ""
        let collectionPath = record["collectionPath"] as? String ?? Self.collectionPath(for: path)
        let documentID = record["documentId"] as? String ?? Self.documentID(for: path)
        let updatedAt = (record["updatedAt"] as? Date) ?? Date()
        let payloadData = record["payloadData"] as? Data ?? Data()
        let data = try Self.decodePayload(payloadData)
        return StoredDocument(path: path, collectionPath: collectionPath, documentID: documentID, data: data, updatedAt: updatedAt)
    }

    private func broadcastMutation(paths: [String]) {
        DispatchQueue.main.async {
            self.notificationCenter.post(name: self.mutationNotification, object: paths)
        }
    }

    static func compare(_ lhs: Any?, _ rhs: Any?, descending: Bool) -> Bool {
        let result: ComparisonResult
        switch (lhs, rhs) {
        case let (l as Timestamp, r as Timestamp):
            result = l.dateValue().compare(r.dateValue())
        case let (l as Date, r as Date):
            result = l.compare(r)
        case let (l as Int, r as Int):
            result = l == r ? .orderedSame : (l < r ? .orderedAscending : .orderedDescending)
        case let (l as Int64, r as Int64):
            result = l == r ? .orderedSame : (l < r ? .orderedAscending : .orderedDescending)
        case let (l as Double, r as Double):
            result = l == r ? .orderedSame : (l < r ? .orderedAscending : .orderedDescending)
        case let (l as String, r as String):
            result = l.localizedCaseInsensitiveCompare(r)
        case (_?, nil):
            result = .orderedDescending
        case (nil, _?):
            result = .orderedAscending
        default:
            result = .orderedSame
        }
        return descending ? (result == .orderedDescending) : (result == .orderedAscending)
    }

    private static func resolveFieldOperations(in incoming: [String: Any], base: [String: Any], allowDeletes: Bool) -> [String: Any] {
        var output = base
        for (key, value) in incoming {
            if let op = value as? FieldValueOperation {
                switch op.kind {
                case .delete:
                    if allowDeletes {
                        output.removeValue(forKey: key)
                    }
                case .serverTimestamp:
                    output[key] = Timestamp(date: Date())
                case .increment(let amount):
                    let current = output[key]
                    if let intValue = current as? Int {
                        output[key] = intValue + Int(amount)
                    } else if let int64Value = current as? Int64 {
                        output[key] = int64Value + amount
                    } else if let doubleValue = current as? Double {
                        output[key] = doubleValue + Double(amount)
                    } else {
                        output[key] = Int(amount)
                    }
                }
            } else {
                output[key] = value
            }
        }
        return output
    }

    private static func merge(base: [String: Any], incoming: [String: Any]) -> [String: Any] {
        resolveFieldOperations(in: incoming, base: base, allowDeletes: true)
    }

    private static func encodePayload(_ data: [String: Any]) throws -> Data {
        let normalized = try normalizeToJSON(data)
        return try JSONSerialization.data(withJSONObject: normalized, options: [])
    }

    private static func decodePayload(_ data: Data) throws -> [String: Any] {
        guard !data.isEmpty else { return [:] }
        let object = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dict = denormalizeFromJSON(object) as? [String: Any] else {
            return [:]
        }
        return dict
    }

    private static func normalizeToJSON(_ value: Any) throws -> Any {
        switch value {
        case let timestamp as Timestamp:
            return ["compatType": "timestamp", "value": timestamp.dateValue().timeIntervalSince1970]
        case let date as Date:
            return ["compatType": "timestamp", "value": date.timeIntervalSince1970]
        case let string as String:
            return string
        case let int as Int:
            return int
        case let int64 as Int64:
            return int64
        case let double as Double:
            return double
        case let bool as Bool:
            return bool
        case let number as NSNumber:
            return number
        case is NSNull:
            return NSNull()
        case let array as [Any]:
            return try array.map { try normalizeToJSON($0) }
        case let dict as [String: Any]:
            var output: [String: Any] = [:]
            for (key, value) in dict {
                output[key] = try normalizeToJSON(value)
            }
            return output
        default:
            throw NSError(domain: "CloudKitStore", code: 401, userInfo: [NSLocalizedDescriptionKey: "Unsupported payload value: \(type(of: value))"])
        }
    }

    private static func denormalizeFromJSON(_ value: Any) -> Any {
        if let dict = value as? [String: Any] {
            if let type = dict["compatType"] as? String, type == "timestamp", let seconds = dict["value"] as? Double {
                return Timestamp(date: Date(timeIntervalSince1970: seconds))
            }
            var output: [String: Any] = [:]
            for (key, nested) in dict {
                output[key] = denormalizeFromJSON(nested)
            }
            return output
        }
        if let array = value as? [Any] {
            return array.map { denormalizeFromJSON($0) }
        }
        return value
    }

    private static func recordName(for path: String) -> String {
        let digest = SHA256.hash(data: Data(path.utf8))
        return "doc-\(digest.map { String(format: "%02x", $0) }.joined())"
    }

    private static func collectionPath(for documentPath: String) -> String {
        let parts = documentPath.split(separator: "/").map(String.init)
        guard parts.count > 1 else { return documentPath }
        return parts.dropLast().joined(separator: "/")
    }

    private static func documentID(for documentPath: String) -> String {
        documentPath.split(separator: "/").last.map(String.init) ?? documentPath
    }
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
