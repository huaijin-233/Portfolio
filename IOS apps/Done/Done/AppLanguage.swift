//
//  AppLanguage.swift
//  Done
//
//  Created by Codex on 3/11/26.
//

import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var id: String { rawValue }

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    var displayName: String {
        switch self {
        case .english:
            return "English"
        case .simplifiedChinese:
            return "简体中文"
        }
    }

    var morningReminderTitle: String {
        switch self {
        case .english:
            return "Today's Task"
        case .simplifiedChinese:
            return "今日任务提醒"
        }
    }

    func morningReminderBody(for title: String, dueDate: Date) -> String {
        let dueTime = dueTimeString(for: dueDate)
        switch self {
        case .english:
            return "\"\(title)\" is due today at \(dueTime)."
        case .simplifiedChinese:
            return "\"\(title)\" 今天 \(dueTime) 到期。"
        }
    }

    func hoursReminderTitle(hours: Int) -> String {
        switch self {
        case .english:
            return hours == 1 ? "Due in 1 Hour" : "Due in \(hours) Hours"
        case .simplifiedChinese:
            return "\(hours)小时后到期"
        }
    }

    func hoursReminderBody(for title: String, hours: Int) -> String {
        switch self {
        case .english:
            return "\"\(title)\" is due in \(hours) \(hours == 1 ? "hour" : "hours")."
        case .simplifiedChinese:
            return "\"\(title)\" 将在 \(hours) 小时后到期。"
        }
    }

    private func dueTimeString(for date: Date) -> String {
        date.formatted(
            Date.FormatStyle(date: .omitted, time: .shortened)
                .locale(locale)
        )
    }
}
