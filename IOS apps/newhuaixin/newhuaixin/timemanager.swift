//
//  timemanager.swift
//  Huai Xin
//
//  Created by Huaijin233 on 2/12/26.
import Foundation
import Combine
class TimeManager {
    static let shared = TimeManager()
    
    private let dateFormatter: DateFormatter
    
    private init() {
        dateFormatter = DateFormatter()
        // Format: Year-Month-Day Hour:Minute (e.g., 2023-10-27 14:30)
        // This gives the AI full context of the date and time.
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
    }
    
    // Returns the timestamp string to be appended to user messages
    // Example output: " [Time: 2023-10-27 14:30]"
    func getTimestampString(for date: Date) -> String {
        return " [Time: \(dateFormatter.string(from: date))]"
    }
}
