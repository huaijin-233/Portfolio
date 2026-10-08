//
//  TodoView.swift
//  Done
//
//  Created by Codex on 3/11/26.
//

import SwiftUI

struct TodoView: View {
    @EnvironmentObject private var localization: LocalizationStore
    @EnvironmentObject private var themeStore: ThemeStore
    @ObservedObject var store: TaskStore
    @State private var openedTaskRowID: String?

    private var now: Date { Date() }

    private var overdueTasks: [Assignment] {
        store.incompleteTasksSorted.filter { $0.dueDate < now }
    }

    private var todayTasks: [Assignment] {
        let calendar = Calendar.current
        return store.incompleteTasksSorted.filter {
            $0.dueDate >= now && calendar.isDateInToday($0.dueDate)
        }
    }

    private var nextSevenDayTasks: [Assignment] {
        let calendar = Calendar.current
        let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now) ?? now)
        let eightDaysFromToday = calendar.date(byAdding: .day, value: 8, to: calendar.startOfDay(for: now)) ?? now

        return store.incompleteTasksSorted.filter {
            $0.dueDate >= tomorrow && $0.dueDate < eightDaysFromToday
        }
    }

    private var completedTasks: [Assignment] {
        store.tasks
            .filter { $0.isCompleted }
            .sorted { $0.dueDate > $1.dueDate }
    }

    private var hasActiveTasks: Bool {
        !overdueTasks.isEmpty || !todayTasks.isEmpty || !nextSevenDayTasks.isEmpty
    }

    private var palette: ThemePalette {
        themeStore.theme.palette
    }

    var body: some View {
        ZStack {
            ThemedScreenBackground()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    headerCard

                    if !hasActiveTasks {
                        emptyStateCard
                    } else {
                        if !overdueTasks.isEmpty {
                            taskSection(
                                title: localization.text(.overdue),
                                tasks: overdueTasks,
                                accent: palette.overdue
                            )
                        }

                        if !todayTasks.isEmpty {
                            taskSection(
                                title: localization.text(.today),
                                tasks: todayTasks,
                                accent: palette.accent
                            )
                        }

                        if !nextSevenDayTasks.isEmpty {
                            taskSection(
                                title: localization.text(.nextSevenDays),
                                tasks: nextSevenDayTasks,
                                accent: palette.warning
                            )
                        }
                    }

                    if !completedTasks.isEmpty {
                        taskSection(
                            title: localization.text(.completed),
                            tasks: Array(completedTasks.prefix(8)),
                            accent: palette.success
                        )
                    }
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

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(localization.text(.todoTitle))
                .font(.system(size: 30, weight: .bold, design: .serif))
                .foregroundStyle(.white)

            Text(localization.text(.todoSubtitle))
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.88))

            HStack(spacing: 14) {
                MetricBadge(title: localization.text(.overdue), value: "\(overdueTasks.count)")
                MetricBadge(title: localization.text(.dueToday), value: "\(todayTasks.count)")
                MetricBadge(title: localization.text(.dueSoon), value: "\(nextSevenDayTasks.count)")
            }
        }
        .heroCard()
    }

    private var emptyStateCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(palette.accent)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(palette.accentSoft)
                    )

                Text(localization.text(.allCaughtUp))
                    .font(.system(size: 22, weight: .bold, design: .serif))
            }

            Text(localization.text(.noUpcomingTasksBody))
                .font(.subheadline)
                .foregroundStyle(palette.textSecondary)
        }
        .canvasCard()
    }

    private func taskSection(title: String, tasks: [Assignment], accent: Color) -> some View {
        LazyVStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: title) {
                Text("\(tasks.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(accent.opacity(0.12))
                    )
            }

            ForEach(tasks) { task in
                taskCard(for: task)
            }
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
