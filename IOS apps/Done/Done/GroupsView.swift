//
//  GroupsView.swift
//  Done
//
//  Created by Codex on 3/12/26.
//

import SwiftUI
import UIKit

struct GroupsView: View {
    @EnvironmentObject private var localization: LocalizationStore
    @EnvironmentObject private var themeStore: ThemeStore
    @ObservedObject var groupStore: GroupStore

    @State private var showingCreateSheet = false
    @State private var showingJoinSheet = false
    @State private var selectedGroup: TaskGroup?
    @State private var membersGroup: TaskGroup?
    @State private var copiedCode: String?
    @State private var operationMessage: String?
    @State private var openedGroupRowID: String?

    private var palette: ThemePalette {
        themeStore.theme.palette
    }

    var body: some View {
        ZStack {
            ThemedScreenBackground()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    heroCard
                    actionsCard
                    if let operationMessage {
                        infoCard(message: operationMessage)
                    }
                    if let error = groupStore.loadError {
                        infoCard(message: message(for: error))
                    }
                    groupListSection
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
        .sheet(isPresented: $showingCreateSheet) {
            GroupCreateSheet(groupStore: groupStore) { createdGroup in
                selectedGroup = createdGroup
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingJoinSheet) {
            GroupJoinSheet(groupStore: groupStore)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $membersGroup) { group in
            GroupMembersSheet(group: group, groupStore: groupStore)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedGroup) { group in
            GroupDetailSheet(group: group, copiedCode: copiedCode) { code in
                UIPasteboard.general.string = code
                copiedCode = code
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .task {
            await groupStore.refreshIfNeeded()
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(localization.text(.groupTitle))
                .font(.system(size: 30, weight: .bold, design: .serif))
                .foregroundStyle(.white)

            Text(localization.text(.groupSubtitle))
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.88))

            HStack(spacing: 14) {
                MetricBadge(title: localization.text(.yourGroups), value: "\(groupStore.groups.count)")
                MetricBadge(
                    title: localization.text(.createdGroups),
                    value: "\(groupStore.groups.filter(\.isOwnedByCurrentUser).count)"
                )
            }
        }
        .heroCard()
    }

    private var actionsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: localization.text(.groupActions))

            HStack(spacing: 12) {
                Button {
                    showingCreateSheet = true
                } label: {
                    actionButtonLabel(
                        title: localization.text(.createGroup),
                        systemImage: "plus.circle.fill"
                    )
                }
                .buttonStyle(.plain)

                Button {
                    showingJoinSheet = true
                } label: {
                    actionButtonLabel(
                        title: localization.text(.joinGroup),
                        systemImage: "person.badge.plus.fill"
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .canvasCard()
    }

    private var groupListSection: some View {
        LazyVStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: localization.text(.yourGroups)) {
                Text("\(groupStore.groups.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.accentDeep)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(palette.accentSoft)
                    )
            }

            if groupStore.groups.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(localization.text(.noGroups))
                        .font(.headline)

                    Text(localization.text(.noGroupsBody))
                        .font(.subheadline)
                        .foregroundStyle(palette.textSecondary)
                }
                .canvasCard()
            } else {
                ForEach(groupStore.groups) { group in
                    SwipeDeleteRow(rowID: group.id, openedRowID: $openedGroupRowID, isEnabled: true) {
                        Task {
                            await deleteGroup(group)
                        }
                    } content: {
                        groupCard(for: group)
                    }
                }
            }
        }
    }

    private func groupCard(for group: TaskGroup) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [palette.accentSoft, palette.surface],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 46, height: 46)

                    Image(systemName: group.isOwnedByCurrentUser ? "person.3.sequence.fill" : "person.2.wave.2.fill")
                        .font(.headline)
                        .foregroundStyle(group.isOwnedByCurrentUser ? palette.accentDeep : palette.warning)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(group.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)

                    if !group.details.isEmpty {
                        Text(group.details)
                            .font(.subheadline)
                            .foregroundStyle(palette.textSecondary)
                            .lineLimit(3)
                    }
                }

                Spacer(minLength: 8)

                Text(group.isOwnedByCurrentUser ? localization.text(.ownerBadge) : localization.text(.joinedBadge))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(group.isOwnedByCurrentUser ? palette.accentDeep : palette.warning)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill((group.isOwnedByCurrentUser ? palette.accentSoft : palette.warning.opacity(0.12)))
                    )
            }

            HStack(spacing: 10) {
                Label(memberCountText(for: group), systemImage: "person.2.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(palette.textSecondary)

                Spacer()

                Button {
                    membersGroup = group
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "person.2.circle.fill")
                        Text(localization.text(.membersLabel))
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.accentDeep)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(palette.accentSoft)
                    )
                    .overlay(
                        Capsule()
                            .stroke(palette.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                Label(localization.text(.groupInviteCode), systemImage: "ticket.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(palette.textSecondary)

                Spacer()

                Button {
                    selectedGroup = group
                } label: {
                    HStack(spacing: 6) {
                        Text(localization.text(.viewInviteCode))
                        Image(systemName: "chevron.right")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.accentDeep)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(palette.accentSoft)
                    )
                    .overlay(
                        Capsule()
                            .stroke(palette.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .canvasCard(padding: 16)
    }

    private func memberCountText(for group: TaskGroup) -> String {
        let count = groupStore.memberCount(for: group)
        switch localization.language {
        case .english:
            return count == 1 ? "1 person" : "\(count) people"
        case .simplifiedChinese:
            return "\(count)人"
        }
    }

    private func actionButtonLabel(title: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.16))
                    .frame(width: 40, height: 40)

                Image(systemName: systemImage)
                    .font(.headline)
            }

            Text(title)
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 120, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [palette.accent, palette.accentDeep],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    private func infoCard(message: String) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(palette.textSecondary)
            .canvasCard()
    }

    private func message(for error: GroupStoreError) -> String {
        switch error {
        case .missingName:
            return localization.text(.groupNameMissing)
        case .missingMemberName:
            return localization.text(.memberNameMissing)
        case .missingInviteCode:
            return localization.text(.inviteCodeMissing)
        case .invalidInviteCode:
            return localization.text(.invalidInviteCode)
        case .accountUnavailable:
            return localization.text(.cloudKitUnavailable)
        case .deleteFailed:
            return localization.text(.groupDeleteFailed)
        case .operationFailed:
            return localization.text(.groupsLoadFailed)
        }
    }

    private func deleteGroup(_ group: TaskGroup) async {
        do {
            selectedGroup = nil
            operationMessage = nil
            try await groupStore.deleteGroup(group)
        } catch let error as GroupStoreError {
            operationMessage = message(for: error)
        } catch {
            operationMessage = localization.text(.groupDeleteFailed)
        }
    }
}

private struct GroupCreateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localization: LocalizationStore
    @EnvironmentObject private var themeStore: ThemeStore
    @ObservedObject var groupStore: GroupStore

    @State private var memberName = ""
    @State private var name = ""
    @State private var details = ""
    @State private var isSubmitting = false
    @State private var errorText: String?

    let onCreated: (TaskGroup) -> Void

    private var palette: ThemePalette {
        themeStore.theme.palette
    }

    private var canSubmit: Bool {
        !memberName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isSubmitting
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ThemedScreenBackground()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: localization.text(.createGroup))

                        TextField(localization.text(.memberNameField), text: $memberName)
                            .textInputAutocapitalization(.words)
                            .premiumField()

                        TextField(localization.text(.groupNameField), text: $name)
                            .premiumField()

                        TextField(localization.text(.groupDescriptionField), text: $details, axis: .vertical)
                            .lineLimit(3...5)
                            .premiumField()

                        if let errorText {
                            Text(errorText)
                                .font(.subheadline)
                                .foregroundStyle(palette.overdue)
                        }

                        Button {
                            Task {
                                await createGroup()
                            }
                        } label: {
                            HStack {
                                if isSubmitting {
                                    ProgressView()
                                        .tint(.white)
                                }

                                Text(localization.text(.createGroupButton))
                                    .font(.headline)
                            }
                            .primaryActionButton(isEnabled: canSubmit)
                        }
                        .buttonStyle(.plain)
                        .disabled(!canSubmit)
                    }
                    .canvasCard(padding: 20)
                    .padding(20)
                }
            }
            .navigationTitle(localization.text(.createGroup))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(localization.text(.close)) {
                        dismiss()
                    }
                }
            }
        }
    }

    private func createGroup() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorText = nil
        defer { isSubmitting = false }

        do {
            let group = try await groupStore.createGroup(
                name: name,
                details: details,
                ownerDisplayName: memberName
            )
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onCreated(group)
            }
        } catch let error as GroupStoreError {
            errorText = message(for: error)
        } catch {
            errorText = localization.text(.groupCreateFailed)
        }
    }

    private func message(for error: GroupStoreError) -> String {
        switch error {
        case .missingName:
            return localization.text(.groupNameMissing)
        case .missingMemberName:
            return localization.text(.memberNameMissing)
        case .missingInviteCode:
            return localization.text(.inviteCodeMissing)
        case .invalidInviteCode:
            return localization.text(.invalidInviteCode)
        case .accountUnavailable:
            return localization.text(.cloudKitUnavailable)
        case .deleteFailed:
            return localization.text(.groupCreateFailed)
        case .operationFailed:
            return localization.text(.groupCreateFailed)
        }
    }
}

private struct GroupJoinSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localization: LocalizationStore
    @EnvironmentObject private var themeStore: ThemeStore
    @ObservedObject var groupStore: GroupStore

    @State private var memberName = ""
    @State private var inviteCode = ""
    @State private var isSubmitting = false
    @State private var errorText: String?

    private var palette: ThemePalette {
        themeStore.theme.palette
    }

    private var canSubmit: Bool {
        !memberName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isSubmitting
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ThemedScreenBackground()

                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(title: localization.text(.joinGroup))

                    TextField(localization.text(.memberNameField), text: $memberName)
                        .textInputAutocapitalization(.words)
                        .premiumField()

                    TextField(localization.text(.inviteCodeField), text: $inviteCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .premiumField()

                    if let errorText {
                        Text(errorText)
                            .font(.subheadline)
                            .foregroundStyle(palette.overdue)
                    }

                    Button {
                        Task {
                            await joinGroup()
                        }
                    } label: {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            }

                            Text(localization.text(.joinGroupButton))
                                .font(.headline)
                        }
                        .primaryActionButton(isEnabled: canSubmit)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSubmit)

                    Spacer(minLength: 0)
                }
                .canvasCard(padding: 20)
                .padding(20)
            }
            .navigationTitle(localization.text(.joinGroup))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(localization.text(.close)) {
                        dismiss()
                    }
                }
            }
        }
    }

    private func joinGroup() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorText = nil
        defer { isSubmitting = false }

        do {
            _ = try await groupStore.joinGroup(inviteCode: inviteCode, displayName: memberName)
            dismiss()
        } catch let error as GroupStoreError {
            errorText = message(for: error)
        } catch {
            errorText = localization.text(.groupJoinFailed)
        }
    }

    private func message(for error: GroupStoreError) -> String {
        switch error {
        case .missingName:
            return localization.text(.groupNameMissing)
        case .missingMemberName:
            return localization.text(.memberNameMissing)
        case .missingInviteCode:
            return localization.text(.inviteCodeMissing)
        case .invalidInviteCode:
            return localization.text(.invalidInviteCode)
        case .accountUnavailable:
            return localization.text(.cloudKitUnavailable)
        case .deleteFailed:
            return localization.text(.groupJoinFailed)
        case .operationFailed:
            return localization.text(.groupJoinFailed)
        }
    }
}

private struct GroupDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localization: LocalizationStore
    @EnvironmentObject private var themeStore: ThemeStore

    let group: TaskGroup
    let copiedCode: String?
    let onCopy: (String) -> Void

    private var palette: ThemePalette {
        themeStore.theme.palette
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ThemedScreenBackground()

                VStack(alignment: .leading, spacing: 18) {
                    SectionHeader(title: group.name) {
                        Text(group.isOwnedByCurrentUser ? localization.text(.ownerBadge) : localization.text(.joinedBadge))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(group.isOwnedByCurrentUser ? palette.accentDeep : palette.warning)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(group.isOwnedByCurrentUser ? palette.accentSoft : palette.warning.opacity(0.14))
                            )
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        if !group.details.isEmpty {
                            Text(group.details)
                                .font(.subheadline)
                                .foregroundStyle(palette.textSecondary)
                        }

                        Text(localization.text(.groupInviteCode))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.textSecondary)

                        HStack {
                            Text(group.inviteCode)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(palette.accentDeep)

                            Spacer()

                            Button {
                                onCopy(group.inviteCode)
                            } label: {
                                Text(copiedCode == group.inviteCode ? localization.text(.copied) : localization.text(.copyCode))
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(
                                        Capsule()
                                            .fill(palette.accentSoft)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .canvasCard()

                    Spacer(minLength: 0)
                }
                .canvasCard(padding: 20)
                .padding(20)
            }
            .navigationTitle(localization.text(.groupDetailTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(localization.text(.close)) {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct GroupMembersSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localization: LocalizationStore
    @EnvironmentObject private var themeStore: ThemeStore

    let group: TaskGroup
    @ObservedObject var groupStore: GroupStore

    private var palette: ThemePalette {
        themeStore.theme.palette
    }

    private var members: [GroupMember] {
        groupStore.members(for: group)
    }

    private var countText: String {
        let count = members.count
        switch localization.language {
        case .english:
            return count == 1 ? "1 person" : "\(count) people"
        case .simplifiedChinese:
            return "\(count)人"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ThemedScreenBackground()

                VStack(alignment: .leading, spacing: 18) {
                    SectionHeader(title: group.name, subtitle: countText)

                    if members.isEmpty {
                        Text(localization.text(.noMembersYet))
                            .font(.subheadline)
                            .foregroundStyle(palette.textSecondary)
                            .canvasCard()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(members) { member in
                                    HStack(spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(palette.accentSoft)
                                                .frame(width: 42, height: 42)

                                            Text(String(member.displayName.prefix(1)).uppercased())
                                                .font(.headline.weight(.bold))
                                                .foregroundStyle(palette.accentDeep)
                                        }

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(member.displayName)
                                                .font(.system(size: 17, weight: .semibold))

                                            Text(member.isOwner ? localization.text(.ownerBadge) : localization.text(.joinedBadge))
                                                .font(.caption.weight(.medium))
                                                .foregroundStyle(palette.textSecondary)
                                        }

                                        Spacer()

                                        if member.isOwner {
                                            Text(localization.text(.ownerBadge))
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
                                    .canvasCard(padding: 14)
                                }
                            }
                        }
                    }
                }
                .canvasCard(padding: 20)
                .padding(20)
            }
            .navigationTitle(localization.text(.membersLabel))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(localization.text(.close)) {
                        dismiss()
                    }
                }
            }
        }
    }
}
