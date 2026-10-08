//
//  InkLocalization.swift
//  Ink
//
//  Created by Codex on 3/13/26.
//

import Combine
import Foundation
import SwiftUI

enum InkLanguage: String, CaseIterable, Identifiable, Sendable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english:
            return "English"
        case .simplifiedChinese:
            return "简体中文"
        }
    }

    var locale: Locale {
        Locale(identifier: rawValue)
    }
}

@MainActor
final class InkLocalization: ObservableObject {
    @Published private(set) var language: InkLanguage

    private let defaults: UserDefaults
    private let languageDefaultsKey = "ink.language"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let storedValue = defaults.string(forKey: languageDefaultsKey),
           let storedLanguage = InkLanguage(rawValue: storedValue) {
            language = storedLanguage
        } else {
            language = .english
        }
    }

    var locale: Locale {
        language.locale
    }

    var sidebarSubtitle: String {
        switch language {
        case .english:
            return "Private journals"
        case .simplifiedChinese:
            return "私人日志"
        }
    }

    var entriesLabel: String {
        switch language {
        case .english:
            return "Entries"
        case .simplifiedChinese:
            return "篇记录"
        }
    }

    var storageLabel: String {
        switch language {
        case .english:
            return "Storage"
        case .simplifiedChinese:
            return "存储"
        }
    }

    var localStorageTitle: String {
        switch language {
        case .english:
            return "Local"
        case .simplifiedChinese:
            return "本地"
        }
    }

    var privateJournalHeader: String {
        switch language {
        case .english:
            return "PRIVATE JOURNAL"
        case .simplifiedChinese:
            return "私人日志"
        }
    }

    var documentHeader: String {
        switch language {
        case .english:
            return "INK DOCUMENT"
        case .simplifiedChinese:
            return "INK 文稿"
        }
    }

    var savedLocally: String {
        switch language {
        case .english:
            return "Saved locally"
        case .simplifiedChinese:
            return "已保存在本地"
        }
    }

    var syncedWithICloud: String {
        switch language {
        case .english:
            return "Synced with iCloud"
        case .simplifiedChinese:
            return "已与 iCloud 同步"
        }
    }

    var editableDocument: String {
        switch language {
        case .english:
            return "Editable document"
        case .simplifiedChinese:
            return "可编辑文稿"
        }
    }

    var titlePlaceholder: String {
        switch language {
        case .english:
            return "Title"
        case .simplifiedChinese:
            return "标题"
        }
    }

    var bodyPlaceholder: String {
        switch language {
        case .english:
            return "Start writing..."
        case .simplifiedChinese:
            return "开始写点什么..."
        }
    }

    var newJournal: String {
        switch language {
        case .english:
            return "New Journal"
        case .simplifiedChinese:
            return "新建日志"
        }
    }

    var saveAs: String {
        switch language {
        case .english:
            return "Save As"
        case .simplifiedChinese:
            return "另存为"
        }
    }

    var screenshotMedia: String {
        switch language {
        case .english:
            return "Capture Screenshot"
        case .simplifiedChinese:
            return "截屏"
        }
    }

    var cameraMedia: String {
        switch language {
        case .english:
            return "Open Camera"
        case .simplifiedChinese:
            return "相机"
        }
    }

    var importMedia: String {
        switch language {
        case .english:
            return "Import Media"
        case .simplifiedChinese:
            return "导入"
        }
    }

    var importPhotos: String {
        switch language {
        case .english:
            return "Import Photos"
        case .simplifiedChinese:
            return "导入相片"
        }
    }

    var deleteJournal: String {
        switch language {
        case .english:
            return "Delete Journal"
        case .simplifiedChinese:
            return "删除日志"
        }
    }

    var emptyStateTitle: String {
        switch language {
        case .english:
            return "Create your next journal"
        case .simplifiedChinese:
            return "开始你的下一篇日志"
        }
    }

    var emptyStateMessage: String {
        switch language {
        case .english:
            return "A calm workspace for private writing, saved directly on your Mac."
        case .simplifiedChinese:
            return "一个安静的私人书写空间，内容直接保存在你的 Mac 上。"
        }
    }

    var untitled: String {
        switch language {
        case .english:
            return "Untitled"
        case .simplifiedChinese:
            return "未命名"
        }
    }

    var mediaSectionTitle: String {
        switch language {
        case .english:
            return "Media"
        case .simplifiedChinese:
            return "媒体"
        }
    }

    var importingMediaTitle: String {
        switch language {
        case .english:
            return "Importing media"
        case .simplifiedChinese:
            return "正在导入媒体"
        }
    }

    var importingMediaMessage: String {
        switch language {
        case .english:
            return "Large files are prepared in the background to keep Ink5 responsive."
        case .simplifiedChinese:
            return "较大的文件会在后台处理，这样 Ink5 会保持流畅。"
        }
    }

    var removeAttachment: String {
        switch language {
        case .english:
            return "Remove attachment"
        case .simplifiedChinese:
            return "移除附件"
        }
    }

    var imageLabel: String {
        switch language {
        case .english:
            return "Image"
        case .simplifiedChinese:
            return "图片"
        }
    }

    var videoLabel: String {
        switch language {
        case .english:
            return "Video"
        case .simplifiedChinese:
            return "视频"
        }
    }

    var dismissAction: String {
        switch language {
        case .english:
            return "OK"
        case .simplifiedChinese:
            return "好"
        }
    }

    var cancelAction: String {
        switch language {
        case .english:
            return "Cancel"
        case .simplifiedChinese:
            return "取消"
        }
    }

    var closeAction: String {
        switch language {
        case .english:
            return "Close"
        case .simplifiedChinese:
            return "关闭"
        }
    }

    var openSettingsAction: String {
        switch language {
        case .english:
            return "Open Settings"
        case .simplifiedChinese:
            return "打开设置"
        }
    }

    var captureMediaErrorTitle: String {
        switch language {
        case .english:
            return "Unable to Add Media"
        case .simplifiedChinese:
            return "无法添加媒体"
        }
    }

    var cameraPermissionTitle: String {
        switch language {
        case .english:
            return "Camera Access Needed"
        case .simplifiedChinese:
            return "需要相机权限"
        }
    }

    var cameraPermissionMessage: String {
        switch language {
        case .english:
            return "Allow Ink5 to use the camera so you can capture photos and videos in your journal."
        case .simplifiedChinese:
            return "请允许 Ink5 使用相机，这样你才能在日志里拍照和录制视频。"
        }
    }

    var cameraUnavailableTitle: String {
        switch language {
        case .english:
            return "Camera Unavailable"
        case .simplifiedChinese:
            return "相机不可用"
        }
    }

    var cameraUnavailableMessage: String {
        switch language {
        case .english:
            return "Ink5 couldn't start the front camera on this Mac."
        case .simplifiedChinese:
            return "Ink5 无法在这台 Mac 上启动前置摄像头。"
        }
    }

    var mobileCameraNotSupportedMessage: String {
        switch language {
        case .english:
            return "This iPhone doesn't have an available camera."
        case .simplifiedChinese:
            return "这部 iPhone 当前没有可用的相机。"
        }
    }

    var importMediaFailedMessage: String {
        switch language {
        case .english:
            return "Ink5 couldn't add this media to your journal. Please try again."
        case .simplifiedChinese:
            return "Ink5 无法把这段媒体加入日志，请再试一次。"
        }
    }

    var finalizingVideoTitle: String {
        switch language {
        case .english:
            return "Finishing video"
        case .simplifiedChinese:
            return "正在完成视频"
        }
    }

    var finalizingVideoMessage: String {
        switch language {
        case .english:
            return "Ink5 is saving your recording before it appears in the journal."
        case .simplifiedChinese:
            return "Ink5 正在保存录像，完成后它会出现在日志中。"
        }
    }

    var microphonePermissionTitle: String {
        switch language {
        case .english:
            return "Microphone Access Needed"
        case .simplifiedChinese:
            return "需要麦克风权限"
        }
    }

    var microphonePermissionMessage: String {
        switch language {
        case .english:
            return "Allow Ink5 to use the microphone so recorded journal videos include sound."
        case .simplifiedChinese:
            return "请允许 Ink5 使用麦克风，这样录制的日志视频才能带有声音。"
        }
    }

    var microphoneUnavailableTitle: String {
        switch language {
        case .english:
            return "Microphone Unavailable"
        case .simplifiedChinese:
            return "麦克风不可用"
        }
    }

    var microphoneUnavailableMessage: String {
        switch language {
        case .english:
            return "Ink5 couldn't connect to a microphone for video recording on this Mac."
        case .simplifiedChinese:
            return "Ink5 无法在这台 Mac 上连接可用于录像的麦克风。"
        }
    }

    var recordingFailedTitle: String {
        switch language {
        case .english:
            return "Unable to Save Video"
        case .simplifiedChinese:
            return "无法保存视频"
        }
    }

    var recordingFailedMessage: String {
        switch language {
        case .english:
            return "Ink5 couldn't finalize this recording. Please try again."
        case .simplifiedChinese:
            return "Ink5 无法完成这段录像，请再试一次。"
        }
    }

    var takePhoto: String {
        switch language {
        case .english:
            return "Photo"
        case .simplifiedChinese:
            return "拍照"
        }
    }

    var recordVideo: String {
        switch language {
        case .english:
            return "Video"
        case .simplifiedChinese:
            return "录像"
        }
    }

    var stopRecording: String {
        switch language {
        case .english:
            return "Stop"
        case .simplifiedChinese:
            return "停止"
        }
    }

    var cameraLiveLabel: String {
        switch language {
        case .english:
            return "Front Camera"
        case .simplifiedChinese:
            return "前置摄像头"
        }
    }

    var languageMenuHelp: String {
        switch language {
        case .english:
            return "Language"
        case .simplifiedChinese:
            return "语言"
        }
    }

    var libraryWindowTitle: String {
        switch language {
        case .english:
            return "Library"
        case .simplifiedChinese:
            return "资料库"
        }
    }

    func setLanguage(_ language: InkLanguage) {
        guard self.language != language else {
            return
        }

        self.language = language
        defaults.set(language.rawValue, forKey: languageDefaultsKey)
    }

    func entryTitle(for entry: JournalEntry) -> String {
        let trimmed = entry.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? untitled : trimmed
    }

    func previewText(for entry: JournalEntry) -> String {
        let trimmed = entry.body.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }

        if entry.attachmentCount > 0 {
            return attachmentCountText(entry.attachmentCount)
        }

        return bodyPlaceholder
    }

    func wordCountText(_ count: Int) -> String {
        switch language {
        case .english:
            return count == 1 ? "1 word" : "\(count) words"
        case .simplifiedChinese:
            return "\(count) 字词"
        }
    }

    func attachmentCountText(_ count: Int) -> String {
        switch language {
        case .english:
            return count == 1 ? "1 attachment" : "\(count) attachments"
        case .simplifiedChinese:
            return "\(count) 个附件"
        }
    }

    func attachmentKindLabel(_ kind: JournalAttachmentKind) -> String {
        switch kind {
        case .image:
            return imageLabel
        case .video:
            return videoLabel
        }
    }

    func editorDate(_ date: Date) -> String {
        localizedDate(date, dateStyle: .full, timeStyle: .short)
    }

    func sidebarDate(_ date: Date) -> String {
        localizedDate(date, dateStyle: .medium, timeStyle: .short)
    }

    private func localizedDate(
        _ date: Date,
        dateStyle: DateFormatter.Style,
        timeStyle: DateFormatter.Style
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        formatter.doesRelativeDateFormatting = false
        return formatter.string(from: date)
    }
}
