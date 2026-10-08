//
//  createview.swift
//  Huai Xin
//
//  Created by Huaijin233 on 2/5/26.
import SwiftUI
import UIKit
import Combine

struct CreateView: View {
    enum ExpandTarget: Hashable {
        case world
        case intro
        case personality
        case userPersona
        case relationship
    }

    @Environment(\.presentationMode) var presentationMode
    var onCreate: ((CharacterModel) -> Void)?
    
    @State private var name = ""
    @State private var world = ""
    @State private var intro = ""
    @State private var personality = ""
    @State private var userName = "" // 新增：你的名字
    @State private var userPersona = ""
    @State private var relationship = ""
    
    // 图片上传相关
    @State private var showImagePicker = false
    @State private var inputImage: UIImage?
    @State private var avatarBase64: String = ""
    
    @State private var isLoading = false
    @State private var expandingField: ExpandTarget?
    
    private let db = Firestore.firestore()
    
    // UI Constants
    let bgPink = Color(red: 0.99, green: 0.96, blue: 0.97)
    let cardWhite = Color.white
    let primaryPink = Color(red: 1.0, green: 0.45, blue: 0.65)
    
    var body: some View {
        NavigationView {
            ZStack {
                bgPink.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header / Avatar Section
                        VStack(spacing: 16) {
                            Button(action: { showImagePicker = true }) {
                                ZStack {
                                    AvatarView(name: name.isEmpty ? "?" : name, color: "pink", size: 90, base64: avatarBase64)
                                        .shadow(color: primaryPink.opacity(0.15), radius: 10, x: 0, y: 5)
                                    
                                    Image(systemName: "camera.fill")
                                        .foregroundColor(.white)
                                        .padding(8)
                                        .background(primaryPink)
                                        .clipShape(Circle())
                                        .offset(x: 30, y: 30)
                                        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                                }
                            }
                            
                            Text(LT("Tap to set avatar", "タップしてアバターを設定", "點擊設定頭像"))
                                .font(.caption)
                                .foregroundColor(.gray.opacity(0.8))
                        }
                        .padding(.top, 20)
                        
                        Text(LT("Basic Info", "基本情報", "基本信息"))
                            .font(.headline)
                            .foregroundColor(primaryPink)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        SettingTextCard(
                            icon: "person.fill",
                            title: LT("Character Name", "キャラクター名", "人物名字"),
                            placeholder: LT("Give them a name", "名前を付ける", "给 TA 起个名字"),
                            text: $name
                        )

                        Text(LT("Detailed Settings", "詳細設定", "詳細設定"))
                            .font(.headline)
                            .foregroundColor(primaryPink)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        SettingMultilineCard(
                            icon: "globe",
                            title: LT("World Background", "世界観の背景", "世界观背景"),
                            placeholder: LT("Write the world background", "世界観の背景を書く", "写下世界观背景"),
                            text: $world,
                            showExpand: shouldShowExpandButton(for: world),
                            isExpanding: expandingField == .world,
                            onExpand: { expandSetting(.world) }
                        )

                        SettingMultilineCard(
                            icon: "text.alignleft",
                            title: LT("Character Introduction", "キャラクター紹介", "人物介绍"),
                            placeholder: LT("Write their story", "その人の物語を書く", "写下 TA 的故事"),
                            text: $intro,
                            showExpand: shouldShowExpandButton(for: intro),
                            isExpanding: expandingField == .intro,
                            onExpand: { expandSetting(.intro) }
                        )

                        SettingMultilineCard(
                            icon: "sparkles",
                            title: LT("Character Personality", "キャラクターの性格", "人物性格"),
                            placeholder: LT("Write their personality", "性格を書く", "写下人物性格"),
                            text: $personality,
                            showExpand: shouldShowExpandButton(for: personality),
                            isExpanding: expandingField == .personality,
                            onExpand: { expandSetting(.personality) }
                        )

                        Text(LT("Interaction Settings", "交流設定", "互动设定"))
                            .font(.headline)
                            .foregroundColor(primaryPink)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        SettingTextCard(
                            icon: "person.circle",
                            title: LT("Your Name", "あなたの名前", "你的名字"),
                            placeholder: LT("Your name", "あなたの名前", "你的名字"),
                            text: $userName
                        )

                        SettingMultilineCard(
                            icon: "theatermasks.fill",
                            title: LT("Your Persona", "あなたの設定", "你的设定"),
                            placeholder: LT("Write your persona", "あなたの設定を書く", "写下你本人的设定"),
                            text: $userPersona,
                            showExpand: shouldShowExpandButton(for: userPersona),
                            isExpanding: expandingField == .userPersona,
                            onExpand: { expandSetting(.userPersona) }
                        )

                        SettingMultilineCard(
                            icon: "heart.fill",
                            title: LT("Your Relationship", "あなたとの関係", "和你的关系"),
                            placeholder: LT("Write your story together", "2人の物語を書く", "写下你们的故事"),
                            text: $relationship,
                            showExpand: shouldShowExpandButton(for: relationship),
                            isExpanding: expandingField == .relationship,
                            onExpand: { expandSetting(.relationship) }
                        )
                        
                        // Action Button
                        Button(action: createCharacter) {
                            ZStack {
                                if isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text(LT("Create Character", "キャラクターを作成", "創建人物"))
                                        .font(.headline)
                                        .fontWeight(.bold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(name.isEmpty ? Color.gray.opacity(0.3) : primaryPink)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .shadow(color: name.isEmpty ? Color.clear : primaryPink.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .disabled(name.isEmpty || isLoading)
                        .padding(.bottom, 40)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle(LT("Create Character", "キャラクター作成", "創建人物"))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Text(LT("Cancel", "キャンセル", "取消")).foregroundColor(.gray)
            })
            .sheet(isPresented: $showImagePicker, onDismiss: processImage) {
                ImagePicker(image: $inputImage)
            }
        }
    }
    
    func processImage() {
        guard let inputImage = inputImage else { return }
        // 压缩图片并转 Base64
        if let data = inputImage.jpegData(compressionQuality: 0.5) {
            // 简单的尺寸缩放处理，防止数据过大
            // 这里为了演示直接使用，实际建议先 Resize 到 200x200
            self.avatarBase64 = data.base64EncodedString()
        }
    }
    
    func createCharacter() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        isLoading = true
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let currentTime = formatter.string(from: Date())
        
        let newChar = CharacterModel(
            name: name,
            world: world,
            intro: intro,
            personality: personality,
            userName: userName, // 保存用户名字
            userPersona: userPersona,
            relationship: relationship,
            avatarColor: Bool.random() ? "blue" : "pink", // 内部逻辑值，UI映射为 Cyan/Pink
            avatarBase64: avatarBase64, // 保存图片
            createdAt: Date(),
            virtualTime: currentTime,
            location: localizedInitialLocation()
        )
        
        // 使用 setData 或 addDocument(data:)，传入字典
        var ref: DocumentReference? = nil
        ref = db.collection("users").document(uid).collection("characters").addDocument(data: newChar.toDictionary()) { error in
            isLoading = false
            if let error = error {
                print("Error saving char: \(error)")
            } else {
                // Return created character with correct ID
                var finalChar = newChar
                if let docId = ref?.documentID {
                    finalChar.id = docId
                }
                onCreate?(finalChar)
                presentationMode.wrappedValue.dismiss()
            }
        }
    }

    private func shouldShowExpandButton(for text: String) -> Bool {
        let contentCount = text.filter { !$0.isWhitespace && !$0.isNewline }.count
        return contentCount >= 5
    }

    private func expandSetting(_ target: ExpandTarget) {
        guard expandingField == nil else { return }

        let currentText = text(for: target).trimmingCharacters(in: .whitespacesAndNewlines)
        guard shouldShowExpandButton(for: currentText) else { return }

        expandingField = target

        Task {
            let expandedText = await requestExpandedText(for: target, originalText: currentText)

            await MainActor.run {
                if let expandedText {
                    setText(expandedText, for: target)
                }
                expandingField = nil
            }
        }
    }

    private func text(for target: ExpandTarget) -> String {
        switch target {
        case .world:
            return world
        case .intro:
            return intro
        case .personality:
            return personality
        case .userPersona:
            return userPersona
        case .relationship:
            return relationship
        }
    }

    private func setText(_ value: String, for target: ExpandTarget) {
        switch target {
        case .world:
            world = value
        case .intro:
            intro = value
        case .personality:
            personality = value
        case .userPersona:
            userPersona = value
        case .relationship:
            relationship = value
        }
    }

    private func settingLabel(for target: ExpandTarget) -> String {
        switch target {
        case .world:
            return LT("world background", "世界観の背景", "世界观背景")
        case .intro:
            return LT("character introduction", "キャラクター紹介", "人物介绍")
        case .personality:
            return LT("character personality", "キャラクターの性格", "人物性格")
        case .userPersona:
            return LT("your persona", "あなたの設定", "你的设定")
        case .relationship:
            return LT("your relationship", "あなたとの関係", "和你的关系")
        }
    }

    private func requestExpandedText(for target: ExpandTarget, originalText: String) async -> String? {
        guard let url = URL(string: "https://api.302.ai/v1/chat/completions") else { return nil }

        let label = settingLabel(for: target)
        let language = currentAILanguageName()
        let systemPrompt = """
        You are helping a user expand a short character setting for a character creation form.
        Keep the meaning and core facts the same, but make it richer, more vivid, and more specific.
        Return only the expanded text for the \(label), with no title, no bullet points, and no quotation marks.
        Respond naturally in \(language).
        """

        let body: [String: Any] = [
            "model": "grok-4.20-beta-0309-reasoning",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": originalText]
            ],
            "temperature": 0.9
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer sk-SqztARuLPfz2Hu7rGgLlZWrgdUpf6rN7f48RFOsgG2qlUelg", forHTTPHeaderField: "Authorization")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
                return nil
            }

            let decoded = try JSONDecoder().decode(CreateViewAIResponse.self, from: data)
            return decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            print("Expand setting error: \(error)")
            return nil
        }
    }
}

private struct CreateViewAIResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }

        let message: Message
    }

    let choices: [Choice]
}

struct SettingTextCard: View {
    var icon: String
    var title: String
    var placeholder: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.black.opacity(0.72))

            TextField(placeholder, text: $text)
                .foregroundColor(.black.opacity(0.82))
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(Color(red: 0.985, green: 0.965, blue: 0.975))
                .cornerRadius(14)
        }
        .padding(18)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.02), radius: 10, x: 0, y: 2)
    }
}

struct SettingMultilineCard: View {
    var icon: String
    var title: String
    var placeholder: String
    @Binding var text: String
    var showExpand: Bool = false
    var isExpanding: Bool = false
    var onExpand: (() -> Void)? = nil

    @State private var measuredHeight: CGFloat = 44

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Label(title, systemImage: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.black.opacity(0.72))

                Spacer(minLength: 8)

                if showExpand {
                    Button(action: { onExpand?() }) {
                        HStack(spacing: 4) {
                            if isExpanding {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .tint(.white)
                            } else {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 10, weight: .semibold))
                            }

                            Text(LT("Expand", "拡写", "扩写"))
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(Color(red: 1.0, green: 0.45, blue: 0.65))
                        .foregroundColor(.white)
                        .cornerRadius(999)
                    }
                    .disabled(isExpanding)
                }
            }

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundColor(.gray.opacity(0.55))
                        .padding(.top, 14)
                        .padding(.leading, 10)
                }

                GrowingTextView(text: $text, measuredHeight: $measuredHeight)
                    .frame(height: max(measuredHeight, 120))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color(red: 0.985, green: 0.965, blue: 0.975))
            .cornerRadius(16)
        }
        .padding(18)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.02), radius: 10, x: 0, y: 2)
    }
}

struct GrowingTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var measuredHeight: CGFloat

    private let minHeight: CGFloat = 44
    private let maxHeight: CGFloat = 220

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.backgroundColor = .clear
        tv.font = UIFont.systemFont(ofSize: 16)
        tv.textColor = UIColor.black.withAlphaComponent(0.8)
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
        var parent: GrowingTextView

        init(parent: GrowingTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            parent.recalcHeight(view: textView)
        }
    }

    private func recalcHeight(view: UITextView) {
        // Use the current width to compute the correct wrapped height.
        let targetSize = CGSize(width: view.bounds.width, height: .greatestFiniteMagnitude)
        let fittingSize = view.sizeThatFits(targetSize)

        // Clamp to min/max. If exceeding max, enable internal scrolling.
        let clamped = min(max(fittingSize.height, minHeight), maxHeight)
        view.isScrollEnabled = fittingSize.height > maxHeight

        if measuredHeight != clamped {
            DispatchQueue.main.async {
                self.measuredHeight = clamped
            }
        }
    }
}

// 简单的图片选择器封装
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = true // 允许裁剪正方形
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.image = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.image = originalImage
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}
