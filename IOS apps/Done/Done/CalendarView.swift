//
//  CalendarView.swift
//  Done
//
//  Created by Codex on 3/11/26.
//

import SwiftUI

struct CalendarView: View {
    @EnvironmentObject private var localization: LocalizationStore
    @EnvironmentObject private var themeStore: ThemeStore
    @ObservedObject var store: TaskStore

    @State private var displayedMonth = Date()
    @State private var selectedDate = Date()
    @State private var openedTaskRowID: String?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.locale = localization.locale
        return calendar
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let offset = calendar.firstWeekday - 1
        return Array(symbols[offset...]) + Array(symbols[..<offset])
    }

    private var monthDays: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
              let dayRange = calendar.range(of: .day, in: .month, for: displayedMonth) else {
            return []
        }

        let firstDay = monthInterval.start
        let firstDayWeekday = calendar.component(.weekday, from: firstDay)
        let leadingPadding = (firstDayWeekday - calendar.firstWeekday + 7) % 7

        var days: [Date?] = Array(repeating: nil, count: leadingPadding)

        for day in dayRange {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }

        while days.count % 7 != 0 {
            days.append(nil)
        }

        return days
    }

    private var monthTaskCount: Int {
        store.tasks.filter {
            !$0.isCompleted && calendar.isDate($0.dueDate, equalTo: displayedMonth, toGranularity: .month)
        }.count
    }

    private var selectedDayTasks: [Assignment] {
        store.tasks(on: selectedDate, includeCompleted: true)
    }

    private var selectedDayTitle: String {
        String(
            format: localization.text(.tasksOnDate),
            TaskDateFormatting.dayTitle(selectedDate, locale: localization.locale)
        )
    }

    private var palette: ThemePalette {
        themeStore.theme.palette
    }

    var body: some View {
        ZStack {
            ThemedScreenBackground()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    heroCard
                    monthBoard
                    selectedDayBoard
                }
                .padding(20)
                .padding(.bottom, 28)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                ThemeMenu()
            }

            ToolbarItem(placement: .topBarTrailing) {
                LanguageMenu()
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(localization.text(.calendarTitle))
                .font(.system(size: 30, weight: .bold, design: .serif))
                .foregroundStyle(.white)

            Text(localization.text(.calendarSubtitle))
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.88))

            HStack(spacing: 14) {
                MetricBadge(title: localization.text(.tasksThisMonth), value: "\(monthTaskCount)")
                MetricBadge(title: localization.text(.selectedDay), value: "\(selectedDayTasks.count)")
            }
        }
        .heroCard()
    }

    private var monthBoard: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                title: TaskDateFormatting.monthTitle(displayedMonth, locale: localization.locale),
                subtitle: localization.text(.tasksThisMonth)
            ) {
                Text("\(monthTaskCount)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.accentDeep)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(palette.accentSoft)
                    )
            }

            monthHeader

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol.uppercased())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(palette.textSecondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(Array(monthDays.enumerated()), id: \.offset) { item in
                    if let date = item.element {
                        dayCell(for: date)
                    } else {
                        Color.clear
                            .frame(height: 68)
                    }
                }
            }
        }
        .canvasCard()
    }

    private var selectedDayBoard: some View {
        LazyVStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: selectedDayTitle) {
                Text("\(selectedDayTasks.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.accentDeep)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(palette.accentSoft)
                    )
            }

            if selectedDayTasks.isEmpty {
                Text(localization.text(.noTasksOnDate))
                    .foregroundStyle(palette.textSecondary)
                    .canvasCard()
            } else {
                ForEach(selectedDayTasks) { task in
                    taskCard(for: task)
                }
            }
        }
        .canvasCard(padding: 18)
    }

    private var monthHeader: some View {
        HStack {
            Button {
                shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .foregroundStyle(palette.accent)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(palette.accentSoft)
                    )
            }
            .buttonStyle(.plain)

            Spacer()

            Text(localization.text(.calendarTitle))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.textSecondary)

            Spacer()

            Button {
                shiftMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .foregroundStyle(palette.accent)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(palette.accentSoft)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private func dayCell(for date: Date) -> some View {
        let taskCount = store.tasks(on: date, includeCompleted: false).count
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let fillColor = isSelected ? palette.accent : palette.surface
        let dayTextColor: Color = isSelected ? .white : .primary

        return Button {
            selectedDate = date
        } label: {
            VStack(spacing: 8) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(dayTextColor)

                if taskCount > 0 {
                    Text("\(taskCount)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(isSelected ? .white : palette.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.white.opacity(0.18) : palette.accentSoft)
                        )
                } else {
                    Circle()
                        .fill(isSelected ? Color.white.opacity(0.18) : palette.border)
                        .frame(width: 8, height: 8)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 68)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(fillColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isToday ? palette.accent : palette.border, lineWidth: isSelected ? 0 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func shiftMonth(by value: Int) {
        guard let shifted = calendar.date(byAdding: .month, value: value, to: displayedMonth) else { return }
        displayedMonth = shifted

        if !calendar.isDate(selectedDate, equalTo: shifted, toGranularity: .month),
           let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: shifted)) {
            selectedDate = firstDay
        }
    }

    @ViewBuilder
    private func taskCard(for task: Assignment) -> some View {
        let row = TaskRow(
            task: task,
            canModify: store.canModify(task),
            onToggleComplete: {
                Task {
                    await store.toggleCompletion(for: task.id)
                }
            }
        )
        .equatable()

        if store.canModify(task) {
            SwipeDeleteRow(rowID: task.id.uuidString, openedRowID: $openedTaskRowID, isEnabled: true) {
                Task {
                    await store.deleteTask(task.id)
                }
            } content: {
                row
            }
        } else {
            row
        }
    }
}
