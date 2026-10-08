//
//  changeview.swift
//  Huai Xin
//
//  Created by Huaijin233 on 2/15/26.
//
import SwiftUI
import UIKit

struct ChangeView: View, Equatable {
    @Environment(\.presentationMode) var presentationMode
    
    // Navigation callback to parent (CharacterView or ChatListView) - Keeping signature for compatibility but not using for navigation
    var onEnterChat: ((CharacterModel?, GroupChatModel?) -> Void)?
    
    // Data Models (One of these will be non-nil)
    var character: CharacterModel?
    var group: GroupChatModel?
    
    // Implement Equatable to prevent view updates (and navigation pops) when data changes in background
    static func == (lhs: ChangeView, rhs: ChangeView) -> Bool {
        return lhs.character?.id == rhs.character?.id && lhs.group?.id == rhs.group?.id
    }
    
    // Form States
    @State private var name = ""
    @State private var world = ""
    @State private var intro = ""
    @State private var personality = ""
    @State private var userName = ""
    @State private var userPersona = ""
    @State private var relationship = ""
    
    // Avatar States
    @State private var showImagePicker = false
    @State private var inputImage: UIImage?
    @State private var avatarBase64: String = ""
    
    @State private var isLoading = false
    @State private var showDeleteAlert = false
    
    // Navigation State
    @State private var navigateToChat = false
    // Stable models for navigation to prevent popping when parent data updates (e.g. lastMessage changes)
    @State private var stableCharacter: CharacterModel?
    @State private var stableGroup: GroupChatModel?
    
    private let db = Firestore.firestore()
    
    // UI Constants
    let bgGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 1.0, green: 0.98, blue: 0.99),
            Color(red: 1.0, green: 0.94, blue: 0.96)
        ]),
        startPoint: .top,
        endPoint: .bottom
    )
    let primaryPink = Color(red: 1.0, green: 0.45, blue: 0.65)
    let softShadow = Color(red: 1.0, green: 0.45, blue: 0.65).opacity(0.15)
    
    var body: some View {
        ZStack {
            bgGradient.ignoresSafeArea()
            
            // Navigation Links
            // Use stable models to ensure destination view identity doesn't change on DB updates
            if let char = stableCharacter {
                NavigationLink(destination: ChatView(character: char), isActive: $navigateToChat) { EmptyView() }
            }
            if let grp = stableGroup {
                NavigationLink(destination: GroupChatView(group: grp), isActive: $navigateToChat) { EmptyView() }
            }
            
            ScrollView {
                VStack(spacing: 32) {
                    // Avatar Section
                    VStack(spacing: 16) {
                        Button(action: { showImagePicker = true }) {
                            ZStack {
                                // Glow effect
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 100, height: 100)
                                    .shadow(color: softShadow, radius: 15, x: 0, y: 8)
                                
                                AvatarView(
                                    name: name.isEmpty ? "?" : name,
                                    color: character?.avatarColor ?? "pink",
                                    size: 94,
                                    base64: avatarBase64
                                )
                                
                                // Camera Icon - Glassmorphism style
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(
                                        Circle()
                                            .fill(LinearGradient(colors: [primaryPink, primaryPink.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    )
                                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                    .shadow(color: primaryPink.opacity(0.3), radius: 4, x: 0, y: 2)
                                    .offset(x: 32, y: 32)
                            }
                        }
                        Text(LT("Tap to change avatar", "タップしてアバターを変更", "點擊修改頭像"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(primaryPink.opacity(0.8))
                    }
                    .padding(.top, 24)
                    
                    // Basic Info
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Image(systemName: group != nil ? "person.3.fill" : "person.fill")
                                .foregroundColor(primaryPink)
                            Text(group != nil ? LT("Group Chat Info", "グループチャット情報", "群聊資訊") : LT("Basic Info", "基本情報", "基本信息"))
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundColor(Color(UIColor.darkGray))
                        }
                        .padding(.bottom, 4)
                        
                        ChangeInputRow(icon: "tag.fill", placeholder: LT("Name", "名前", "名稱"), text: $name)
                    }
                    .padding(24)
                    .background(Color.white)
                    .cornerRadius(28)
                    .shadow(color: Color.black.opacity(0.03), radius: 15, x: 0, y: 5)
                    
                    // Detail Settings
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(primaryPink)
                            Text(LT("Detailed Settings", "詳細設定", "詳細設定"))
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundColor(Color(UIColor.darkGray))
                        }
                        .padding(.bottom, 4)

                        ChangeMultilineInputRow(icon: "globe", placeholder: LT("World", "世界観", "世界觀"), text: $world)

                        // Groups don't typically have a single "intro" or "personality" for the group itself in this model,
                        // but we allow editing the world context.
                        // Characters have Intro/Personality.
                        if character != nil {
                            Divider().padding(.leading, 36).opacity(0.3)
                            ChangeMultilineInputRow(icon: "text.alignleft", placeholder: LT("Introduction", "紹介", "介紹"), text: $intro)
                            Divider().padding(.leading, 36).opacity(0.3)
                            ChangeMultilineInputRow(icon: "sparkles", placeholder: LT("Personality", "性格", "性格"), text: $personality)
                        }
                    }
                    .padding(24)
                    .background(Color.white)
                    .cornerRadius(28)
                    .shadow(color: Color.black.opacity(0.03), radius: 15, x: 0, y: 5)
                    
                    // Interaction Settings
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Image(systemName: "heart.text.square.fill")
                                .foregroundColor(primaryPink)
                            Text(LT("Interaction Settings", "交流設定", "互動設定"))
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundColor(Color(UIColor.darkGray))
                        }
                        .padding(.bottom, 4)

                        ChangeInputRow(icon: "person.circle", placeholder: LT("Your name", "あなたの名前", "你的名字"), text: $userName)
                        Divider().padding(.leading, 36).opacity(0.3)
                        ChangeMultilineInputRow(icon: "theatermasks.fill", placeholder: LT("Your persona", "あなたの設定", "你的設定"), text: $userPersona)

                        if character != nil {
                            Divider().padding(.leading, 36).opacity(0.3)
                            ChangeMultilineInputRow(icon: "heart.fill", placeholder: LT("Relationship", "関係", "關係"), text: $relationship)
                        }
                    }
                    .padding(24)
                    .background(Color.white)
                    .cornerRadius(28)
                    .shadow(color: Color.black.opacity(0.03), radius: 15, x: 0, y: 5)
                    
                    // Action Buttons
                    VStack(spacing: 16) {
                        // Enter Chat Button
                        Button(action: {
                            navigateToChat = true
                        }) {
                            HStack {
                                Image(systemName: "message.fill")
                                Text(LT("Enter Chat", "チャットへ", "進入聊天"))
                            }
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(primaryPink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.white)
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(primaryPink.opacity(0.3), lineWidth: 1)
                            )
                            .shadow(color: primaryPink.opacity(0.05), radius: 8, x: 0, y: 4)
                        }
                        
                        Button(action: saveChanges) {
                            ZStack {
                                if isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text(LT("Save Changes", "変更を保存", "保存修改"))
                                        .font(.system(size: 17, weight: .bold, design: .rounded))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                name.isEmpty
                                ? LinearGradient(colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [primaryPink, primaryPink.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .foregroundColor(.white)
                            .cornerRadius(20)
                            .shadow(color: name.isEmpty ? Color.clear : primaryPink.opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                        .disabled(name.isEmpty || isLoading)
                        
                        Button(action: { showDeleteAlert = true }) {
                            Text(group != nil ? LT("Delete Group Chat", "グループチャットを削除", "解散群聊") : LT("Delete Character", "キャラクターを削除", "刪除人物"))
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.red.opacity(0.7))
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.red.opacity(0.03))
                                .cornerRadius(20)
                        }
                    }
                    .padding(.bottom, 50)
                }
                .padding(.horizontal, 20)
            }
        }
        .navigationTitle(LT("Edit Profile", "プロフィールを編集", "編輯資料"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showImagePicker, onDismiss: processImage) {
            ImagePicker(image: $inputImage)
        }
        .onAppear(perform: loadData)
        .alert(isPresented: $showDeleteAlert) {
            Alert(
                title: Text(LT("Confirm Delete", "削除を確認", "確認刪除")),
                message: Text(LT("This cannot be undone and all chat history will be cleared.", "この操作は元に戻せず、すべてのチャット履歴が削除されます。", "刪除後無法恢復，且會清空所有聊天記錄。")),
                primaryButton: .destructive(Text(LT("Delete", "削除", "刪除"))) { deleteItem() },
                secondaryButton: .cancel(Text(LT("Cancel", "キャンセル", "取消")))
            )
        }
    }
    
    func loadData() {
        if let char = character {
            // Capture stable model for navigation
            if stableCharacter == nil { stableCharacter = char }
            
            self.name = char.name
            self.world = char.world
            self.intro = char.intro
            self.personality = char.personality
            self.userName = char.userName
            self.userPersona = char.userPersona
            self.relationship = char.relationship
            self.avatarBase64 = char.avatarBase64
        } else if let grp = group {
            // Capture stable model for navigation
            if stableGroup == nil { stableGroup = grp }
            
            self.name = grp.name
            self.world = grp.world
            self.userName = grp.userName
            self.userPersona = grp.userPersona
        }
    }
    
    func processImage() {
        guard let inputImage = inputImage else { return }
        if let data = inputImage.jpegData(compressionQuality: 0.5) {
            self.avatarBase64 = data.base64EncodedString()
        }
    }
    
    func saveChanges() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        isLoading = true
        
        let userRef = db.collection("users").document(uid)
        
        if let char = character {
            userRef.collection("characters").document(char.id).updateData([
                "name": name,
                "world": world,
                "intro": intro,
                "personality": personality,
                "userName": userName,
                "userPersona": userPersona,
                "relationship": relationship,
                "avatarBase64": avatarBase64
            ]) { _ in
                isLoading = false
                presentationMode.wrappedValue.dismiss()
            }
        } else if let grp = group {
            userRef.collection("groups").document(grp.id).updateData([
                "name": name,
                "world": world,
                "userName": userName,
                "userPersona": userPersona
            ]) { _ in
                isLoading = false
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
    
    func deleteItem() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        isLoading = true
        
        let userRef = db.collection("users").document(uid)
        
        if let char = character {
            userRef.collection("characters").document(char.id).delete { _ in
                isLoading = false
                presentationMode.wrappedValue.dismiss()
            }
        } else if let grp = group {
            userRef.collection("groups").document(grp.id).delete { _ in
                isLoading = false
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

struct ChangeInputRow: View {
    var icon: String
    var placeholder: String
    @Binding var text: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(red: 1.0, green: 0.95, blue: 0.97))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .foregroundColor(Color(red: 1.0, green: 0.45, blue: 0.65))
                    .font(.system(size: 16))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                if !text.isEmpty {
                    Text(placeholder)
                        .font(.caption2)
                        .foregroundColor(.gray.opacity(0.8))
                }
                TextField(placeholder, text: $text)
                    .font(.system(size: 16))
                    .foregroundColor(.black.opacity(0.85))
            }
        }
    }
}

struct ChangeMultilineInputRow: View {
    var icon: String
    var placeholder: String
    @Binding var text: String

    @State private var measuredHeight: CGFloat = 44

    // Match ChangeInputRow styling
    private let iconBg = Color(red: 1.0, green: 0.95, blue: 0.97)
    private let iconFg = Color(red: 1.0, green: 0.45, blue: 0.65)

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconBg)
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .foregroundColor(iconFg)
                    .font(.system(size: 16))
            }
            .padding(.top, 2)

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 16))
                        .foregroundColor(.gray.opacity(0.55))
                        .padding(.top, 10)
                        .padding(.leading, 4)
                } else {
                    Text(placeholder)
                        .font(.caption2)
                        .foregroundColor(.gray.opacity(0.8))
                        .padding(.top, -4)
                        .padding(.leading, 0)
                }

                CH_GrowingTextView(text: $text, measuredHeight: $measuredHeight)
                    .frame(height: measuredHeight)
                    .padding(.top, text.isEmpty ? 2 : 12)
            }
        }
    }
}

// UIKit-backed multi-line input that auto-wraps and auto-grows.
struct CH_GrowingTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var measuredHeight: CGFloat

    private let minHeight: CGFloat = 44
    private let maxHeight: CGFloat = 240

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.backgroundColor = .clear
        tv.font = UIFont.systemFont(ofSize: 16)
        tv.textColor = UIColor.black.withAlphaComponent(0.85)
        tv.isScrollEnabled = false
        tv.delegate = context.coordinator
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 2, bottom: 8, right: 2)
        tv.textContainer.lineFragmentPadding = 0
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        recalcHeight(view: uiView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: CH_GrowingTextView

        init(parent: CH_GrowingTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            parent.recalcHeight(view: textView)
        }
    }

    private func recalcHeight(view: UITextView) {
        let targetSize = CGSize(width: view.bounds.width, height: .greatestFiniteMagnitude)
        let fittingSize = view.sizeThatFits(targetSize)

        let clamped = min(max(fittingSize.height, minHeight), maxHeight)
        view.isScrollEnabled = fittingSize.height > maxHeight

        if measuredHeight != clamped {
            DispatchQueue.main.async {
                self.measuredHeight = clamped
            }
        }
    }
}
