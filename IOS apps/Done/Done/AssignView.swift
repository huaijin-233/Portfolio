//
//  AssignView.swift
//  Done
//
//  Created by Codex on 3/11/26.
//

import SwiftUI

struct AssignView: View {
    private enum Field: Hashable {
        case title
        case notes
    }

    @EnvironmentObject private var localization: LocalizationStore
    @EnvironmentObject private var themeStore: ThemeStore
    @ObservedObject var store: TaskStore
    @ObservedObject var groupStore: GroupStore

    @State private var title = ""
    @State private var notes = ""
    @State private var dueDate = Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date()
    @State private var selectedGroup: TaskGroup?
    @State private var isSubmitting = false
    @State private var errorText: String?
    @State private var openedTaskRowID: String?
    @FocusState private var focusedField: Field?

    private var activeCount: Int {
        store.incompleteTasksSorted.count
    }

    private var dueTodayCount: Int {
        store.incompleteTasksSorted.filter { Calendar.current.isDateInToday($0.dueDate) }.count
    }

    private var recentTasks: [Assignment] {
        Array(store.incompleteTasksSorted.prefix(6))
    }

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSubmitting
    }

    private var palette: ThemePalette {
        themeStore.theme.palette
    }

    var body: some View {
        ZStack {
            ThemedScreenBackground()
                .contentShape(Rectangle())
                .onTapGesture {
                    focusedField = nil
                }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    heroCard
                    composerCard
                    recentAssignmentsSection
                }
                .padding(20)
                .padding(.bottom, 28)
            }
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(
                TapGesture().onEnded {
                    focusedField = nil
                }
            )
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
            Text(localization.text(.assignTitle))
                .font(.system(size: 30, weight: .bold, design: .serif))
                .foregroundStyle(.white)

            HStack(spacing: 14) {
                MetricBadge(title: localization.text(.activeTasks), value: "\(activeCount)")
                MetricBadge(title: localization.text(.dueToday), value: "\(dueTodayCount)")
            }
        }
        .heroCard()
    }

    private var composerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: localization.text(.newAssignment)) {
                if !groupStore.groups.isEmpty {
                    groupPicker
                }
            }

            Group {
                TextField(localization.text(.titleField), text: $title)
                    .textInputAutocapitalization(.sentences)
                    .focused($focusedField, equals: .title)
                    .premiumField()

                TextField(localization.text(.notesField), text: $notes, axis: .vertical)
                    .lineLimit(3...5)
                    .focused($focusedField, equals: .notes)
                    .premiumField()

                HStack {
                    Text(localization.text(.dueDateField))
                        .font(.subheadline.weight(.semibold))

                    Spacer()

                    DatePicker(
                        localization.text(.dueDateField),
                        selection: $dueDate,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(palette.accent)
                }
                .premiumField()
            }

            if let selectedGroup {
                Label(
                    "\(localization.text(.selectedGroupPrefix)) \(selectedGroup.name)",
                    systemImage: "person.3.fill"
                )
                .font(.caption.weight(.medium))
                .foregroundStyle(palette.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(palette.accentSoft.opacity(0.75))
                )
            }

            if let errorText {
                Text(errorText)
                    .font(.subheadline)
                    .foregroundStyle(palette.overdue)
            }

            Button {
                Task {
                    await assignTask()
                }
            } label: {
                HStack {
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                    }

                    Text(localization.text(.assignButton))
                        .font(.headline)
                }
                .primaryActionButton(isEnabled: canSubmit)
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit)
        }
        .canvasCard(padding: 20)
    }

    private var recentAssignmentsSection: some View {
        LazyVStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: localization.text(.recentAssignments)) {
                Text("\(recentTasks.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.accentDeep)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(palette.accentSoft)
                    )
            }

            if recentTasks.isEmpty {
                Text(localization.text(.noAssignments))
                    .foregroundStyle(palette.textSecondary)
                    .canvasCard()
            } else {
                ForEach(recentTasks) { task in
                    taskCard(for: task)
                }
            }
        }
    }

    private var groupPicker: some View {
        Menu {
            Button {
                selectedGroup = nil
            } label: {
                if selectedGroup == nil {
                    Label(localization.text(.personalAssignment), systemImage: "checkmark")
                } else {
                    Text(localization.text(.personalAssignment))
                }
            }

            ForEach(groupStore.groups) { group in
                Button {
                    selectedGroup = group
                } label: {
                    if selectedGroup == group {
                        Label(group.name, systemImage: "checkmark")
                    } else {
                        Text(group.name)
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: selectedGroup == nil ? "person.fill" : "person.3.fill")
                Text(selectedGroup?.name ?? localization.text(.selectGroup))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(palette.accentDeep)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(palette.accentSoft)
            )
            .overlay(
                Capsule()
                    .stroke(palette.border, lineWidth: 1)
            )
        }
    }

    private func assignTask() async {
        focusedField = nil
        errorText = nil
        guard !isSubmitting else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await store.addTask(title: title, notes: notes, dueDate: dueDate, group: selectedGroup)
            title = ""
            notes = ""
            dueDate = Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date()
        } catch let error as TaskStoreError {
            switch error {
            case .cloudUnavailable:
                errorText = localization.text(.cloudKitUnavailable)
            case .saveFailed:
                errorText = localization.text(.groupTaskSaveFailed)
            }
        } catch {
            errorText = localization.text(.groupTaskSaveFailed)
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
