//
//  TaskRow.swift
//  Done
//
//  Created by Codex on 3/11/26.
//

import SwiftUI

struct TaskRow: View, Equatable {
    @EnvironmentObject private var localization: LocalizationStore
    @EnvironmentObject private var themeStore: ThemeStore

    let task: Assignment
    let canModify: Bool
    let onToggleComplete: () -> Void

    private var palette: ThemePalette {
        themeStore.theme.palette
    }

    private var statusText: String {
        if task.isCompleted {
            return localization.text(.completedBadge)
        }

        return TaskDateFormatting.relativeDate(
            task.dueDate,
            locale: localization.locale
        )
    }

    private var statusColor: Color {
        let now = Date()
        if task.isCompleted {
            return palette.success
        }
        if task.dueDate < now {
            return palette.overdue
        }
        if task.dueDate.timeIntervalSince(now) < 24 * 60 * 60 {
            return palette.warning
        }
        return palette.accent
    }

    private var dueLine: String {
        "\(localization.text(.dueLabel)) \(TaskDateFormatting.dueDateTime(task.dueDate, locale: localization.locale))"
    }

    static func == (lhs: TaskRow, rhs: TaskRow) -> Bool {
        lhs.task == rhs.task && lhs.canModify == rhs.canModify
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onToggleComplete) {
                ZStack {
                    Circle()
                        .fill(
                            (task.isCompleted ? palette.success : (canModify ? palette.accent : palette.border))
                                .opacity(task.isCompleted ? 0.18 : 0.12)
                        )
                        .frame(width: 38, height: 38)

                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(task.isCompleted ? palette.success : (canModify ? palette.accent : palette.textSecondary))
                }
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
            .disabled(!canModify)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(task.title)
                            .font(.system(size: 17, weight: .semibold))
                            .strikethrough(task.isCompleted, color: .secondary)
                            .foregroundStyle(task.isCompleted ? .secondary : .primary)

                        if !task.notes.isEmpty {
                            Text(task.notes)
                                .font(.subheadline)
                                .foregroundStyle(palette.textSecondary)
                                .lineLimit(3)
                        }

                        if let groupName = task.groupName {
                            Label(groupName, systemImage: "person.3.fill")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(palette.accentDeep)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(palette.accentSoft)
                                )
                        }
                    }

                    Spacer(minLength: 8)
                }

                HStack(alignment: .center, spacing: 10) {
                    Label(dueLine, systemImage: "calendar.badge.clock")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(palette.textSecondary)

                    Spacer(minLength: 8)

                    Text(statusText)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(statusColor.opacity(task.isCompleted ? 0.14 : 0.12))
                        )
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(palette.surfaceMuted.opacity(0.92))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(palette.border.opacity(0.75), lineWidth: 1)
                )
            }
        }
        .canvasCard(padding: 16)
        .contentShape(Rectangle())
    }
}
