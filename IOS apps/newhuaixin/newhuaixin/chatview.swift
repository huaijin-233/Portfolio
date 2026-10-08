
import SwiftUI
import UIKit
import Combine

// MARK: - Chat List View (Tab 1)

struct ChatListView: View {
    // 0 = 单聊, 1 = 群聊
    @State private var chatType: Int = 0
    
    @State private var activeChats: [CharacterModel] = []
    @State private var activeGroups: [GroupChatModel] = []
    
    @State private var showCreateSheet = false
    @State private var showGroupCreateSheet = false
    
    // Navigation programmatic state
    @State private var navCharacter: CharacterModel?
    @State private var navGroup: GroupChatModel?
    @State private var navigateToChar = false
    @State private var navigateToGroup = false
    
    private let db = Firestore.firestore()
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Programmatic navigation links (Hidden)
                if let char = navCharacter {
                    NavigationLink(destination: ChatView(character: char), isActive: $navigateToChar) { EmptyView() }
                }
                if let group = navGroup {
                    NavigationLink(destination: GroupChatView(group: group), isActive: $navigateToGroup) { EmptyView() }
                }
                
                VStack(spacing: 0) {
                    // 切换器
                    Picker("Chat Type", selection: $chatType) {
                        Text(LT("Direct", "個別", "單聊")).tag(0)
                        Text(LT("Group", "グループ", "群聊")).tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    
                    if chatType == 0 {
                        // 单聊列表
                        List {
                            ForEach(activeChats) { char in
                                NavigationLink(destination: ChatView(character: char)) {
                                    HStack(spacing: 16) {
                                        AvatarView(name: char.name, color: char.avatarColor, size: 52, base64: char.avatarBase64)
                                        VStack(alignment: .leading, spacing: 6) {
                                            HStack {
                                                Text(char.name)
                                                    .font(.system(size: 17, weight: .semibold))
                                                    .foregroundColor(.primary)
                                                Spacer()
                                                if let time = char.lastMessageTime {
                                                    Text(timeFormatter.string(from: time))
                                                        .font(.system(size: 12))
                                                        .foregroundColor(.gray.opacity(0.8))
                                                }
                                            }
                                            Text(char.lastMessage ?? "")
                                                .font(.system(size: 14))
                                                .foregroundColor(.gray)
                                                .lineLimit(1)
                                        }

                                        if char.unreadCount > 0 {
                                            ZStack {
                                                Circle()
                                                    .fill(Color.red)
                                                Text(char.unreadCount > 99 ? "99+" : "\(char.unreadCount)")
                                                    .font(.system(size: char.unreadCount > 99 ? 9 : 11, weight: .bold))
                                                    .foregroundColor(.white)
                                            }
                                            .frame(width: 22, height: 22)
                                        }
                                    }
                                    .padding(.vertical, 6)
                                }
                            }
                            .onDelete(perform: deleteChat)
                        }
                        .listStyle(PlainListStyle())
                    } else {
                        // 群聊列表
                        List {
                            ForEach(activeGroups) { group in
                                NavigationLink(destination: GroupChatView(group: group)) {
                                    HStack(spacing: 16) {
                                        ZStack {
                                            Circle().fill(Color.pink.opacity(0.08))
                                            Image(systemName: "person.3.fill")
                                                .foregroundColor(.pink.opacity(0.8))
                                                .font(.system(size: 20))
                                        }
                                        .frame(width: 52, height: 52)
                                        
                                        VStack(alignment: .leading, spacing: 6) {
                                            HStack {
                                                Text(group.name)
                                                    .font(.system(size: 17, weight: .semibold))
                                                    .lineLimit(1)
                                                Spacer()
                                                if let time = group.lastMessageTime {
                                                    Text(timeFormatter.string(from: time))
                                                        .font(.system(size: 12))
                                                        .foregroundColor(.gray.opacity(0.8))
                                                }
                                            }
                                            Text(group.lastMessage ?? LT("Group chat created", "グループチャットが作成されました", "群聊已創建"))
                                                .font(.system(size: 14))
                                                .foregroundColor(.gray)
                                                .lineLimit(1)
                                        }
                                    }
                                    .padding(.vertical, 6)
                                }
                            }
                            .onDelete(perform: deleteGroup)
                        }
                        .listStyle(PlainListStyle())
                    }
                }
            }
            .navigationTitle(LT("Chat", "チャット", "聊天"))
            .navigationBarItems(
                leading: Button(action: { showGroupCreateSheet = true }) {
                    Image(systemName: "person.2.badge.plus.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.pink)
                },
                trailing: Button(action: { showCreateSheet = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.pink)
                }
            )
            .sheet(isPresented: $showCreateSheet) {
                CreateView(onCreate: { newChar in
                    // Automatically navigate to new chat
                    self.navCharacter = newChar
                    // Delay slightly to allow sheet to dismiss completely
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.navigateToChar = true
                    }
                })
            }
            .sheet(isPresented: $showGroupCreateSheet) {
                GroupCreateView(onCreate: { newGroup in
                    // Automatically navigate to new group chat
                    self.navGroup = newGroup
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.navigateToGroup = true
                    }
                })
            }
        }
        .onAppear {
            fetchActiveChats()
            fetchActiveGroups()
        }
    }
    
    func fetchActiveChats() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(uid).collection("characters")
            .order(by: "lastMessageTime", descending: true)
            .addSnapshotListener { snapshot, _ in
                guard let documents = snapshot?.documents else { return }
                self.activeChats = documents.map { CharacterModel(id: $0.documentID, data: $0.data() ?? [:]) }.filter { $0.lastMessage != nil }
            }
    }
    
    func fetchActiveGroups() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(uid).collection("groups")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, _ in
                guard let documents = snapshot?.documents else { return }
                self.activeGroups = documents.map { GroupChatModel(id: $0.documentID, data: $0.data() ?? [:]) }
            }
    }
    
    func deleteChat(at offsets: IndexSet) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        offsets.forEach { index in
            let charId = activeChats[index].id
            let charRef = db.collection("users").document(uid).collection("characters").document(charId)
            
            charRef.updateData([
                "lastMessage": FieldValue.delete(),
                "lastMessageTime": FieldValue.delete(),
                "currentThought": FieldValue.delete()
            ])
            
            charRef.collection("messages").getDocuments { snapshot, error in
                guard let documents = snapshot?.documents else { return }
                let batch = db.batch()
                for doc in documents {
                    batch.deleteDocument(doc.reference)
                }
                batch.commit()
            }
        }
    }
    
    func deleteGroup(at offsets: IndexSet) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        offsets.forEach { index in
            let groupId = activeGroups[index].id
            let groupRef = db.collection("users").document(uid).collection("groups").document(groupId)
            
            groupRef.collection("messages").getDocuments { snapshot, error in
                guard let documents = snapshot?.documents else { return }
                let batch = db.batch()
                for doc in documents {
                    batch.deleteDocument(doc.reference)
                }
                batch.commit { _ in
                    groupRef.delete()
                }
            }
        }
    }
}

// MARK: - Floating Space-Time Capsule (AssistiveTouch Style)

struct FloatingSpaceTimeCapsule: View {
    @Binding var time: String
    @Binding var location: String
    var onUpdate: () -> Void
    
    // Position State (Default to top right ish)
    @State private var position: CGPoint = CGPoint(x: UIScreen.main.bounds.width - 80, y: 120)
    @State private var isExpanded: Bool = false
    @State private var minuteTicker = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // 1. The Edit Panel Overlay (Modal)
            if isExpanded {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        closePanel()
                    }
                    .zIndex(100)
                
                VStack(spacing: 20) {
                    // Header
                    HStack {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(.white)
                        Text(LT("Time & Space", "時空調整", "時空調整"))
                            .font(.headline)
                            .foregroundColor(.white)
                            .fontWeight(.bold)
                        Spacer()
                        Button(action: closePanel) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    
                    // Time Picker
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.white.opacity(0.8))
                        DatePicker("", selection: Binding(
                            get: {
                                let formatter = DateFormatter()
                                formatter.dateFormat = "HH:mm"
                                return formatter.date(from: time) ?? Date()
                            },
                            set: { newVal in
                                let formatter = DateFormatter()
                                formatter.dateFormat = "HH:mm"
                                time = formatter.string(from: newVal)
                            }
                        ), displayedComponents: .hourAndMinute)
                        .datePickerStyle(WheelDatePickerStyle())
                        .labelsHidden()
                        .colorScheme(.dark) // White text for picker
                        .frame(height: 100)
                        .clipped()
                    }
                    .padding(.horizontal)
                    
                    // Location Input
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.white.opacity(0.8))
                        TextField(LT("Current location", "現在地", "當前地點"), text: $location)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(8)
                    }
                    
                    Button(action: closePanel) {
                        Text(LT("Confirm", "確認", "確定"))
                            .fontWeight(.bold)
                            .foregroundColor(Color(red: 1.0, green: 0.45, blue: 0.65))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .cornerRadius(12)
                    }
                }
                .padding(24)
                .frame(width: 300)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(red: 1.0, green: 0.45, blue: 0.65).opacity(0.95))
                        .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
                )
                .zIndex(101)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
            
            // 2. The Floating Capsule Button
            if !isExpanded {
                HStack(spacing: 6) {
                    Text(time)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                    
                    Text("·")
                    
                    Text(localizedLocationValue(location))
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: 90)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundColor(.white)
                .background(
                    Capsule()
                        .fill(Color(red: 1.0, green: 0.45, blue: 0.65).opacity(0.85))
                        .shadow(color: Color(red: 1.0, green: 0.45, blue: 0.65).opacity(0.4), radius: 8, x: 0, y: 4)
                )
                .position(position)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            position = value.location
                        }
                        .onEnded { value in
                            withAnimation(.spring()) {
                                // Clamp to screen bounds
                                let w = UIScreen.main.bounds.width
                                let h = UIScreen.main.bounds.height
                                let x = min(max(value.location.x, 40), w - 40)
                                let y = min(max(value.location.y, 100), h - 100)
                                position = CGPoint(x: x, y: y)
                            }
                        }
                )
                .onTapGesture {
                    withAnimation(.spring()) {
                        isExpanded = true
                    }
                }
                .zIndex(99)
            }
        }
        .onReceive(minuteTicker) { _ in
            // Pause ticking while editing to avoid fighting user input
            guard !isExpanded else { return }
            time = incrementOneMinute(time)
        }
    }
    
    func closePanel() {
        withAnimation {
            isExpanded = false
            onUpdate()
        }
    }

    func incrementOneMinute(_ current: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        guard let date = formatter.date(from: current) else {
            return current
        }

        if let next = Calendar.current.date(byAdding: .minute, value: 1, to: date) {
            return formatter.string(from: next)
        }

        return current
    }
}

// MARK: - Single Chat View

struct ChatView: View {
    let character: CharacterModel
    @State private var messages: [MessageModel] = []
    @State private var currentThought: String = ""
    
    @State private var inputText = ""
    @State private var selectedRange: NSRange? = nil
    
    @State private var isSending = false
    @State private var showAlert = false
    @State private var showActionToast = false
    
    // Time & Space State
    @State private var virtualTime: String = "09:00"
    @State private var location: String = localizedUnknownLocation()
    
    private let db = Firestore.firestore()
    
    // UI Constants
    private let chatBackground = Color(red: 0.98, green: 0.96, blue: 0.97) // Soft Pinkish White
    private let userBubbleColor = Color(red: 1.0, green: 0.45, blue: 0.65) // Elegant Pink
    
    var body: some View {
        ZStack(alignment: .top) {
            chatBackground.ignoresSafeArea() // Background
            
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        // Spacer for Pill safety
                        Spacer().frame(height: 20)
                        
                        LazyVStack(spacing: 16) { // Increased spacing for cleaner look
                            ForEach(messages) { msg in
                                HStack(alignment: .bottom, spacing: 10) {
                                    if msg.role == "user" {
                                        Spacer()
                                        Text(msg.content)
                                            .font(.system(size: 16))
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 12)
                                            .background(userBubbleColor)
                                            .foregroundColor(.white)
                                            .cornerRadius(20)
                                            .cornerRadius(4, corners: .bottomRight)
                                            .shadow(color: userBubbleColor.opacity(0.3), radius: 4, x: 0, y: 2)
                                            .contextMenu {
                                                Button(role: .destructive) {
                                                    deleteMessage(msg)
                                                } label: {
                                                    Label(LT("Delete", "削除", "刪除"), systemImage: "trash")
                                                }
                                            }
                                    } else {
                                        AvatarView(name: character.name, color: character.avatarColor, size: 34, base64: character.avatarBase64)
                                        Text(msg.content)
                                            .font(.system(size: 16))
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 12)
                                            .background(Color.white)
                                            .foregroundColor(.black.opacity(0.85))
                                            .cornerRadius(20)
                                            .cornerRadius(4, corners: .bottomLeft)
                                            .shadow(color: Color.black.opacity(0.06), radius: 3, x: 0, y: 1)
                                            .contextMenu {
                                                Button(role: .destructive) {
                                                    deleteMessage(msg)
                                                } label: {
                                                    Label(LT("Delete", "削除", "刪除"), systemImage: "trash")
                                                }
                                            }
                                        Spacer()
                                    }
                                }
                                .padding(.horizontal, 16)
                                .id(msg.id)
                            }
                        }
                        .padding(.vertical, 20)
                    }
                    .onChange(of: messages.count) { _ in
                        if let lastId = messages.last?.id { withAnimation { proxy.scrollTo(lastId, anchor: .bottom) } }
                    }
                }
                
                if isSending {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("\(character.name) \(LT("is typing...", "が入力中…", "正在輸入..."))")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    .padding(.bottom, 8)
                    .transition(.opacity)
                }
                
                InputArea(
                    inputText: $inputText,
                    selectedRange: $selectedRange,
                    isSending: isSending,
                    onSend: checkLimitAndSend,
                    onInsertAction: triggerActionToast
                )
            }
            
            // Toast 提示
            if showActionToast {
                VStack {
                    Spacer()
                    Text(LT("Please enter your action inside 【】", "【】の中にあなたの行動を書いてください", "請在框【】中輸入你的動作和行為"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(25)
                        .padding(.bottom, 90)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .allowsHitTesting(false)
                .zIndex(50)
            }
            
            // New Floating Pill
            FloatingSpaceTimeCapsule(
                time: $virtualTime,
                location: $location,
                onUpdate: updateContext
            )
            .zIndex(100) // Highest Z
        }
        .navigationTitle(character.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            listenToMessages()
            loadContext()
            clearUnreadCount()
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(LT("Free messages used up", "無料メッセージを使い切りました", "免費次數已用完")),
                message: Text(LT("Please check in to get more free messages.", "チェックインして無料メッセージを増やしてください。", "請通過簽到獲取更多免費次數。")),
                dismissButton: .default(Text(LT("OK", "OK", "知道了")))
            )
        }
    }
    
    func loadContext() {
        self.virtualTime = character.virtualTime
        self.location = localizedLocationValue(character.location)
        self.currentThought = character.currentThought ?? ""
    }
    
    func updateContext() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(uid).collection("characters").document(character.id).updateData([
            "virtualTime": virtualTime,
            "location": location
        ])
    }

    func clearUnreadCount() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(uid).collection("characters").document(character.id).updateData([
            "unreadCount": 0
        ])
    }
    
    func listenToMessages() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(uid).collection("characters").document(character.id).collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                self.messages = docs.map { MessageModel(id: $0.documentID, data: $0.data() ?? [:]) }
            }
    }
    
    func deleteMessage(_ msg: MessageModel) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(uid)
            .collection("characters").document(character.id)
            .collection("messages").document(msg.id).delete()
    }
    
    func checkLimitAndSend() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        let userRef = db.collection("users").document(uid)
        userRef.getDocument { snapshot, _ in
            let count = snapshot?.data()?["freeMessageCount"] as? Int ?? 0
            if count > 0 {
                userRef.updateData(["freeMessageCount": FieldValue.increment(Int64(-1))])
                self.sendMessage()
            } else {
                self.showAlert = true
            }
        }
    }
    
    func sendMessage() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        inputText = ""
        isSending = true
        
        let userMsg = MessageModel(role: "user", content: text, timestamp: Date())
        let charRef = db.collection("users").document(uid).collection("characters").document(character.id)
        
        charRef.collection("messages").addDocument(data: userMsg.toDictionary())
        charRef.updateData(["lastMessage": text, "lastMessageTime": Timestamp(date: Date())])
        
        AIService.shared.sendMessage(character: character, history: messages, userMessage: text, virtualTime: virtualTime, location: location, currentThought: currentThought) { result in
            guard let result = result else {
                self.isSending = false
                return
            }

            if let updatedThought = result.thought, !updatedThought.isEmpty {
                self.currentThought = updatedThought
                charRef.updateData(["currentThought": updatedThought])
            }

            self.sendNextMessage(index: 0, responses: result.messages, charRef: charRef)
        }
    }
    
    func sendNextMessage(index: Int, responses: [String], charRef: DocumentReference) {
        if index >= responses.count {
            self.isSending = false
            return
        }
        
        let text = responses[index]
        let delay = min(1.0 + Double(text.count) * 0.05, 4.0)
        let finalDelay = Double.random(in: 0.5...1.0) + delay
        
        DispatchQueue.main.asyncAfter(deadline: .now() + finalDelay) {
            let timestamp = Date()
            let aiMsg = MessageModel(role: "ai", content: text, timestamp: timestamp)
            
            charRef.collection("messages").addDocument(data: aiMsg.toDictionary())
            
            if index == responses.count - 1 {
                charRef.updateData(["lastMessage": text, "lastMessageTime": Timestamp(date: timestamp)])
            }
            
            self.sendNextMessage(index: index + 1, responses: responses, charRef: charRef)
        }
    }
    
    func triggerActionToast() {
        withAnimation(.spring()) {
            showActionToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut) {
                showActionToast = false
            }
        }
    }
}

// MARK: - Group Chat View

struct GroupChatView: View {
    let group: GroupChatModel
    @State private var messages: [MessageModel] = []
    
    @State private var inputText = ""
    @State private var selectedRange: NSRange? = nil
    
    @State private var isSending = false
    @State private var showAlert = false
    @State private var showActionToast = false
    
    // Time & Space State
    @State private var virtualTime: String = "09:00"
    @State private var location: String = localizedUnknownLocation()
    
    private let db = Firestore.firestore()
    
    // UI Constants
    private let chatBackground = Color(red: 0.98, green: 0.96, blue: 0.97)
    private let userBubbleColor = Color(red: 1.0, green: 0.45, blue: 0.65)
    
    var body: some View {
        ZStack(alignment: .top) {
            chatBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        Spacer().frame(height: 20)
                        
                        LazyVStack(spacing: 16) {
                            ForEach(messages) { msg in
                                HStack(alignment: .bottom, spacing: 10) {
                                    if msg.role == "user" {
                                        Spacer()
                                        Text(msg.content)
                                            .font(.system(size: 16))
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 12)
                                            .background(userBubbleColor)
                                            .foregroundColor(.white)
                                            .cornerRadius(20)
                                            .cornerRadius(4, corners: .bottomRight)
                                            .shadow(color: userBubbleColor.opacity(0.3), radius: 4, x: 0, y: 2)
                                            .contextMenu {
                                                Button(role: .destructive) {
                                                    deleteMessage(msg)
                                                } label: {
                                                    Label(LT("Delete", "削除", "刪除"), systemImage: "trash")
                                                }
                                            }
                                    } else {
                                        let member = group.members.first(where: { $0.name == msg.senderName })
                                        AvatarView(name: msg.senderName ?? "?", color: member?.avatarColor ?? "blue", size: 34, base64: member?.avatarBase64)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            if let name = msg.senderName {
                                                Text(name)
                                                    .font(.system(size: 11))
                                                    .foregroundColor(.gray.opacity(0.8))
                                                    .padding(.leading, 2)
                                            }
                                            Text(msg.content)
                                                .font(.system(size: 16))
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 12)
                                                .background(Color.white)
                                                .foregroundColor(.black.opacity(0.85))
                                                .cornerRadius(20)
                                                .cornerRadius(4, corners: .bottomLeft)
                                                .shadow(color: Color.black.opacity(0.06), radius: 3, x: 0, y: 1)
                                                .contextMenu {
                                                    Button(role: .destructive) {
                                                        deleteMessage(msg)
                                                    } label: {
                                                        Label(LT("Delete", "削除", "刪除"), systemImage: "trash")
                                                    }
                                                }
                                        }
                                        Spacer()
                                    }
                                }
                                .padding(.horizontal, 16)
                                .id(msg.id)
                            }
                        }
                        .padding(.vertical, 20)
                    }
                    .onChange(of: messages.count) { _ in
                        if let lastId = messages.last?.id { withAnimation { proxy.scrollTo(lastId, anchor: .bottom) } }
                    }
                }
                
                if isSending {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text(LT("Group members are typing...", "グループメンバーが入力中…", "群成員正在輸入..."))
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    .padding(.bottom, 8)
                    .transition(.opacity)
                }
                
                InputArea(
                    inputText: $inputText,
                    selectedRange: $selectedRange,
                    isSending: isSending,
                    onSend: checkLimitAndSend,
                    onInsertAction: triggerActionToast
                )
            }
            
            // Toast
            if showActionToast {
                VStack {
                    Spacer()
                    Text(LT("Please enter your action inside 【】", "【】の中にあなたの行動を書いてください", "請在框【】中輸入你的動作和行為"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(25)
                        .padding(.bottom, 90)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .allowsHitTesting(false)
                .zIndex(50)
            }
            
            // New Floating Pill
            FloatingSpaceTimeCapsule(
                time: $virtualTime,
                location: $location,
                onUpdate: updateContext
            )
            .zIndex(100)
        }
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            listenToMessages()
            loadContext()
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(LT("Free messages used up", "無料メッセージを使い切りました", "免費次數已用完")),
                message: Text(LT("Please check in to get more free messages.", "チェックインして無料メッセージを増やしてください。", "請通過簽到獲取更多免費次數。")),
                dismissButton: .default(Text(LT("OK", "OK", "知道了")))
            )
        }
    }
    
    func loadContext() {
        self.virtualTime = group.virtualTime
        self.location = localizedLocationValue(group.location)
    }
    
    func updateContext() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(uid).collection("groups").document(group.id).updateData([
            "virtualTime": virtualTime,
            "location": location
        ])
    }
    
    func listenToMessages() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(uid).collection("groups").document(group.id).collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                self.messages = docs.map { MessageModel(id: $0.documentID, data: $0.data() ?? [:]) }
            }
    }
    
    func deleteMessage(_ msg: MessageModel) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(uid)
            .collection("groups").document(group.id)
            .collection("messages").document(msg.id).delete()
    }
    
    func checkLimitAndSend() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        let userRef = db.collection("users").document(uid)
        userRef.getDocument { snapshot, _ in
            let count = snapshot?.data()?["freeMessageCount"] as? Int ?? 0
            if count > 0 {
                userRef.updateData(["freeMessageCount": FieldValue.increment(Int64(-1))])
                self.sendMessage()
            } else {
                self.showAlert = true
            }
        }
    }
    
    func sendMessage() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        inputText = ""
        isSending = true
        
        let groupRef = db.collection("users").document(uid).collection("groups").document(group.id)
        
        let userMsg = MessageModel(role: "user", senderName: localizedMeText(), content: text, timestamp: Date())
        groupRef.collection("messages").addDocument(data: userMsg.toDictionary())
        groupRef.updateData(["lastMessage": text, "lastMessageTime": Timestamp(date: Date())])
        
        triggerMemberResponses(index: 0, currentHistory: self.messages + [userMsg], groupRef: groupRef)
    }
    
    func triggerMemberResponses(index: Int, currentHistory: [MessageModel], groupRef: DocumentReference) {
        if index >= group.members.count {
            self.isSending = false
            return
        }
        
        let member = group.members[index]
        
        AIService.shared.sendGroupMessage(targetMember: member, groupContext: group, history: currentHistory, virtualTime: virtualTime, location: location) { responses in
            guard let responses = responses, !responses.isEmpty else {
                self.triggerMemberResponses(index: index + 1, currentHistory: currentHistory, groupRef: groupRef)
                return
            }
            
            self.sendMemberMessagesRecursive(
                responses: responses,
                msgIndex: 0,
                member: member,
                groupRef: groupRef,
                currentHistory: currentHistory
            ) { updatedHistory in
                let interMemberDelay = Double.random(in: 1.5...3.0)
                DispatchQueue.main.asyncAfter(deadline: .now() + interMemberDelay) {
                    self.triggerMemberResponses(index: index + 1, currentHistory: updatedHistory, groupRef: groupRef)
                }
            }
        }
    }
    
    func sendMemberMessagesRecursive(
        responses: [String],
        msgIndex: Int,
        member: GroupMember,
        groupRef: DocumentReference,
        currentHistory: [MessageModel],
        completion: @escaping ([MessageModel]) -> Void
    ) {
        if msgIndex >= responses.count {
            completion(currentHistory)
            return
        }

        let rawText = responses[msgIndex]
        let text = sanitizeGroupAIText(rawText, memberName: member.name)
        let delay = min(1.0 + Double(text.count) * 0.05, 4.0)
        let finalDelay = Double.random(in: 0.5...1.0) + delay

        DispatchQueue.main.asyncAfter(deadline: .now() + finalDelay) {
            let timestamp = Date()
            let aiMsg = MessageModel(role: "ai", senderName: member.name, content: text, timestamp: timestamp)
            groupRef.collection("messages").addDocument(data: aiMsg.toDictionary())
            groupRef.updateData(["lastMessage": "\(member.name): \(text)", "lastMessageTime": Timestamp(date: timestamp)])

            var nextHistory = currentHistory
            nextHistory.append(aiMsg)

            self.sendMemberMessagesRecursive(
                responses: responses,
                msgIndex: msgIndex + 1,
                member: member,
                groupRef: groupRef,
                currentHistory: nextHistory,
                completion: completion
            )
        }
    }

    // Remove duplicated speaker prefix returned by the model in group chat.
    // UI already shows senderName separately.
    func sanitizeGroupAIText(_ text: String, memberName: String) -> String {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Common prefixes like "李可可：..." or "【李可可】：..." or "[李可可]: ..."
        let candidates = [
            "\(memberName)：",
            "\(memberName):",
            "【\(memberName)】：",
            "【\(memberName)】:",
            "[\(memberName)]：",
            "[\(memberName)]:"
        ]

        for p in candidates {
            if s.hasPrefix(p) {
                s.removeFirst(p.count)
                break
            }
        }

        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func triggerActionToast() {
        withAnimation(.spring()) {
            showActionToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut) {
                showActionToast = false
            }
        }
    }
}

// MARK: - Input Area Components

// A wrapper for UITextView that supports auto-growing height and multiline input
struct ChatInputTextField: UIViewRepresentable {
    @Binding var text: String
    @Binding var selectedRange: NSRange?
    @Binding var dynamicHeight: CGFloat
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.systemFont(ofSize: 17)
        textView.backgroundColor = .clear
        textView.isScrollEnabled = false // Initially false to allow sizeThatFits to work for auto-growth
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 5, bottom: 8, right: 5)
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal) // Prevent horizontal expansion
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.isUpdatingFromSwiftUI = true
        defer { context.coordinator.isUpdatingFromSwiftUI = false }

        if uiView.text != text {
            uiView.text = text
        }
        
        if let range = selectedRange {
             if uiView.selectedRange.location != range.location || uiView.selectedRange.length != range.length {
                 uiView.selectedRange = range
             }
        }
        
        DispatchQueue.main.async {
            let fixedWidth = uiView.frame.size.width
            let newSize = uiView.sizeThatFits(CGSize(width: fixedWidth, height: CGFloat.greatestFiniteMagnitude))
            let maxHeight: CGFloat = 100 // Maximum height before scrolling
            let minHeight: CGFloat = 38
            
            if newSize.height >= maxHeight {
                if !uiView.isScrollEnabled {
                    uiView.isScrollEnabled = true
                }
                if self.dynamicHeight != maxHeight {
                    self.dynamicHeight = maxHeight
                }
            } else {
                if uiView.isScrollEnabled {
                    uiView.isScrollEnabled = false
                }
                let targetH = max(newSize.height, minHeight)
                if abs(self.dynamicHeight - targetH) > 2 {
                    self.dynamicHeight = targetH
                }
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: ChatInputTextField
        var isUpdatingFromSwiftUI = false
        
        init(_ parent: ChatInputTextField) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            guard !isUpdatingFromSwiftUI else { return }
            parent.text = textView.text
            let range = textView.selectedRange
            DispatchQueue.main.async {
                if self.parent.selectedRange != range {
                    self.parent.selectedRange = range
                }
            }
        }
        
        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !isUpdatingFromSwiftUI else { return }
            let range = textView.selectedRange
            DispatchQueue.main.async {
                if self.parent.selectedRange != range {
                    self.parent.selectedRange = range
                }
            }
        }
    }
}

struct InputArea: View {
    @Binding var inputText: String
    @Binding var selectedRange: NSRange?
    var isSending: Bool
    var onSend: () -> Void
    var onInsertAction: (() -> Void)?
    
    @State private var inputHeight: CGFloat = 38
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            // Text Input
            ZStack(alignment: .leading) {
                if inputText.isEmpty {
                    Text(LT("Type a message...", "メッセージを入力...", "發消息..."))
                        .font(.system(size: 17))
                        .foregroundColor(.gray.opacity(0.6))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                }
                
                ChatInputTextField(
                    text: $inputText,
                    selectedRange: $selectedRange,
                    dynamicHeight: $inputHeight
                )
                .frame(height: inputHeight)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(red: 0.96, green: 0.96, blue: 0.96)) // Softer gray input background
            .cornerRadius(24)
            .frame(maxWidth: .infinity) // Ensure container uses available width
            // .disabled(isSending) - Removed to allow typing while sending
            
            // Action Button
            Button(action: insertAction) {
                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.pink)
                    .frame(width: 44, height: 44)
                    .background(Color.pink.opacity(0.1))
                    .clipShape(Circle())
            }
            .padding(.bottom, 2)
            // .disabled(isSending) - Removed to allow typing while sending
            
            // Send Button
            if !inputText.isEmpty {
                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 38))
                        .foregroundColor(.pink) // Always pink if has text
                        .shadow(color: .pink.opacity(0.2), radius: 3, x: 0, y: 2)
                }
                .padding(.bottom, 2)
                // .disabled(isSending) - Removed to allow multiple messages
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6) // Add bottom padding for safety
        .background(Color.white)
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: -2) // Subtle top shadow
    }
    
    func insertAction() {
        if inputText.isEmpty {
            inputText = "【】"
            selectedRange = NSRange(location: 1, length: 0)
        } else {
            // Insert at current cursor position if possible, else append
            if let range = selectedRange, range.location <= inputText.count {
                let index = inputText.index(inputText.startIndex, offsetBy: range.location)
                inputText.insert(contentsOf: "【】", at: index)
                selectedRange = NSRange(location: range.location + 1, length: 0)
            } else {
                inputText += "【】"
                let length = inputText.utf16.count
                selectedRange = NSRange(location: length - 1, length: 0)
            }
        }
        onInsertAction?()
    }
}

// Helper
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
