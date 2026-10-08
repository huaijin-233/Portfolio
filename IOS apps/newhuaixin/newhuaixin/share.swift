//  share.swift
//  Huai Xin
//
//  Created by Huaijin233 on 2/23/26.
//

import Foundation

// MARK: - Invite / Share Logic (No UI)

/// Rules implemented here:
/// 1) Share (generate invite code): each user can generate/share at most once per day (resets next day).
/// 2) Redeem (enter invite code): each account can redeem at most once in their lifetime.
/// 3) Each invite code can be redeemed at most once.
/// 4) On successful redeem: inviter +100 freeMessageCount, redeemer +100 freeMessageCount.
final class ShareManager {
    static let shared = ShareManager()

    private let db = Firestore.firestore()
    private init() {}

    // Firestore fields (users/{uid})
    private let kFreeCount = "freeMessageCount"
    private let kLastInviteCreatedAt = "lastInviteCreatedAt"       // Timestamp
    private let kLastInviteCode = "lastInviteCode"                 // String
    private let kHasRedeemedInvite = "hasRedeemedInvite"           // Bool
    private let kRedeemedInviteCode = "redeemedInviteCode"         // String

    // Firestore collection for invite codes
    private let inviteCodesCollection = "inviteCodes"

    enum ShareError: LocalizedError {
        case notLoggedIn
        case alreadySharedToday(code: String?)
        case invalidCodeFormat
        case codeNotFound
        case codeAlreadyRedeemed
        case cannotRedeemOwnCode
        case alreadyRedeemedOnce
        case internalError(String)

        var errorCode: Int {
            switch self {
            case .notLoggedIn:
                return 1
            case .alreadySharedToday:
                return 2
            case .invalidCodeFormat:
                return 3
            case .codeNotFound:
                return 4
            case .codeAlreadyRedeemed:
                return 5
            case .cannotRedeemOwnCode:
                return 6
            case .alreadyRedeemedOnce:
                return 7
            case .internalError:
                return 8
            }
        }

        var errorDescription: String? {
            switch self {
            case .notLoggedIn:
                return LT("Not logged in", "ログインしていません", "尚未登入")
            case .alreadySharedToday(let code):
                if let code = code, !code.isEmpty {
                    return LT(
                        "Already shared today (code: \(code))",
                        "今日はすでに共有済みです（コード: \(code)）",
                        "今天已經分享過了（邀請碼：\(code)）"
                    )
                }
                return LT("Already shared today", "今日はすでに共有済みです", "今天已經分享過了")
            case .invalidCodeFormat:
                return LT("Invalid invite code", "招待コードが無効です", "邀請碼無效")
            case .codeNotFound:
                return LT("Invite code not found", "招待コードが見つかりません", "找不到邀請碼")
            case .codeAlreadyRedeemed:
                return LT("Invite code already redeemed", "この招待コードはすでに使用されています", "這個邀請碼已被兌換")
            case .cannotRedeemOwnCode:
                return LT("Cannot redeem your own code", "自分の招待コードは使用できません", "不能兌換自己的邀請碼")
            case .alreadyRedeemedOnce:
                return LT("You can only redeem once", "招待コードの入力は一度だけです", "邀請碼只能兌換一次")
            case .internalError(let msg):
                return msg
            }
        }

        var asNSError: NSError {
            NSError(domain: "ShareManager", code: errorCode, userInfo: [NSLocalizedDescriptionKey: self.localizedDescription])
        }

        static func fromNSError(_ ns: NSError) -> ShareError? {
            guard ns.domain == "ShareManager" else { return nil }
            switch ns.code {
            case 1:
                return .notLoggedIn
            case 2:
                return .alreadySharedToday(code: nil)
            case 3:
                return .invalidCodeFormat
            case 4:
                return .codeNotFound
            case 5:
                return .codeAlreadyRedeemed
            case 6:
                return .cannotRedeemOwnCode
            case 7:
                return .alreadyRedeemedOnce
            case 8:
                return .internalError(ns.localizedDescription)
            default:
                return .internalError(ns.localizedDescription)
            }
        }
    }

    // MARK: - Public API

    /// Create today's invite code.
    /// - If user already created one today, throws `.alreadySharedToday(code:)`.
    /// - On success, returns the newly created 6-letter code.
    @MainActor
    func createDailyInviteCode() async throws -> String {
        guard let uid = Auth.auth().currentUser?.uid else { throw ShareError.notLoggedIn }

        // Try multiple times to avoid extremely rare code collisions.
        var lastError: Error?
        for _ in 0..<6 {
            let code = Self.generateCode(length: 6)
            do {
                try await runCreateDailyInviteTransaction(uid: uid, code: code)
                return code
            } catch let e as ShareError {
                // If already shared today, stop immediately (do not retry).
                if case .alreadySharedToday = e { throw e }
                lastError = e
            } catch {
                lastError = error
            }
        }
        throw lastError ?? ShareError.internalError(LT("Failed to create invite code", "招待コードの作成に失敗しました", "建立邀請碼失敗"))
    }

    /// Fetch today's existing invite code, if any. Returns nil if none created today.
    @MainActor
    func fetchTodayInviteCode() async throws -> String? {
        guard let uid = Auth.auth().currentUser?.uid else { throw ShareError.notLoggedIn }
        let userRef = db.collection("users").document(uid)
        let snap = try await userRef.getDocument()
        let data = snap.data() ?? [:]

        if let ts = data[kLastInviteCreatedAt] as? Timestamp,
           Calendar.current.isDateInToday(ts.dateValue()) {
            return data[kLastInviteCode] as? String
        }
        return nil
    }

    /// Redeem an invite code.
    /// - Each account can redeem only once in their lifetime.
    /// - Each code can be redeemed only once.
    /// - On success: inviter +100, redeemer +100.
    @MainActor
    func redeemInviteCode(_ rawCode: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { throw ShareError.notLoggedIn }
        let code = Self.normalizeCode(rawCode)
        guard Self.isValidCode(code) else { throw ShareError.invalidCodeFormat }

        try await runRedeemTransaction(redeemerUid: uid, code: code)
    }

    // MARK: - Transactions

    private func runCreateDailyInviteTransaction(uid: String, code: String) async throws {
        let userRef = db.collection("users").document(uid)
        let codeRef = db.collection(inviteCodesCollection).document(code)

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            db.runTransaction({ (transaction, errorPointer) -> Any? in
                // 1) Read user doc
                let userSnap: DocumentSnapshot
                do {
                    userSnap = try transaction.getDocument(userRef)
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }

                let userData = userSnap.data() ?? [:]

                // 2) Check daily limit
                if let ts = userData[self.kLastInviteCreatedAt] as? Timestamp,
                   Calendar.current.isDateInToday(ts.dateValue()) {
                    let existing = userData[self.kLastInviteCode] as? String
                    errorPointer?.pointee = ShareError.alreadySharedToday(code: existing).asNSError
                    return nil
                }

                // 3) Ensure code doc does not already exist (collision)
                let codeSnap: DocumentSnapshot
                do {
                    codeSnap = try transaction.getDocument(codeRef)
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }

                if codeSnap.exists {
                    errorPointer?.pointee = ShareError.internalError(LT("Code collision", "コードが重複しました", "邀請碼衝突")).asNSError
                    return nil
                }

                // 4) Write invite code doc
                transaction.setData([
                    "ownerUid": uid,
                    "createdAt": FieldValue.serverTimestamp(),
                    "redeemedBy": NSNull(),
                    "redeemedAt": NSNull()
                ], forDocument: codeRef)

                // 5) Update user's lastInviteCreatedAt + lastInviteCode
                // Use setData(merge:true) to be tolerant even if user doc shape changes.
                transaction.setData([
                    self.kLastInviteCreatedAt: FieldValue.serverTimestamp(),
                    self.kLastInviteCode: code
                ], forDocument: userRef, merge: true)

                return nil
            }, completion: { (_, error) in
                if let error = error {
                    let ns = error as NSError
                    if let mapped = ShareError.fromNSError(ns) {
                        cont.resume(throwing: mapped)
                    } else {
                        cont.resume(throwing: error)
                    }
                } else {
                    cont.resume(returning: ())
                }
            })
        }
    }

    private func runRedeemTransaction(redeemerUid: String, code: String) async throws {
        let redeemerRef = db.collection("users").document(redeemerUid)
        let codeRef = db.collection(inviteCodesCollection).document(code)

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            db.runTransaction({ (transaction, errorPointer) -> Any? in
                // 1) Read redeemer user
                let redeemerSnap: DocumentSnapshot
                do {
                    redeemerSnap = try transaction.getDocument(redeemerRef)
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
                let redeemerData = redeemerSnap.data() ?? [:]

                // Redeem only once in lifetime
                let alreadyRedeemed = redeemerData[self.kHasRedeemedInvite] as? Bool ?? false
                if alreadyRedeemed {
                    errorPointer?.pointee = ShareError.alreadyRedeemedOnce.asNSError
                    return nil
                }

                // 2) Read code doc
                let codeSnap: DocumentSnapshot
                do {
                    codeSnap = try transaction.getDocument(codeRef)
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }

                guard codeSnap.exists else {
                    errorPointer?.pointee = ShareError.codeNotFound.asNSError
                    return nil
                }

                let codeData = codeSnap.data() ?? [:]
                let ownerUid = codeData["ownerUid"] as? String ?? ""
                if ownerUid.isEmpty {
                    errorPointer?.pointee = ShareError.internalError("Invalid invite code data").asNSError
                    return nil
                }

                if ownerUid == redeemerUid {
                    errorPointer?.pointee = ShareError.cannotRedeemOwnCode.asNSError
                    return nil
                }

                // One-time code: redeemedBy must be absent/null/empty
                if let redeemedBy = codeData["redeemedBy"] as? String, !redeemedBy.isEmpty {
                    errorPointer?.pointee = ShareError.codeAlreadyRedeemed.asNSError
                    return nil
                }

                // 3) Update invite code doc to redeemed
                transaction.updateData([
                    "redeemedBy": redeemerUid,
                    "redeemedAt": FieldValue.serverTimestamp()
                ], forDocument: codeRef)

                // 4) +100 to redeemer and mark redeemed-once
                transaction.setData([
                    self.kFreeCount: FieldValue.increment(Int64(100)),
                    self.kHasRedeemedInvite: true,
                    self.kRedeemedInviteCode: code
                ], forDocument: redeemerRef, merge: true)

                // 5) +100 to inviter
                let inviterRef = self.db.collection("users").document(ownerUid)
                transaction.setData([
                    self.kFreeCount: FieldValue.increment(Int64(100))
                ], forDocument: inviterRef, merge: true)

                return nil
            }, completion: { (_, error) in
                if let error = error {
                    let ns = error as NSError
                    if let mapped = ShareError.fromNSError(ns) {
                        cont.resume(throwing: mapped)
                    } else {
                        cont.resume(throwing: error)
                    }
                } else {
                    cont.resume(returning: ())
                }
            })
        }
    }

    // MARK: - Helpers

    static func normalizeCode(_ code: String) -> String {
        code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    static func isValidCode(_ code: String) -> Bool {
        let pattern = "^[A-Z]{6}$"
        return code.range(of: pattern, options: .regularExpression) != nil
    }

    static func generateCode(length: Int) -> String {
        let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        var result = ""
        result.reserveCapacity(length)
        for _ in 0..<length {
            if let c = letters.randomElement() {
                result.append(c)
            }
        }
        return result
    }
}
