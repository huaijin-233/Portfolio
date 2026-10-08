//
//  LocalizationStore.swift
//  Done
//
//  Created by Codex on 3/11/26.
//

import Combine
import Foundation

enum LocalizedKey: String {
    case authTitle
    case authSubtitle
    case signInTab
    case signUpTab
    case usernameField
    case passwordField
    case emailField
    case verificationCodeField
    case sendCode
    case sendCodeSent
    case signInButton
    case signUpButton
    case continueAsGuest
    case completeAppleAccountButton
    case continueWithApple
    case authChecking
    case registrationReady
    case authInvalidCredentials
    case authEmailProviderUnavailable
    case authConfigurationMissing
    case authRequestFailed
    case authAppleCredentialMissing
    case authAppleFailed
    case authAppleRegistrationFirst
    case authAppleCallbackMissing
    case authAppleStateInvalid
    case appleRegistrationPrompt
    case appleRegistrationReady
    case orContinueWithPassword
    case assignTab
    case todoTab
    case calendarTab
    case groupTab
    case assignTitle
    case activeTasks
    case dueToday
    case newAssignment
    case titleField
    case notesField
    case dueDateField
    case assignButton
    case recentAssignments
    case noAssignments
    case todoTitle
    case todoSubtitle
    case workloadOverview
    case overdue
    case today
    case nextSevenDays
    case completed
    case noUpcomingTasks
    case noUpcomingTasksBody
    case calendarTitle
    case calendarSubtitle
    case tasksThisMonth
    case selectedDay
    case tasksOnDate
    case noTasksOnDate
    case language
    case theme
    case completedBadge
    case dueLabel
    case notesLabel
    case delete
    case dueSoon
    case allCaughtUp
    case signOut
    case groupTitle
    case groupSubtitle
    case yourGroups
    case createdGroups
    case groupActions
    case createGroup
    case joinGroup
    case groupNameField
    case groupDescriptionField
    case createGroupButton
    case joinGroupButton
    case groupInviteCode
    case memberNameField
    case inviteCodeField
    case noGroups
    case noGroupsBody
    case ownerBadge
    case joinedBadge
    case tapToViewInviteCode
    case copyCode
    case copied
    case groupDetailTitle
    case close
    case personalAssignment
    case selectGroup
    case selectedGroupPrefix
    case viewInviteCode
    case groupNameMissing
    case memberNameMissing
    case inviteCodeMissing
    case invalidInviteCode
    case cloudKitUnavailable
    case groupsLoadFailed
    case groupCreateFailed
    case groupJoinFailed
    case groupTaskSaveFailed
    case groupDeleteFailed
    case membersLabel
    case noMembersYet
}

@MainActor
final class LocalizationStore: ObservableObject {
    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: storageKey)
        }
    }

    private let storageKey = "done.language.v1"

    init() {
        let savedValue = UserDefaults.standard.string(forKey: storageKey)
        language = AppLanguage(rawValue: savedValue ?? "") ?? .english
    }

    var locale: Locale {
        language.locale
    }

    func text(_ key: LocalizedKey) -> String {
        translations[language]?[key] ?? translations[.english]?[key] ?? key.rawValue
    }

    func label(for language: AppLanguage) -> String {
        language.displayName
    }

    private let translations: [AppLanguage: [LocalizedKey: String]] = [
        .english: [
            .authTitle: "Welcome Back",
            .authSubtitle: "Use Apple to create your account, then sign in with Apple or your password.",
            .signInTab: "Sign In",
            .signUpTab: "Register",
            .usernameField: "Username",
            .passwordField: "Password",
            .emailField: "Email",
            .verificationCodeField: "Verification Code",
            .sendCode: "Send Code",
            .sendCodeSent: "Code Sent",
            .signInButton: "Log In",
            .signUpButton: "Create Account",
            .continueAsGuest: "Continue as Guest",
            .completeAppleAccountButton: "Finish Account Setup",
            .continueWithApple: "Continue with Apple",
            .authChecking: "Checking session...",
            .registrationReady: "Verification code sent. Finish the form to create your account.",
            .authInvalidCredentials: "The username or password is incorrect.",
            .authEmailProviderUnavailable: "Email verification is not enabled in the current CloudBase environment yet.",
            .authConfigurationMissing: "CloudBase configuration is missing from the app bundle.",
            .authRequestFailed: "The request could not be completed right now. Please try again.",
            .authAppleCredentialMissing: "Apple did not return a valid authorization code.",
            .authAppleFailed: "Apple sign in could not be completed right now.",
            .authAppleRegistrationFirst: "Start with Apple in the Register tab before setting a password.",
            .authAppleCallbackMissing: "Apple authorization finished, but no usable code was returned.",
            .authAppleStateInvalid: "Apple authorization could not be verified. Please try again.",
            .appleRegistrationPrompt: "Use Apple first. After authorization, set a username and password for future logins.",
            .appleRegistrationReady: "Apple is verified. Set your username and password to complete the account.",
            .orContinueWithPassword: "Or continue with your password",
            .assignTab: "Assign",
            .todoTab: "To Do",
            .calendarTab: "Calendar",
            .groupTab: "Groups",
            .assignTitle: "Assignments",
            .activeTasks: "Active Tasks",
            .dueToday: "Due Today",
            .newAssignment: "New Assignment",
            .titleField: "Title",
            .notesField: "Notes (optional)",
            .dueDateField: "Due Date",
            .assignButton: "Assign",
            .recentAssignments: "Recent Assignments",
            .noAssignments: "No assignments yet.",
            .todoTitle: "To Do",
            .todoSubtitle: "The next seven days, sorted by urgency.",
            .workloadOverview: "Workload Overview",
            .overdue: "Overdue",
            .today: "Today",
            .nextSevenDays: "Next 7 Days",
            .completed: "Completed",
            .noUpcomingTasks: "No tasks in the next 7 days",
            .noUpcomingTasksBody: "Create an assignment to start building your timeline.",
            .calendarTitle: "Calendar",
            .calendarSubtitle: "See your workload on the calendar before it stacks up.",
            .tasksThisMonth: "Tasks This Month",
            .selectedDay: "Selected Day",
            .tasksOnDate: "Tasks on %@",
            .noTasksOnDate: "No tasks on this date.",
            .language: "Language",
            .theme: "Theme",
            .completedBadge: "Completed",
            .dueLabel: "Due",
            .notesLabel: "Notes",
            .delete: "Delete",
            .dueSoon: "Due Soon",
            .allCaughtUp: "All caught up",
            .signOut: "Sign Out",
            .groupTitle: "Groups",
            .groupSubtitle: "Create a shared space, keep the invite code, and assign work to the whole group.",
            .yourGroups: "Your Groups",
            .createdGroups: "Created",
            .groupActions: "Group Actions",
            .createGroup: "Create Group",
            .joinGroup: "Join Group",
            .groupNameField: "Group Name",
            .groupDescriptionField: "Description",
            .createGroupButton: "Create Group",
            .joinGroupButton: "Join with Code",
            .groupInviteCode: "Invite Code",
            .memberNameField: "Your Name",
            .inviteCodeField: "Invite Code",
            .noGroups: "No groups yet",
            .noGroupsBody: "Create a group or join one with an invite code.",
            .ownerBadge: "Owner",
            .joinedBadge: "Joined",
            .tapToViewInviteCode: "Tap to view invite code",
            .copyCode: "Copy",
            .copied: "Copied",
            .groupDetailTitle: "Group",
            .close: "Close",
            .personalAssignment: "Personal",
            .selectGroup: "Group",
            .selectedGroupPrefix: "Selected group:",
            .viewInviteCode: "View Code",
            .groupNameMissing: "Enter a group name first.",
            .memberNameMissing: "Enter your name first.",
            .inviteCodeMissing: "Enter an invite code first.",
            .invalidInviteCode: "That invite code does not match any group.",
            .cloudKitUnavailable: "CloudKit is not available right now. Check your Apple ID and iCloud settings.",
            .groupsLoadFailed: "Groups could not be loaded right now.",
            .groupCreateFailed: "The group could not be created right now.",
            .groupJoinFailed: "The group could not be joined right now.",
            .groupTaskSaveFailed: "The group assignment could not be saved right now.",
            .groupDeleteFailed: "The group could not be deleted right now.",
            .membersLabel: "People",
            .noMembersYet: "No members yet."
        ],
        .simplifiedChinese: [
            .authTitle: "开始使用",
            .authSubtitle: "先用 Apple 完成注册，之后可以直接用 Apple 或用户名密码登录。",
            .signInTab: "登录",
            .signUpTab: "注册",
            .usernameField: "用户名",
            .passwordField: "密码",
            .emailField: "邮箱",
            .verificationCodeField: "验证码",
            .sendCode: "发送验证码",
            .sendCodeSent: "已发送",
            .signInButton: "登录",
            .signUpButton: "创建账号",
            .continueAsGuest: "匿名进入",
            .completeAppleAccountButton: "完成账号设置",
            .continueWithApple: "使用 Apple 继续",
            .authChecking: "正在恢复登录状态...",
            .registrationReady: "验证码已发送，填完剩余信息后即可完成注册。",
            .authInvalidCredentials: "用户名或密码不正确。",
            .authEmailProviderUnavailable: "当前 CloudBase 环境还没有开启邮箱验证码能力。",
            .authConfigurationMissing: "App 内缺少 CloudBase 配置。",
            .authRequestFailed: "当前请求暂时无法完成，请稍后再试。",
            .authAppleCredentialMissing: "Apple 没有返回可用的授权码。",
            .authAppleFailed: "Apple 登录暂时无法完成。",
            .authAppleRegistrationFirst: "请先在注册页通过 Apple 开始创建账号。",
            .authAppleCallbackMissing: "Apple 授权已完成，但没有返回可用的登录凭据。",
            .authAppleStateInvalid: "Apple 授权校验失败，请重新尝试。",
            .appleRegistrationPrompt: "先用 Apple 完成身份认证，再设置用户名和密码，之后两种方式都能登录。",
            .appleRegistrationReady: "Apple 已验证完成，继续设置用户名和密码即可完成账号创建。",
            .orContinueWithPassword: "或者继续使用用户名密码",
            .assignTab: "布置",
            .todoTab: "待办",
            .calendarTab: "日历",
            .groupTab: "群组",
            .assignTitle: "任务布置",
            .activeTasks: "进行中",
            .dueToday: "今日到期",
            .newAssignment: "新任务",
            .titleField: "标题",
            .notesField: "备注（可选）",
            .dueDateField: "截止时间",
            .assignButton: "布置任务",
            .recentAssignments: "最近任务",
            .noAssignments: "还没有任务。",
            .todoTitle: "待办",
            .todoSubtitle: "未来七天内最该做的事。",
            .workloadOverview: "任务概览",
            .overdue: "已逾期",
            .today: "今天",
            .nextSevenDays: "未来 7 天",
            .completed: "已完成",
            .noUpcomingTasks: "未来 7 天没有任务",
            .noUpcomingTasksBody: "先创建一个有截止时间的任务。",
            .calendarTitle: "日历",
            .calendarSubtitle: "在任务堆积之前，先看到它们分布在哪些日期。",
            .tasksThisMonth: "本月任务",
            .selectedDay: "选中日期",
            .tasksOnDate: "%@ 的任务",
            .noTasksOnDate: "这一天没有任务。",
            .language: "语言",
            .theme: "主题",
            .completedBadge: "已完成",
            .dueLabel: "截止",
            .notesLabel: "备注",
            .delete: "删除",
            .dueSoon: "即将到期",
            .allCaughtUp: "当前都处理完了",
            .signOut: "退出登录",
            .groupTitle: "群组",
            .groupSubtitle: "创建共享群组，保存邀请码，然后把任务布置给整个群组。",
            .yourGroups: "你的群组",
            .createdGroups: "已创建",
            .groupActions: "群组操作",
            .createGroup: "创建群组",
            .joinGroup: "加入群组",
            .groupNameField: "群组名称",
            .groupDescriptionField: "群组介绍",
            .createGroupButton: "创建群组",
            .joinGroupButton: "输入邀请码加入",
            .groupInviteCode: "邀请码",
            .memberNameField: "你的名字",
            .inviteCodeField: "输入邀请码",
            .noGroups: "还没有群组",
            .noGroupsBody: "你可以创建一个群组，或者输入邀请码加入现有群组。",
            .ownerBadge: "创建者",
            .joinedBadge: "已加入",
            .tapToViewInviteCode: "点击查看邀请码",
            .copyCode: "复制",
            .copied: "已复制",
            .groupDetailTitle: "群组详情",
            .close: "关闭",
            .personalAssignment: "个人",
            .selectGroup: "群组",
            .selectedGroupPrefix: "已选群组：",
            .viewInviteCode: "查看邀请码",
            .groupNameMissing: "请先输入群组名称。",
            .memberNameMissing: "请先输入你的名字。",
            .inviteCodeMissing: "请先输入邀请码。",
            .invalidInviteCode: "这个邀请码没有对应的群组。",
            .cloudKitUnavailable: "CloudKit 当前不可用，请检查 Apple ID 和 iCloud 设置。",
            .groupsLoadFailed: "当前无法加载群组。",
            .groupCreateFailed: "当前无法创建群组。",
            .groupJoinFailed: "当前无法加入群组。",
            .groupTaskSaveFailed: "当前无法保存群组任务。",
            .groupDeleteFailed: "当前无法删除群组。",
            .membersLabel: "成员",
            .noMembersYet: "当前还没有成员。"
        ]
    ]
}
