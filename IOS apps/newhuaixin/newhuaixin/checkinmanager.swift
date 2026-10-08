//
//  checkinmanager.swift
//  Huai Xin
//
//  Created by Huaijin233 on 2/10/26.
import Foundation

class CheckInManager {
    static let shared = CheckInManager()
    private let db = Firestore.firestore()
    
    func checkIn(userId: String, completion: @escaping (Bool, String?) -> Void) {
        let userRef = db.collection("users").document(userId)
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let doc: DocumentSnapshot
            do {
                try doc = transaction.getDocument(userRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            // 修复逻辑：如果文档不存在，说明是新用户或数据缺失
            // 直接初始化数据并给予签到奖励
            if !doc.exists {
                transaction.setData([
                    "freeMessageCount": 100, // 初始 100 次
                    "lastCheckInDate": Timestamp(date: Date()),
                    "createdAt": Timestamp(date: Date())
                ], forDocument: userRef)
                return "success"
            }
            
            guard let data = doc.data() else {
                let error = NSError(domain: "CheckInError", code: 500, userInfo: [NSLocalizedDescriptionKey: LT("Failed to read data", "データを読み取れませんでした", "無法讀取資料")])
                errorPointer?.pointee = error
                return nil
            }
            
            // Check if already checked in today
            let lastTimestamp = data["lastCheckInDate"] as? Timestamp
            if let lastDate = lastTimestamp?.dateValue(), Calendar.current.isDateInToday(lastDate) {
                return "already_checked_in"
            }
            
            // Grant reward (20 free messages)
            let currentFree = data["freeMessageCount"] as? Int ?? 0
            let newCount = currentFree + 50
            
            transaction.updateData([
                "freeMessageCount": newCount,
                "lastCheckInDate": Timestamp(date: Date())
            ], forDocument: userRef)
            
            return "success"
            
        }) { (object, error) in
            // IMPORTANT: Dispatch to Main Thread for UI updates
            DispatchQueue.main.async {
                if let error = error {
                    print("CheckIn Transaction Error: \(error)")
                    completion(false, LT("Check-in failed", "チェックインに失敗しました", "簽到失敗") + ": \(error.localizedDescription)")
                } else if let status = object as? String {
                    if status == "success" {
                        completion(true, nil)
                    } else if status == "already_checked_in" {
                        completion(false, LT("Already checked in today", "今日はすでにチェックイン済みです", "今天已經簽到過了"))
                    } else {
                        completion(false, LT("Unexpected status", "状態が異常です", "狀態異常"))
                    }
                } else {
                    completion(false, LT("Operation failed, please try again", "操作に失敗しました。もう一度お試しください", "操作失敗，請重試"))
                }
            }
        }
    }
}
