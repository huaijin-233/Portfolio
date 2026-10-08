//
//  TaskDateFormatting.swift
//  Done
//
//  Created by Codex on 3/11/26.
//

import Foundation

enum TaskDateFormatting {
    static func dueDateTime(_ date: Date, locale: Locale) -> String {
        date.formatted(
            Date.FormatStyle(date: .abbreviated, time: .shortened)
                .locale(locale)
        )
    }

    static func monthTitle(_ date: Date, locale: Locale) -> String {
        date.formatted(
            Date.FormatStyle()
                .month(.wide)
                .year()
                .locale(locale)
        )
    }

    static func dayTitle(_ date: Date, locale: Locale) -> String {
        date.formatted(
            Date.FormatStyle(date: .complete, time: .omitted)
                .locale(locale)
        )
    }

    static func relativeDate(_ date: Date, relativeTo referenceDate: Date = Date(), locale: Locale) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: referenceDate)
    }
}
