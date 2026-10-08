//
//  groupcreateview.swift
//  Huai Xin
//
//  Created by Huaijin233 on 2/10/26.
import SwiftUI
import UIKit
import Combine

struct GroupCreateView: View {
    @Environment(\.presentationMode) var presentationMode
    var onCreate: ((GroupChatModel) -> Void)?
    
    // 步骤状态: 0 = 世界观, 1...5 = 角色
    @State private var currentStep = 0
    
    // 数据状态
    @State private var groupName = "" // 新增：群聊名称
    @State private var world = ""
    @State private var userName = "" // 新增：用户名字
    @State private var userPersona = ""
    @State private var members: [GroupMember] = [
        GroupMember(name: "", intro: "", personality: "", avatarColor: "blue") // 初始一个空角色
    ]
    
    // 图片上传相关
    @State private var showImagePicker = false
    @State private var inputImage: UIImage?
    // 记录当前正在编辑头像的成员索引
    @State private var editingMemberIndex: Int?
    
    @State private var isLoading = false
    private let db = Firestore.firestore()
    
    // UI Constants
    let bgPink = Color(red: 0.99, green: 0.96, blue: 0.97)
    let primaryPink = Color(red: 1.0, green: 0.45, blue: 0.65)
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 1. 顶部步骤条 (类似浏览器 Tab)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        StepTab(title: LT("Background", "背景設定", "背景設定"), isActive: currentStep == 0, index: 0) { currentStep = 0 }
                        
                        ForEach(0..<members.count, id: \.self) { index in
                            StepTab(
                                title: members[index].name.isEmpty ? "\(LT("Character", "キャラクター", "角色")) \(index + 1)" : members[index].name,
                                isActive: currentStep == index + 1,
                                index: index + 1
                            ) {
                                currentStep = index + 1
                            }
                        }
                        
                        // 添加角色按钮 (最多5个)
                        if members.count < 5 {
                            Button(action: addMember) {
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .bold))
                                    .padding(8)
                                    .background(primaryPink.opacity(0.1))
                                    .foregroundColor(primaryPink)
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .padding()
                }
                .background(Color.white)
                .shadow(color: primaryPink.opacity(0.05), radius: 5, x: 0, y: 5)
                
                // 2. 内容区域
                ZStack {
                    bgPink.ignoresSafeArea()
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            if currentStep == 0 {
                                // 世界观设定页
                                VStack(alignment: .leading, spacing: 20) {
                                    Text(LT("Step 1: Set the group background", "ステップ1: グループ背景を設定", "步驟 1：設定群聊背景"))
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(.black.opacity(0.8))
                                    
                                    // 新增：群聊名称
                                    CustomTextField(label: LT("Group chat name", "グループチャット名", "群聊名稱"), placeholder: LT("For example: Hogwarts Trio (optional)", "例: ホグワーツ三人組（任意）", "例如：霍格華茲三人組（選填）"), text: $groupName, height: 44)
                                    
                                    CustomTextField(label: LT("World background", "世界観の背景", "世界觀背景"), placeholder: LT("For example: the magical world of Harry Potter...", "例: ハリー・ポッターの魔法世界...", "例如：哈利波特的魔法世界..."), text: $world, height: 100)
                                    
                                    // 新增：你的名字
                                    CustomTextField(label: LT("Your name", "あなたの名前", "你的名字"), placeholder: LT("For example: Harry", "例: ハリー", "例如：哈利"), text: $userName, height: 44)
                                    
                                    CustomTextField(label: LT("Your role in the group", "グループ内でのあなたの役割", "你在群裡的身份"), placeholder: LT("For example: a new Gryffindor student...", "例: 新入学のグリフィンドール生...", "例如：新入學的葛來分多學生..."), text: $userPersona, height: 80)
                                }
                                .padding(24)
                                .background(Color.white)
                                .cornerRadius(24)
                                .shadow(color: Color.black.opacity(0.02), radius: 10, x: 0, y: 5)
                                .padding()
                                .transition(.opacity)
                            } else {
                                // 角色设定页
                                let memberIndex = currentStep - 1
                                if memberIndex < members.count {
                                    VStack(alignment: .leading, spacing: 20) {
                                        Text("\(LT("Step", "ステップ", "步驟")) \(currentStep + 1): \(LT("Set character", "キャラクターを設定", "設定角色")) \(memberIndex + 1)")
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .foregroundColor(.black.opacity(0.8))
                                        
                                        // 头像选择
                                        HStack {
                                            Text(LT("Avatar", "アバター", "頭像"))
                                                .font(.headline)
                                                .foregroundColor(.gray)
                                            Spacer()
                                            
                                            Button(action: {
                                                editingMemberIndex = memberIndex
                                                showImagePicker = true
                                            }) {
                                                ZStack {
                                                    AvatarView(
                                                        name: members[memberIndex].name.isEmpty ? "?" : members[memberIndex].name,
                                                        color: members[memberIndex].avatarColor,
                                                        size: 64,
                                                        base64: members[memberIndex].avatarBase64
                                                    )
                                                    
                                                    Image(systemName: "camera.fill")
                                                        .foregroundColor(.white)
                                                        .padding(6)
                                                        .background(primaryPink)
                                                        .clipShape(Circle())
                                                        .offset(x: 22, y: 22)
                                                }
                                            }
                                            
                                            // 同时也保留切换颜色的功能，作为一个小选项
                                            Button(action: {
                                                members[memberIndex].avatarColor = members[memberIndex].avatarColor == "blue" ? "pink" : "blue"
                                            }) {
                                                Image(systemName: "paintpalette.fill")
                                                    .foregroundColor(primaryPink.opacity(0.5))
                                                    .font(.system(size: 20))
                                            }
                                            .padding(.leading, 12)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(LT("Name", "名前", "名字")).font(.caption).fontWeight(.bold).foregroundColor(.gray.opacity(0.7))
                                            TextField(LT("For example: Harry Potter", "例: ハリー・ポッター", "例如：哈利・波特"), text: $members[memberIndex].name)
                                                .padding()
                                                .background(Color(UIColor.secondarySystemBackground))
                                                .cornerRadius(12)
                                        }
                                        
                                        CustomTextField(label: LT("Character background", "キャラクター背景", "角色背景"), placeholder: LT("He is a famous wizard...", "彼は有名な魔法使いです...", "他是一個著名的巫師..."), text: $members[memberIndex].intro, height: 80)
                                        
                                        CustomTextField(label: LT("Character personality", "キャラクター性格", "角色性格"), placeholder: LT("Brave, upright, a little impulsive...", "勇敢で正直、少し衝動的...", "勇敢、正直、有些衝動..."), text: $members[memberIndex].personality, height: 60)
                                        
                                        // 删除按钮
                                        if members.count > 1 {
                                            Button(action: { removeMember(at: memberIndex) }) {
                                                HStack {
                                                    Image(systemName: "trash")
                                                    Text(LT("Delete this character", "このキャラクターを削除", "刪除此角色"))
                                                }
                                                .foregroundColor(.red.opacity(0.8))
                                                .font(.system(size: 14, weight: .medium))
                                                .padding(.top, 10)
                                            }
                                        }
                                    }
                                    .padding(24)
                                    .background(Color.white)
                                    .cornerRadius(24)
                                    .shadow(color: Color.black.opacity(0.02), radius: 10, x: 0, y: 5)
                                    .padding()
                                    .transition(.opacity)
                                }
                            }
                        }
                    }
                }
                
                // 3. 底部按钮栏
                HStack(spacing: 16) {
                    if currentStep > 0 {
                        Button(action: { withAnimation { currentStep -= 1 } }) {
                            Text(LT("Previous", "前へ", "上一步"))
                                .fontWeight(.medium)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(16)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    if currentStep < members.count {
                        Button(action: { withAnimation { currentStep += 1 } }) {
                            Text(LT("Next", "次へ", "下一步"))
                                .fontWeight(.bold)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(primaryPink)
                                .cornerRadius(16)
                                .foregroundColor(.white)
                                .shadow(color: primaryPink.opacity(0.3), radius: 5, x: 0, y: 3)
                        }
                    } else {
                        Button(action: createGroupChat) {
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text(LT("Start Chat", "チャット開始", "開始聊天"))
                                    .fontWeight(.bold)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(primaryPink)
                        .cornerRadius(16)
                        .foregroundColor(.white)
                        .shadow(color: primaryPink.opacity(0.3), radius: 5, x: 0, y: 3)
                        .disabled(isLoading || world.isEmpty || members.contains(where: { $0.name.isEmpty }))
                    }
                }
                .padding(20)
                .background(Color.white)
                .shadow(color: Color.black.opacity(0.03), radius: 10, y: -5)
            }
            .navigationTitle(LT("Create Group Chat", "グループチャット作成", "創建群聊"))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Text(LT("Cancel", "キャンセル", "取消")).foregroundColor(.gray)
            })
            .sheet(isPresented: $showImagePicker, onDismiss: processImage) {
                // 重用 CreateView 中定义的 ImagePicker
                ImagePicker(image: $inputImage)
            }
        }
    }
    
    // Logic (Unchanged)
    
    func processImage() {
        guard let inputImage = inputImage, let index = editingMemberIndex else { return }
        
        if let data = inputImage.jpegData(compressionQuality: 0.5) {
            // 更新对应成员的头像
            members[index].avatarBase64 = data.base64EncodedString()
        }
        
        // 重置
        self.inputImage = nil
    }
    
    func addMember() {
        withAnimation {
            members.append(GroupMember(name: "", intro: "", personality: "", avatarColor: "pink"))
            currentStep = members.count // 跳转到新的一页
        }
    }
    
    func removeMember(at index: Int) {
        withAnimation {
            members.remove(at: index)
            if currentStep > members.count {
                currentStep = members.count
            }
        }
    }
    
    func createGroupChat() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        isLoading = true
        
        // 构造群名 (如果有输入则使用输入，否则组合成员名字)
        let finalGroupName = groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? members.map { $0.name }.joined(separator: ", ")
            : groupName
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let currentTime = formatter.string(from: Date())
        
        let newGroup = GroupChatModel(
            id: UUID().uuidString,
            data: [
                "name": finalGroupName,
                "world": world,
                "userName": userName, // 保存用户名字
                "userPersona": userPersona,
                "members": members.map { $0.toDictionary() },
                "createdAt": Timestamp(date: Date()),
                "virtualTime": currentTime,
                "location": localizedInitialLocation()
            ]
        )
        
        var ref: DocumentReference? = nil
        ref = db.collection("users").document(uid).collection("groups").addDocument(data: newGroup.toDictionary()) { error in
            isLoading = false
            if error == nil {
                // Return created group with ID
                var finalGroup = newGroup
                if let docId = ref?.documentID {
                    finalGroup.id = docId
                }
                onCreate?(finalGroup)
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

// UI Components

struct StepTab: View {
    let title: String
    let isActive: Bool
    let index: Int
    let action: () -> Void
    
    // Theme color
    let primaryPink = Color(red: 1.0, green: 0.45, blue: 0.65)
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 13))
                    .fontWeight(isActive ? .bold : .medium)
                    .foregroundColor(isActive ? primaryPink : .gray.opacity(0.8))
                
                Rectangle()
                    .fill(isActive ? primaryPink : Color.clear)
                    .frame(height: 3)
                    .cornerRadius(1.5)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isActive ? primaryPink.opacity(0.08) : Color.clear)
            .cornerRadius(10)
        }
    }
}

struct CustomTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var height: CGFloat = 44
    @State private var measuredHeight: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.gray.opacity(0.7))

            if height > 50 {
                // Multi-line: auto wrap + auto grow (instead of fixed height)
                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(placeholder)
                            .foregroundColor(.gray.opacity(0.55))
                            .padding(.top, 14)
                            .padding(.leading, 12)
                    }

                    GC_GrowingTextView(text: $text, measuredHeight: $measuredHeight, minHeight: height, maxHeight: 260)
                        .frame(height: max(measuredHeight, height))
                        .padding(8)
                }
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
            } else {
                TextField(placeholder, text: $text)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
            }
        }
    }
}

// UIKit-backed multi-line input that auto-wraps and auto-grows.
// Used only inside GroupCreateView's CustomTextField when height > 50.
struct GC_GrowingTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var measuredHeight: CGFloat

    var minHeight: CGFloat
    var maxHeight: CGFloat

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.backgroundColor = .clear
        tv.font = UIFont.systemFont(ofSize: 16)
        tv.textColor = UIColor.label
        tv.isScrollEnabled = false
        tv.delegate = context.coordinator
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 2, bottom: 8, right: 2)
        tv.textContainer.lineFragmentPadding = 0
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        // Always point the coordinator at the latest bindings (important when SwiftUI reuses views).
        context.coordinator.textBinding = $text
        context.coordinator.heightBinding = $measuredHeight
        context.coordinator.minHeight = minHeight
        context.coordinator.maxHeight = maxHeight

        // Prevent delegate callbacks from writing back while we set text programmatically.
        context.coordinator.isProgrammaticUpdate = true
        if uiView.text != text {
            uiView.text = text
        }
        context.coordinator.isProgrammaticUpdate = false

        recalcHeight(view: uiView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(textBinding: $text, heightBinding: $measuredHeight, minHeight: minHeight, maxHeight: maxHeight)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        // These bindings MUST be updated from updateUIView because SwiftUI may reuse the underlying UITextView.
        var textBinding: Binding<String>
        var heightBinding: Binding<CGFloat>
        var minHeight: CGFloat
        var maxHeight: CGFloat

        var isProgrammaticUpdate: Bool = false

        init(textBinding: Binding<String>, heightBinding: Binding<CGFloat>, minHeight: CGFloat, maxHeight: CGFloat) {
            self.textBinding = textBinding
            self.heightBinding = heightBinding
            self.minHeight = minHeight
            self.maxHeight = maxHeight
        }

        func textViewDidChange(_ textView: UITextView) {
            // Ignore changes triggered by programmatic text assignment during view reuse.
            if isProgrammaticUpdate { return }

            textBinding.wrappedValue = textView.text

            // Recalculate height using the same clamp rules as the parent.
            let targetSize = CGSize(width: textView.bounds.width, height: .greatestFiniteMagnitude)
            let fittingSize = textView.sizeThatFits(targetSize)

            let clamped = min(max(fittingSize.height, minHeight), maxHeight)
            textView.isScrollEnabled = fittingSize.height > maxHeight

            if heightBinding.wrappedValue != clamped {
                DispatchQueue.main.async {
                    self.heightBinding.wrappedValue = clamped
                }
            }
        }
    }

    private func recalcHeight(view: UITextView) {
        // Compute wrapped height based on current width.
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
