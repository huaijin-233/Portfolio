//
//  profileview1.swift
//  Huai Xin
//
//  Created by Huaijin233 on 2/23/26.
//

import SwiftUI
import UIKit

// MARK: - Profile (Main)

struct ProfileView: View {
    @State private var userName: String = localizedDefaultUserName()
    @State private var userId: String = ""
    @State private var userAvatarBase64: String? = nil
    @State private var freeMessageCount: Int = 0

    @State private var hasCheckedInToday = false
    @State private var isCheckingIn = false

    // Toast (main page)
    @State private var showToast = false
    @State private var toastMessage = ""

    // Invite UI state
    @State private var showInviteModal = false
    @State private var inviteCodeToday: String = ""
    @State private var isInviteLoading = false

    private let db = Firestore.firestore()

    // UI Constants - Premium Soft Pink Theme
    private let bgPink = Color(red: 0.99, green: 0.96, blue: 0.97)
    private let primaryPink = Color(red: 1.0, green: 0.45, blue: 0.65)
    private let textGray = Color(red: 0.4, green: 0.4, blue: 0.45)

    var body: some View {
        NavigationView {
            ZStack {
                bgPink.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        Spacer().frame(height: 10)

                        // 头像区域
                        VStack(spacing: 16) {
                            AvatarView(name: userName, color: "pink", size: 96, base64: userAvatarBase64)
                                .shadow(color: primaryPink.opacity(0.15), radius: 15, x: 0, y: 8)

                            VStack(spacing: 6) {
                                Text(userName)
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.black.opacity(0.85))

                                Text("ID: \(userId)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(textGray.opacity(0.7))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(Color.white)
                                    .cornerRadius(12)
                                    .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
                            }
                        }
                        .padding(.top, 20)

                        // --- 计数/分享/签到区域 ---
                        VStack(spacing: 0) {
                            VStack(spacing: 20) {
                                // Count
                                HStack {
                                    Text(LT("Free messages", "無料チャット回数", "免費聊天次數"))
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(textGray)
                                    Spacer()
                                    Text("\(freeMessageCount)")
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundColor(freeMessageCount > 0 ? primaryPink : .red.opacity(0.8))
                                }

                                // Share Invite
                                VStack(spacing: 10) {
                                    Button(action: handleShareInvite) {
                                        HStack {
                                            Image(systemName: "square.and.arrow.up")
                                            Text(inviteCodeToday.isEmpty ? LT("Share invite code", "招待コードを共有", "分享邀請碼") : LT("Used today", "本日は使用済み", "今日已用完"))
                                                .fontWeight(.semibold)
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(.white.opacity(0.85))
                                        }
                                        .padding(.horizontal, 16)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                        .background(primaryPink)
                                        .foregroundColor(.white)
                                        .cornerRadius(16)
                                        .shadow(color: primaryPink.opacity(0.25), radius: 6, x: 0, y: 3)
                                    }
                                    .disabled(isInviteLoading)

                                    Text(LT("Share an invite code to add 100 messages for both of you", "招待コードを共有すると自分と相手に100回分追加されます", "分享邀請碼給自己和對方增加 100 次聊天次數"))
                                        .font(.caption)
                                        .foregroundColor(textGray.opacity(0.7))
                                }

                                // Check-in
                                VStack(spacing: 10) {
                                    Button(action: performCheckIn) {
                                        HStack {
                                            Image(systemName: hasCheckedInToday ? "checkmark.circle.fill" : "calendar.badge.plus")
                                            Text(hasCheckedInToday ? LT("Checked in today", "今日はチェックイン済み", "今日已簽到") : LT("Daily check-in (+50)", "毎日チェックイン (+50)", "每日簽到 (+50次)"))
                                                .fontWeight(.semibold)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                        .background(hasCheckedInToday ? Color.gray.opacity(0.1) : Color.orange.opacity(0.9))
                                        .foregroundColor(hasCheckedInToday ? .gray : .white)
                                        .cornerRadius(16)
                                        .shadow(color: hasCheckedInToday ? .clear : Color.orange.opacity(0.25), radius: 6, x: 0, y: 3)
                                    }
                                    .disabled(hasCheckedInToday || isCheckingIn)

                                    Text(LT("Check in to get more free messages", "チェックインして無料回数を増やす", "簽到獲取更多免費次數"))
                                        .font(.caption)
                                        .foregroundColor(textGray.opacity(0.7))
                                }
                            }
                            .padding(24)
                        }
                        .background(Color.white)
                        .cornerRadius(24)
                        .shadow(color: Color.black.opacity(0.04), radius: 15, x: 0, y: 5)
                        .padding(.horizontal, 20)

                        // --- 账户管理入口 ---
                        NavigationLink(destination: AccountSettingsView(currentName: userName, currentAvatarBase64: userAvatarBase64)) {
                            HStack {
                                Image(systemName: "gearshape.fill")
                                    .foregroundColor(primaryPink)
                                    .font(.system(size: 18))
                                Text(LT("Account Settings", "アカウント設定", "賬戶管理"))
                                    .foregroundColor(.primary.opacity(0.8))
                                    .fontWeight(.medium)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray.opacity(0.3))
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .padding(20)
                            .background(Color.white)
                            .cornerRadius(20)
                            .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 3)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 50)
                    }
                }
                .navigationBarHidden(true)

                // Invite Code Modal (dark background)
                if showInviteModal {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                        .onTapGesture { withAnimation { showInviteModal = false } }
                        .zIndex(9)

                    VStack(spacing: 16) {
                        Text(LT("Invite Code", "招待コード", "邀請碼"))
                            .font(.headline)
                            .foregroundColor(.black.opacity(0.85))

                        HStack(spacing: 12) {
                            Text(inviteCodeToday)
                                .font(.system(size: 26, weight: .bold, design: .monospaced))
                                .foregroundColor(primaryPink)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 14)
                                .background(primaryPink.opacity(0.08))
                                .cornerRadius(14)

                            Button(action: { copyInviteCode(showToast: true) }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "doc.on.doc")
                                    Text(LT("Copy", "コピー", "複製"))
                                        .fontWeight(.semibold)
                                }
                                .padding(.horizontal, 14)
                                .frame(height: 44)
                                .background(Color.gray.opacity(0.12))
                                .foregroundColor(.black.opacity(0.8))
                                .cornerRadius(14)
                            }
                        }

                        Text(LT("You can tap \"Used today\" to copy today's same invite code again", "「本日は使用済み」をタップして、今日の同じ招待コードを再度コピーできます", "點擊「今日已用完」也可再次複製今天同樣的邀請碼"))
                            .font(.system(size: 12))
                            .foregroundColor(textGray.opacity(0.8))

                        Button(action: { withAnimation { showInviteModal = false } }) {
                            Text(LT("Close", "閉じる", "關閉"))
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.black.opacity(0.06))
                                .foregroundColor(.black.opacity(0.75))
                                .cornerRadius(14)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: 320)
                    .background(Color.white)
                    .cornerRadius(22)
                    .shadow(color: Color.black.opacity(0.12), radius: 20, x: 0, y: 10)
                    .zIndex(10)
                    .transition(.scale.combined(with: .opacity))
                }

                // Toast (main page)
                if showToast {
                    VStack {
                        Spacer()
                        Text(toastMessage)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.black.opacity(0.75))
                            .cornerRadius(25)
                            .padding(.bottom, 60)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .zIndex(10)
                }
            }
        }
        .onAppear { fetchUserData() }
    }

    // MARK: - Check-in

    func performCheckIn() {
        guard !userId.isEmpty else { return }
        isCheckingIn = true

        CheckInManager.shared.checkIn(userId: userId) { success, msg in
            isCheckingIn = false
            if success {
                showToastMessage(LT("Check-in successful! 50 free messages added.", "チェックイン成功！無料メッセージが50回分追加されました。", "簽到成功！已增加 50 次免費次數"))
            } else if let msg = msg {
                showToastMessage(msg)
            }
        }
    }

    // MARK: - Toast

    func showToastMessage(_ msg: String) {
        toastMessage = msg
        withAnimation { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { showToast = false }
        }
    }

    // MARK: - User data + inviter notifications

    func fetchUserData() {
        guard let user = Auth.auth().currentUser else { return }
        userId = user.uid

        if let name = user.displayName, !name.isEmpty {
            userName = name
        } else if let email = user.email, email.hasSuffix("@huaixin.app") {
            userName = email.replacingOccurrences(of: "@huaixin.app", with: "")
        }

        db.collection("users").document(user.uid).addSnapshotListener { snapshot, _ in
            guard let data = snapshot?.data() else { return }

            freeMessageCount = data["freeMessageCount"] as? Int ?? 0
            userAvatarBase64 = data["avatarBase64"] as? String

            let lastTimestamp = data["lastCheckInDate"] as? Timestamp
            if let lastDate = lastTimestamp?.dateValue(), Calendar.current.isDateInToday(lastDate) {
                hasCheckedInToday = true
            } else {
                hasCheckedInToday = false
            }

            // Keep today's invite code label state in sync
            let inviteTs = data["lastInviteCreatedAt"] as? Timestamp
            if let inviteDate = inviteTs?.dateValue(), Calendar.current.isDateInToday(inviteDate) {
                inviteCodeToday = data["lastInviteCode"] as? String ?? inviteCodeToday
            } else {
                inviteCodeToday = ""
            }
        }
    }

    // MARK: - Invite share (main page)

    func handleShareInvite() {
        isInviteLoading = true
        Task {
            do {
                // Try to fetch today's existing code first
                if let today = try await ShareManager.shared.fetchTodayInviteCode(), !today.isEmpty {
                    await MainActor.run { inviteCodeToday = today }
                } else {
                    let newCode = try await ShareManager.shared.createDailyInviteCode()
                    await MainActor.run { inviteCodeToday = newCode }
                }

                await MainActor.run {
                    isInviteLoading = false
                    // Auto-copy once, no toast
                    copyInviteCode(showToast: false)
                    withAnimation { showInviteModal = true }
                }
            } catch {
                await MainActor.run {
                    isInviteLoading = false
                    showToastMessage(LT("Failed to get invite code", "招待コードの取得に失敗しました", "邀請碼獲取失敗") + "：\(error.localizedDescription)")
                }
            }
        }
    }

    func copyInviteCode(showToast: Bool = true) {
        guard !inviteCodeToday.isEmpty else { return }
        UIPasteboard.general.string = inviteCodeToday
        if showToast {
            showToastMessage(LT("Invite code copied", "招待コードをコピーしました", "邀請碼已複製"))
        }
    }
}

// MARK: - Account Settings (Secondary)

struct AccountSettingsView: View {
    @ObservedObject private var lang = LangManager.shared
    @State var currentName: String
    @State var currentAvatarBase64: String?

    @State private var newName: String = ""
    @State private var newPassword: String = ""

    @State private var showImagePicker = false
    @State private var inputImage: UIImage?

    @State private var isLoading = false
    @State private var alertMessage = ""
    @State private var showAlert = false

    // Invite redeem UI state
    @State private var inviteInput: String = ""
    @State private var isVerifyingInvite = false
    @State private var showMiniToast = false
    @State private var miniToastMessage = ""

    private let db = Firestore.firestore()
    private let accentPink = Color(red: 1.0, green: 0.45, blue: 0.65)

    var body: some View {
        Form {
            Section(header: Text(LT("Profile", "プロフィール", "個人資料"))) {
                Button(action: { showImagePicker = true }) {
                    HStack {
                        Text(LT("Avatar", "アバター", "頭像")).foregroundColor(.primary)
                        Spacer()
                        if let base64 = currentAvatarBase64,
                           let data = Data(base64Encoded: base64),
                           let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 44, height: 44)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .frame(width: 44, height: 44)
                                .foregroundColor(.gray.opacity(0.3))
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.gray.opacity(0.5))
                    }
                }

                HStack {
                    Text(LT("Username", "ユーザー名", "用戶名"))
                    TextField(LT("Enter a new username", "新しいユーザー名を入力", "輸入新用戶名"), text: $newName)
                        .multilineTextAlignment(.trailing)
                        .onAppear { newName = currentName }
                }

                if newName != currentName {
                    Button(LT("Save Username", "ユーザー名を保存", "保存用戶名")) { updateUsername() }
                        .foregroundColor(accentPink)
                }
            }

            Section(header: Text(LT("Language", "言語", "语言"))) {
                Picker(
                    LT("App Language", "アプリの言語", "应用语言"),
                    selection: Binding(
                        get: { lang.current },
                        set: { lang.setLanguage($0) }
                    )
                ) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.label).tag(language)
                    }
                }
            }

            // Invite redeem (in account settings)
            Section(header: Text(LT("Invite", "招待", "邀請"))) {
                HStack(spacing: 10) {
                    Text(LT("Enter invite code", "招待コードを入力", "填寫邀請碼"))
                    TextField(LT("6 letters", "6文字", "6 位字母"), text: $inviteInput)
                        .multilineTextAlignment(.trailing)
                        .autocapitalization(.allCharacters)
                        .disableAutocorrection(true)

                    Button(action: verifyInviteCode) {
                        if isVerifyingInvite {
                            ProgressView()
                        } else {
                            Text(LT("Verify", "確認", "驗證")).fontWeight(.semibold)
                        }
                    }
                    .disabled(inviteInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isVerifyingInvite)
                    .foregroundColor(accentPink)
                }
            }

            Section(header: Text(LT("Security", "セキュリティ", "安全設定"))) {
                SecureField(LT("New password (if changing)", "新しいパスワード（変更する場合）", "新密碼（若要更改）"), text: $newPassword)
                if !newPassword.isEmpty {
                    Button(LT("Update Password", "パスワードを更新", "更新密碼")) { updatePassword() }
                        .foregroundColor(accentPink)
                }
            }

            Section {
                Button(action: signOut) {
                    HStack { Spacer(); Text(LT("Sign Out", "ログアウト", "退出登入")).foregroundColor(.red.opacity(0.8)); Spacer() }
                }
                Button(action: deleteAccount) {
                    HStack { Spacer(); Text(LT("Delete Account", "アカウント削除", "註銷賬號")).foregroundColor(.red.opacity(0.8)); Spacer() }
                }
            }
        }
        .navigationTitle(LT("Account Settings", "アカウント設定", "賬戶管理"))
        .sheet(isPresented: $showImagePicker, onDismiss: updateAvatar) {
            ImagePicker(image: $inputImage)
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text(LT("Notice", "お知らせ", "提示")), message: Text(alertMessage), dismissButton: .default(Text(LT("OK", "OK", "確定"))))
        }
        .overlay(
            isLoading
            ? ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.black.opacity(0.1))
            : nil
        )
        .overlay(
            Group {
                if showMiniToast {
                    VStack {
                        Spacer()
                        Text(miniToastMessage)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.black.opacity(0.75))
                            .cornerRadius(25)
                            .padding(.bottom, 60)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        )
    }

    // MARK: - Existing logic

    func updateAvatar() {
        guard let inputImage = inputImage else { return }
        isLoading = true

        if let data = inputImage.jpegData(compressionQuality: 0.5) {
            let base64 = data.base64EncodedString()
            guard let uid = Auth.auth().currentUser?.uid else { return }

            db.collection("users").document(uid).updateData([
                "avatarBase64": base64
            ]) { error in
                isLoading = false
                if let error = error {
                    alertMessage = LT("Failed to update avatar", "アバターの更新に失敗しました", "頭像更新失敗") + ": \(error.localizedDescription)"
                    showAlert = true
                } else {
                    currentAvatarBase64 = base64
                }
            }
        } else {
            isLoading = false
        }
    }

    func updateUsername() {
        guard !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let user = Auth.auth().currentUser else { return }
        isLoading = true

        let changeRequest = user.createProfileChangeRequest()
        changeRequest.displayName = newName
        changeRequest.commitChanges { error in
            if let error = error {
                isLoading = false
                alertMessage = error.localizedDescription
                showAlert = true
                return
            }

            db.collection("users").document(user.uid).updateData([
                "username": newName
            ]) { err in
                isLoading = false
                if err == nil {
                    currentName = newName
                    alertMessage = LT("Username updated", "ユーザー名を更新しました", "用戶名已更新")
                    showAlert = true
                }
            }
        }
    }

    func updatePassword() {
        guard !newPassword.isEmpty else { return }
        guard let user = Auth.auth().currentUser else { return }
        isLoading = true

        user.updatePassword(to: newPassword) { error in
            isLoading = false
            if let error = error {
                alertMessage = LT("Failed to update password", "パスワードの更新に失敗しました", "密碼更新失敗") + ": \(error.localizedDescription)\n" + LT("(You may need to sign in again before changing the password.)", "（パスワード変更前に再ログインが必要な場合があります。）", "（可能需要重新登入才能修改密碼）")
                showAlert = true
            } else {
                newPassword = ""
                alertMessage = LT("Password updated", "パスワードを更新しました", "密碼已更新")
                showAlert = true
            }
        }
    }

    func signOut() {
        try? Auth.auth().signOut()
    }

    func deleteAccount() {
        guard let user = Auth.auth().currentUser else { return }
        alertMessage = LT("Are you sure you want to delete this account? This cannot be undone.", "本当にアカウントを削除しますか？この操作は元に戻せません。", "確定要註銷賬號嗎？此操作不可恢復。")
        isLoading = true

        db.collection("users").document(user.uid).delete { _ in
            user.delete { error in
                isLoading = false
                if let error = error {
                    alertMessage = LT("Failed to delete account", "アカウント削除に失敗しました", "賬號註銷失敗") + ": \(error.localizedDescription)\n" + LT("(You may need to sign in again.)", "（再ログインが必要な場合があります。）", "（可能需要重新登入）")
                    showAlert = true
                }
            }
        }
    }

    // Mini toast for invite verification result
    func showMiniToastMessage(_ msg: String) {
        miniToastMessage = msg
        withAnimation { showMiniToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { showMiniToast = false }
        }
    }

    func verifyInviteCode() {
        let code = inviteInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return }
        isVerifyingInvite = true
        Task {
            do {
                try await ShareManager.shared.redeemInviteCode(code)
                await MainActor.run {
                    isVerifyingInvite = false
                    inviteInput = ""
                    showMiniToastMessage(LT("100 free messages added", "無料メッセージが100回分追加されました", "已增加 100 次聊天次數"))
                }
            } catch {
                await MainActor.run {
                    isVerifyingInvite = false
                    showMiniToastMessage(LT("Verification failed", "確認に失敗しました", "驗證失敗") + "：\(error.localizedDescription)")
                }
            }
        }
    }
}
