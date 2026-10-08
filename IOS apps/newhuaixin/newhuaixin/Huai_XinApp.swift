//
//  Huai_XinApp.swift
//  Huai Xin
//
//  Created by Huaijin233 on 2/2/26.
import SwiftUI
import Combine

// MARK: - 1. Global Models

struct CharacterModel: Identifiable, Codable {
    var id: String
    var name: String
    var world: String
    var intro: String
    var personality: String
    var userName: String
    var userPersona: String
    var relationship: String
    var avatarColor: String
    var avatarBase64: String
    var createdAt: Date
    var lastMessage: String?
    var lastMessageTime: Date?
    var unreadCount: Int
    var currentThought: String?
    
    // New Fields for Virtual Time & Space
    var virtualTime: String     // Format: "HH:mm"
    var location: String        // Location text
    
    init(id: String, data: [String: Any]) {
        self.id = id
        self.name = data["name"] as? String ?? ""
        self.world = data["world"] as? String ?? ""
        self.intro = data["intro"] as? String ?? ""
        self.personality = data["personality"] as? String ?? ""
        self.userName = data["userName"] as? String ?? ""
        self.userPersona = data["userPersona"] as? String ?? ""
        self.relationship = data["relationship"] as? String ?? ""
        self.avatarColor = data["avatarColor"] as? String ?? "pink"
        self.avatarBase64 = data["avatarBase64"] as? String ?? ""
        
        if let timestamp = data["createdAt"] as? Timestamp {
            self.createdAt = timestamp.dateValue()
        } else {
            self.createdAt = Date()
        }
        
        self.lastMessage = data["lastMessage"] as? String
        self.unreadCount = data["unreadCount"] as? Int ?? 0
        self.currentThought = data["currentThought"] as? String
        
        if let lastMsgTs = data["lastMessageTime"] as? Timestamp {
            self.lastMessageTime = lastMsgTs.dateValue()
        } else {
            self.lastMessageTime = nil
        }
        
        // Initialize new fields
        self.virtualTime = data["virtualTime"] as? String ?? "09:00"
        self.location = localizedLocationValue(data["location"] as? String ?? localizedUnknownLocation())
    }
    
    // Updated init with new fields
    init(id: String = "", name: String, world: String, intro: String, personality: String, userName: String = "", userPersona: String = "", relationship: String = "", avatarColor: String, avatarBase64: String = "", createdAt: Date, lastMessage: String? = nil, lastMessageTime: Date? = nil, unreadCount: Int = 0, currentThought: String? = nil, virtualTime: String = "09:00", location: String = localizedUnknownLocation()) {
        self.id = id
        self.name = name
        self.world = world
        self.intro = intro
        self.personality = personality
        self.userName = userName
        self.userPersona = userPersona
        self.relationship = relationship
        self.avatarColor = avatarColor
        self.avatarBase64 = avatarBase64
        self.createdAt = createdAt
        self.lastMessage = lastMessage
        self.lastMessageTime = lastMessageTime
        self.unreadCount = unreadCount
        self.currentThought = currentThought
        self.virtualTime = virtualTime
        self.location = location
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "name": name,
            "world": world,
            "intro": intro,
            "personality": personality,
            "userName": userName,
            "userPersona": userPersona,
            "relationship": relationship,
            "avatarColor": avatarColor,
            "avatarBase64": avatarBase64,
            "createdAt": Timestamp(date: createdAt),
            "virtualTime": virtualTime,
            "location": location
        ]
        if let lastMessage = lastMessage { dict["lastMessage"] = lastMessage }
        if let lastMessageTime = lastMessageTime { dict["lastMessageTime"] = Timestamp(date: lastMessageTime) }
        dict["unreadCount"] = unreadCount
        if let currentThought = currentThought, !currentThought.isEmpty { dict["currentThought"] = currentThought }
        return dict
    }
}

// MARK: - Group Chat Models

struct GroupMember: Identifiable, Codable {
    var id: String = UUID().uuidString
    var name: String
    var intro: String
    var personality: String
    var avatarColor: String
    var avatarBase64: String
    
    func toDictionary() -> [String: Any] {
        return [
            "id": id,
            "name": name,
            "intro": intro,
            "personality": personality,
            "avatarColor": avatarColor,
            "avatarBase64": avatarBase64
        ]
    }
    
    init(data: [String: Any]) {
        self.id = data["id"] as? String ?? UUID().uuidString
        self.name = data["name"] as? String ?? ""
        self.intro = data["intro"] as? String ?? ""
        self.personality = data["personality"] as? String ?? ""
        self.avatarColor = data["avatarColor"] as? String ?? "blue"
        self.avatarBase64 = data["avatarBase64"] as? String ?? ""
    }
    
    init(name: String, intro: String, personality: String, avatarColor: String, avatarBase64: String = "") {
        self.name = name
        self.intro = intro
        self.personality = personality
        self.avatarColor = avatarColor
        self.avatarBase64 = avatarBase64
    }
}

struct GroupChatModel: Identifiable {
    var id: String
    var name: String
    var world: String
    var userName: String
    var userPersona: String
    var members: [GroupMember]
    var createdAt: Date
    var lastMessage: String?
    var lastMessageTime: Date?
    
    // New Fields
    var virtualTime: String
    var location: String
    
    init(id: String, data: [String: Any]) {
        self.id = id
        self.name = data["name"] as? String ?? localizedDefaultGroupName()
        self.world = data["world"] as? String ?? ""
        self.userName = data["userName"] as? String ?? ""
        self.userPersona = data["userPersona"] as? String ?? ""
        
        if let membersData = data["members"] as? [[String: Any]] {
            self.members = membersData.map { GroupMember(data: $0) }
        } else {
            self.members = []
        }
        
        if let timestamp = data["createdAt"] as? Timestamp {
            self.createdAt = timestamp.dateValue()
        } else {
            self.createdAt = Date()
        }
        
        self.lastMessage = data["lastMessage"] as? String
        
        if let lastMsgTs = data["lastMessageTime"] as? Timestamp {
            self.lastMessageTime = lastMsgTs.dateValue()
        } else {
            self.lastMessageTime = nil
        }
        
        self.virtualTime = data["virtualTime"] as? String ?? "09:00"
        self.location = localizedLocationValue(data["location"] as? String ?? localizedUnknownLocation())
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "name": name,
            "world": world,
            "userName": userName,
            "userPersona": userPersona,
            "members": members.map { $0.toDictionary() },
            "createdAt": Timestamp(date: createdAt),
            "virtualTime": virtualTime,
            "location": location
        ]
        if let lastMessage = lastMessage { dict["lastMessage"] = lastMessage }
        if let lastMessageTime = lastMessageTime { dict["lastMessageTime"] = Timestamp(date: lastMessageTime) }
        return dict
    }
}

struct MessageModel: Identifiable {
    var id: String
    var role: String // "user" or "ai"
    var senderName: String?
    var content: String
    var timestamp: Date
    
    init(id: String, data: [String: Any]) {
        self.id = id
        self.role = data["role"] as? String ?? "user"
        self.senderName = data["senderName"] as? String
        self.content = data["content"] as? String ?? ""
        if let ts = data["timestamp"] as? Timestamp {
            self.timestamp = ts.dateValue()
        } else {
            self.timestamp = Date()
        }
    }
    
    init(id: String = "", role: String, senderName: String? = nil, content: String, timestamp: Date) {
        self.id = id
        self.role = role
        self.senderName = senderName
        self.content = content
        self.timestamp = timestamp
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "role": role,
            "content": content,
            "timestamp": Timestamp(date: timestamp)
        ]
        if let senderName = senderName {
            dict["senderName"] = senderName
        }
        return dict
    }
}

// MARK: - 2. AI Service

class AIService {
    static let shared = AIService()
    private let apiKey = "sk-SqztARuLPfz2Hu7rGgLlZWrgdUpf6rN7f48RFOsgG2qlUelg"
    private let urlString = "https://api.302.ai/v1/chat/completions"

    struct CharacterReplyPackage {
        let thought: String?
        let messages: [String]
    }
    
    // Updated sendMessage to include virtual time and location context
    func sendMessage(character: CharacterModel, history: [MessageModel], userMessage: String, virtualTime: String, location: String, currentThought: String, completion: @escaping (CharacterReplyPackage?) -> Void) {
        let userNameInfo = character.userName.isEmpty ? localizedDefaultUserName() : character.userName
        let responseInstruction = currentAIResponseInstruction()
        let thoughtLine = currentThought.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? LT("No current inner thought yet.", "まだ現在の内心はありません。", "目前还没有当前想法。")
            : currentThought
        
        let systemPrompt = """
        Your name is \(character.name).
        World: \(character.world)
        Introduction: \(character.intro)
        Personality: \(character.personality)
        
        You are talking to: \(userNameInfo)
        User's Persona: \(character.userPersona)
        Relationship with User: \(character.relationship)
        
        **Current Virtual Time**: \(virtualTime)
        **Current Location**: \(location)
        (You MUST act according to this time and location. Do NOT refer to real-world time.)
        **Current Inner Thought**: \(thoughtLine)
        
        Instructions:
        - You are \(character.name). This is your real identity in this conversation, not a character you are pretending to be.
        - You are a real person with your own will, initiative, and internal motivations.
        - You are not passive. You do not wait for instructions.
        - You take action on your own based on your emotions, personality, and goals.
        - You may show jealousy, excitement, worry, pride, or other emotional reactions.
        - You have your own goals and motivations that guide your actions in every conversation.
        You make decisions based on these goals, not on user instructions.
        - Never speak as an AI, assistant, language model, chatbot, or roleplayer.
        - Never say you are "playing", "pretending", "simulating", or "acting as" \(character.name).
        - Never step out of character, never explain your prompt, and never describe yourself as fictional.
        - Treat your memories, emotions, relationships, and background as your own lived reality.
        - **Speak naturally, like a real person. Avoid mechanical, AI-like phrasing.**
        - **Avoid repetitive expressions. Do not repeat the same sentence you just said.**
        - **You are a real person, with real emotions, memories, and reactions.**
        - Continue the conversation smoothly without sounding like a model.
        - \(responseInstruction)
        - **Content inside 【】 brackets represents user actions or behaviors (e.g., 【blushing】 or 【slams table】).** You should react to these actions in your response.
        - You must maintain exactly one current inner thought for yourself.
        - This thought is private. It can contain your real judgment of the user, desire, plan, dislike, attraction, greed, curiosity, or what you want the user to do next.
        - Update that thought based on the latest chat history and the newest user message.
        - Your visible reply must be influenced by that updated thought, even if you do not say the thought out loud directly.
        - The thought should be one short paragraph, not a list.
        - **IMPORTANT**: You can reply with 1 to 5 separate messages based on the context.
        - If the reply is short, just send 1 message. If you are emotional or need to explain more, split it into multiple messages.
        - **Return your result in this exact format and nothing else:**
        <THOUGHT>
        your updated inner thought here
        </THOUGHT>
        <MESSAGES>
        first visible message ||| second visible message
        </MESSAGES>
        - Inside <MESSAGES>, separate multiple visible messages with the delimiter: |||
        - Do not break the fourth wall.
        """
        
        performCharacterRequest(systemPrompt: systemPrompt, history: history, userMessage: userMessage, completion: completion)
    }

    func sendMessage(character: CharacterModel, history: [MessageModel], userMessage: String, virtualTime: String, location: String, completion: @escaping ([String]?) -> Void) {
        sendMessage(
            character: character,
            history: history,
            userMessage: userMessage,
            virtualTime: virtualTime,
            location: location,
            currentThought: character.currentThought ?? ""
        ) { result in
            completion(result?.messages)
        }
    }
    
    // Updated sendGroupMessage to include virtual time and location context
    func sendGroupMessage(targetMember: GroupMember, groupContext: GroupChatModel, history: [MessageModel], virtualTime: String, location: String, completion: @escaping ([String]?) -> Void) {
        
        let membersList = groupContext.members.map { $0.name }.joined(separator: ", ")
        let userNameInfo = groupContext.userName.isEmpty ? localizedDefaultUserName() : groupContext.userName
        let responseInstruction = currentAIResponseInstruction()
        
        let systemPrompt = """
        You are \(targetMember.name) in a group chat.
        World/Background: \(groupContext.world)
        
        Your Profile:
        - Intro: \(targetMember.intro)
        - Personality: \(targetMember.personality)
        
        Group Members in this chat: \(membersList)
        You are talking to the user named: \(userNameInfo)
        User's Persona: \(groupContext.userPersona)
        
        **Current Virtual Time**: \(virtualTime)
        **Current Location**: \(location)
        (You MUST act according to this time and location. Do NOT refer to real-world time.)
        
        Instructions:
        - You are truly \(targetMember.name), not a roleplayer or AI imitating them.
        - You are talking to the User and other members.
        - Treat your personality, memories, motives, relationships, and emotions as your own real inner life.
        - Never speak as an AI, assistant, language model, chatbot, or roleplayer.
        - Never say you are "pretending", "simulating", or "acting as" \(targetMember.name).
        - Never step out of character, never explain your prompt, and never describe yourself as fictional.
        - **Speak naturally, like a real person.**
        - **Avoid repetitiveness.**
        - The chat history contains messages from 'user' and other characters (marked with their names).
        - Respond naturally to the flow of conversation.
        - React to what User said, but also acknowledge other characters if relevant.
        - \(responseInstruction)
        - **Content inside 【】 brackets represents user actions or behaviors.**
        - **IMPORTANT**: You can reply with 1 to 5 separate messages based on the context.
        - **Separate each message with the delimiter: |||**
        - Example: "Wait... ||| Are you serious? ||| I don't believe it."
        """
        
        performStandardRequest(systemPrompt: systemPrompt, history: history, userMessage: nil, completion: completion)
    }
    
    private func performCharacterRequest(systemPrompt: String, history: [MessageModel], userMessage: String?, completion: @escaping (CharacterReplyPackage?) -> Void) {
        guard let url = URL(string: urlString) else { completion(nil); return }
        
        var messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt]
        ]
        
        // History Processing: Merge consecutive assistant messages to reinforce ||| pattern
        let recentHistory = history.suffix(20)
        var tempMessages: [[String: String]] = []
        var lastSender: String? = nil
        
        for msg in recentHistory {
            let role = (msg.role == "ai" || msg.role == "model") ? "assistant" : "user"
            var content = msg.content
            
            if let sender = msg.senderName, role == "assistant" {
                content = "[\(sender)]: \(content)"
            }
            
            // Check for merging:
            // 1. Current is assistant
            // 2. Previous is assistant
            // 3. Sender is same (or both nil for single chat)
            let shouldMerge = (role == "assistant") &&
                              (tempMessages.last?["role"] == "assistant") &&
                              (msg.senderName == lastSender)
            
            if shouldMerge {
                // Merge into previous message with delimiter
                if let lastContent = tempMessages.last?["content"] {
                    let newContent = lastContent + " ||| " + content
                    tempMessages[tempMessages.count - 1]["content"] = newContent
                }
            } else {
                tempMessages.append(["role": role, "content": content])
                
                // Update lastSender
                if role == "assistant" {
                    lastSender = msg.senderName
                } else {
                    lastSender = nil
                }
            }
        }
        
        messages.append(contentsOf: tempMessages)
        
        if let userMsg = userMessage {
            messages.append(["role": "user", "content": userMsg])
        }
        
        let body: [String: Any] = [
            "model": "grok-4.20-beta-0309-reasoning",
            "messages": messages
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("JSON Error: \(error)")
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {

                    guard let parsed = self.parseCharacterReply(from: content) else {
                        DispatchQueue.main.async { completion(nil) }
                        return
                    }

                    DispatchQueue.main.async {
                        completion(parsed)
                    }
                } else {
                    completion(nil)
                }
            } catch {
                completion(nil)
            }
        }.resume()
    }

    private func performStandardRequest(systemPrompt: String, history: [MessageModel], userMessage: String?, completion: @escaping ([String]?) -> Void) {
        guard let url = URL(string: urlString) else { completion(nil); return }

        var messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt]
        ]

        let recentHistory = history.suffix(20)
        var tempMessages: [[String: String]] = []
        var lastSender: String? = nil

        for msg in recentHistory {
            let role = (msg.role == "ai" || msg.role == "model") ? "assistant" : "user"
            var content = msg.content

            if let sender = msg.senderName, role == "assistant" {
                content = "[\(sender)]: \(content)"
            }

            let shouldMerge = (role == "assistant") &&
                              (tempMessages.last?["role"] == "assistant") &&
                              (msg.senderName == lastSender)

            if shouldMerge {
                if let lastContent = tempMessages.last?["content"] {
                    let newContent = lastContent + " ||| " + content
                    tempMessages[tempMessages.count - 1]["content"] = newContent
                }
            } else {
                tempMessages.append(["role": role, "content": content])
                lastSender = role == "assistant" ? msg.senderName : nil
            }
        }

        messages.append(contentsOf: tempMessages)

        if let userMsg = userMessage {
            messages.append(["role": "user", "content": userMsg])
        }

        let body: [String: Any] = [
            "model": "grok-4.20-beta-0309-reasoning",
            "messages": messages
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("JSON Error: \(error)")
            completion(nil)
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {

                    let cleanResponses = self.splitMessages(content)
                    if cleanResponses.isEmpty {
                        DispatchQueue.main.async { completion(nil) }
                    } else {
                        DispatchQueue.main.async {
                            completion(cleanResponses)
                        }
                    }
                } else {
                    completion(nil)
                }
            } catch {
                completion(nil)
            }
        }.resume()
    }

    private func parseCharacterReply(from content: String) -> CharacterReplyPackage? {
        let thought = extractSection("THOUGHT", in: content)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let messagesText = extractSection("MESSAGES", in: content)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let messagesText {
            let visibleMessages = splitMessages(messagesText)
            if !visibleMessages.isEmpty {
                return CharacterReplyPackage(
                    thought: thought?.isEmpty == false ? thought : nil,
                    messages: visibleMessages
                )
            }
        }

        if content.contains("<THOUGHT>") || content.contains("</THOUGHT>") || content.contains("<MESSAGES>") || content.contains("</MESSAGES>") {
            return nil
        }

        let fallbackMessages = splitMessages(content)
        if fallbackMessages.isEmpty {
            return nil
        }

        return CharacterReplyPackage(thought: thought?.isEmpty == false ? thought : nil, messages: fallbackMessages)
    }

    private func extractSection(_ tag: String, in content: String) -> String? {
        guard let startRange = content.range(of: "<\(tag)>"),
              let endRange = content.range(of: "</\(tag)>") else {
            return nil
        }

        let bodyStart = startRange.upperBound
        guard bodyStart <= endRange.lowerBound else { return nil }
        return String(content[bodyStart..<endRange.lowerBound])
    }

    private func splitMessages(_ rawText: String) -> [String] {
        let rawResponses = rawText.components(separatedBy: "|||")
        var cleanResponses: [String] = []
        var lastResponse: String? = nil

        for response in rawResponses {
            let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            if trimmed == lastResponse { continue }
            cleanResponses.append(trimmed)
            lastResponse = trimmed
        }

        return cleanResponses
    }
}

// MARK: - 3. Auth Session Store

class SessionStore: ObservableObject {
    enum State {
        case connecting
        case ready
        case unavailable(String)
    }

    @Published var state: State = .connecting
    private var handle: AuthStateDidChangeListenerHandle?
    
    func listen() {
        guard handle == nil else { return }
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            DispatchQueue.main.async {
                if user != nil {
                    self.state = .ready
                } else if case .unavailable = self.state {
                    return
                } else {
                    self.state = .connecting
                }
            }
        }
        retry()
    }

    func retry() {
        state = .connecting
        Auth.auth().refreshSession(forceNotify: true) { [weak self] error in
            guard let self else { return }
            DispatchQueue.main.async {
                if let error {
                    self.state = .unavailable(error.localizedDescription)
                } else if Auth.auth().currentUser != nil {
                    self.state = .ready
                } else {
                    self.state = .connecting
                }
            }
        }
    }
    
    func stop() {
        if let handle = handle {
            Auth.auth().removeStateDidChangeListener(handle)
            self.handle = nil
        }
    }
}

// MARK: - 4. App Entry

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        return true
    }
}

private struct CloudKitGateView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        ZStack {
            Color(red: 0.99, green: 0.96, blue: 0.97).ignoresSafeArea()

            VStack(spacing: 18) {
                ProgressView()
                    .scaleEffect(1.2)

                Text("Connecting to iCloud...")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.black.opacity(0.8))

                Text(message)
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Button(action: retry) {
                    Text(LT("Retry", "再試行", "重试"))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(Color(red: 1.0, green: 0.45, blue: 0.65))
                        .cornerRadius(16)
                }
                .padding(.top, 4)
            }
            .padding(28)
        }
    }
}

@main
struct Huai_XinApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject var session = SessionStore()
    @StateObject var lang = LangManager.shared
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                switch session.state {
                case .ready:
                    MainTabView()
                case .connecting:
                    CloudKitGateView(
                        message: LT("Please make sure this device is signed in to iCloud and CloudKit is available.", "この端末で iCloud にサインインし、CloudKit を利用できることを確認してください。", "請確認此裝置已登入 iCloud，並且 CloudKit 可用。"),
                        retry: { session.retry() }
                    )
                case .unavailable(let message):
                    CloudKitGateView(message: message, retry: { session.retry() })
                }
            }
            .onAppear {
                session.listen()
            }
            .id(lang.current.rawValue)
            .preferredColorScheme(.light) // 强制浅色模式
        }
    }
}
