//
//  lang.swift
//  newhuaixin
//
//  Created by Huaijin233 on 3/8/26.
//

import Foundation
import SwiftUI
import Combine

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case japanese = "ja"
    case traditionalChinese = "zh-Hans"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .english:
            return "English"
        case .japanese:
            return "日本語"
        case .traditionalChinese:
            return "简体中文"
        }
    }

    var aiLanguageName: String {
        switch self {
        case .english:
            return "English"
        case .japanese:
            return "Japanese"
        case .traditionalChinese:
            return "Simplified Chinese"
        }
    }

    var aiResponseInstruction: String {
        switch self {
        case .english:
            return "Respond naturally in English."
        case .japanese:
            return "Respond naturally in Japanese."
        case .traditionalChinese:
            return "Respond naturally in Simplified Chinese."
        }
    }

    var localeIdentifier: String {
        switch self {
        case .english:
            return "en_US"
        case .japanese:
            return "ja_JP"
        case .traditionalChinese:
            return "zh_Hans_CN"
        }
    }
}

final class LangManager: ObservableObject {
    static let shared = LangManager()

    private let defaults = UserDefaults.standard
    private let key = "app_language"

    @Published var current: AppLanguage {
        didSet {
            defaults.set(current.rawValue, forKey: key)
        }
    }

    private init() {
        let stored = defaults.string(forKey: key)
        if stored == "zh-Hant" {
            current = .traditionalChinese
        } else {
            current = AppLanguage(rawValue: stored ?? "") ?? .english
        }
    }

    func setLanguage(_ language: AppLanguage) {
        current = language
    }

    func text(_ english: String, _ japanese: String, _ traditionalChinese: String) -> String {
        switch current {
        case .english:
            return english
        case .japanese:
            return japanese
        case .traditionalChinese:
            return simplifiedChineseText(traditionalChinese)
        }
    }

    func dateString(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: current.localeIdentifier)
        return formatter.string(from: date)
    }
}

private func simplifiedChineseText(_ text: String) -> String {
    let phraseReplacements: [(String, String)] = [
        ("繁體中文", "简体中文"),
        ("開啟你的故事", "开启你的故事"),
        ("用戶名", "用户名"),
        ("註冊", "注册"),
        ("頭像", "头像"),
        ("頭像工坊", "头像工坊"),
        ("選擇", "选择"),
        ("選取", "选取"),
        ("選單", "选单"),
        ("選項", "选项"),
        ("選擇風格", "选择风格"),
        ("選擇小程序", "选择小程序"),
        ("選擇遊戲", "选择游戏"),
        ("選擇語言", "选择语言"),
        ("請選擇您的語言", "请选择您的语言"),
        ("記錄今天的心情和故事", "记录今天的心情和故事"),
        ("更多小程序，敬請期待", "更多小程序，敬请期待"),
        ("免費", "免费"),
        ("聊天次數", "聊天次数"),
        ("邀請碼", "邀请码"),
        ("分享邀請碼", "分享邀请码"),
        ("獲取", "获取"),
        ("複製", "复制"),
        ("關閉", "关闭"),
        ("賬戶管理", "账户管理"),
        ("個人資料", "个人资料"),
        ("輸入", "输入"),
        ("驗證", "验证"),
        ("安全設定", "安全设置"),
        ("新密碼", "新密码"),
        ("更新密碼", "更新密码"),
        ("退出登入", "退出登录"),
        ("註銷賬號", "注销账号"),
        ("提示", "提示"),
        ("頭像更新失敗", "头像更新失败"),
        ("密碼更新失敗", "密码更新失败"),
        ("賬號註銷失敗", "账号注销失败"),
        ("簽到", "签到"),
        ("今日已簽到", "今日已签到"),
        ("免費次數", "免费次数"),
        ("刪除", "删除"),
        ("刪除此角色", "删除此角色"),
        ("刪除人物", "删除人物"),
        ("進入聊天", "进入聊天"),
        ("編輯資料", "编辑资料"),
        ("詳細設定", "详细设定"),
        ("互動設定", "互动设定"),
        ("世界觀", "世界观"),
        ("介紹", "介绍"),
        ("關係", "关系"),
        ("群聊資訊", "群聊信息"),
        ("解散群聊", "解散群聊"),
        ("確認刪除", "确认删除"),
        ("確定", "确定"),
        ("取消", "取消"),
        ("創建人物", "创建人物"),
        ("創建群聊", "创建群聊"),
        ("人物介紹", "人物介绍"),
        ("人物性格", "人物性格"),
        ("你的設定", "你的设定"),
        ("和你的關係", "和你的关系"),
        ("點擊", "点击"),
        ("設定", "设定"),
        ("點下方「新增日記」開始記錄", "点下方「新增日记」开始记录"),
        ("我的日記", "我的日记"),
        ("日記本", "日记本"),
        ("新增日記", "新增日记"),
        ("寫下今天的心情和故事...", "写下今天的心情和故事..."),
        ("剩餘", "剩余"),
        ("生成結果", "生成结果"),
        ("保存圖片", "保存图片"),
        ("圖片載入失敗", "图片载入失败"),
        ("今日次數已用完，請明天再試。", "今日次数已用完，请明天再试。"),
        ("翻譯", "翻译"),
        ("網路", "网络"),
        ("響應", "响应"),
        ("查詢", "查询"),
        ("圖片", "图片"),
        ("請", "请"),
        ("嘗試", "尝试"),
        ("故事詳情", "故事详情"),
        ("你們的故事", "你们的故事"),
        ("寫故事", "写故事"),
        ("一起寫的故事", "一起写的故事"),
        ("記錄", "记录"),
        ("畫", "画"),
        ("遊戲", "游戏"),
        ("小遊戲", "小游戏"),
        ("通訊錄", "通讯录"),
        ("小程序", "小程序"),
        ("簡體中文", "简体中文"),
        ("未知地點", "未知地点"),
        ("初始地點", "初始地点")
    ]

    var result = text
    for (source, target) in phraseReplacements {
        result = result.replacingOccurrences(of: source, with: target)
    }
    return result
}

@inline(__always)
func LT(_ english: String, _ japanese: String, _ traditionalChinese: String) -> String {
    LangManager.shared.text(english, japanese, traditionalChinese)
}

@inline(__always)
func currentAILanguageName() -> String {
    LangManager.shared.current.aiLanguageName
}

@inline(__always)
func currentAIResponseInstruction() -> String {
    LangManager.shared.current.aiResponseInstruction
}

@inline(__always)
func localizedUnknownLocation() -> String {
    LT("Unknown Location", "不明な場所", "未知地點")
}

@inline(__always)
func localizedInitialLocation() -> String {
    LT("Initial Location", "初期地点", "初始地點")
}

@inline(__always)
func localizedDefaultGroupName() -> String {
    LT("Group Chat", "グループチャット", "群聊")
}

@inline(__always)
func localizedDefaultUserName() -> String {
    LT("User", "ユーザー", "使用者")
}

@inline(__always)
func localizedMeText() -> String {
    LT("Me", "私", "我")
}

@inline(__always)
func localizedLocationValue(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
        return localizedUnknownLocation()
    }

    let unknownSet = ["Unknown Location", "不明な場所", "未知地点", "未知地點"]
    if unknownSet.contains(trimmed) {
        return localizedUnknownLocation()
    }

    let initialSet = ["Initial Location", "初期地点", "初始地点", "初始地點"]
    if initialSet.contains(trimmed) {
        return localizedInitialLocation()
    }

    return value
}
