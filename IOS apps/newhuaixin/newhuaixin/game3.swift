
//
//  game3.swift
//  newhuaixin
//
//  Created by Huaijin233 on 3/7/26.
//

import SwiftUI
import UIKit
import Foundation
import Photos

// MARK: - Local Story Model

struct LocalStory: Identifiable, Codable, Equatable {
    let id: String
    let createdAt: Date
    let characterId: String
    let characterName: String
    let lines: [String]

    init(id: String = UUID().uuidString,
         createdAt: Date = Date(),
         characterId: String,
         characterName: String,
         lines: [String]) {
        self.id = id
        self.createdAt = createdAt
        self.characterId = characterId
        self.characterName = characterName
        self.lines = lines
    }

    var title: String {
        let first = lines.first ?? ""
        if first.count <= 22 { return first }
        let idx = first.index(first.startIndex, offsetBy: 22)
        return String(first[..<idx]) + "…"
    }
}

// MARK: - Local Store (UserDefaults)

final class LocalStoryStore {
    static let shared = LocalStoryStore()

    private let key = "localStories_v1"
    private let maxStories = 100
    private init() {}

    func loadAll() -> [LocalStory] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        do {
            return try JSONDecoder().decode([LocalStory].self, from: data)
        } catch {
            return []
        }
    }

    func saveAll(_ stories: [LocalStory]) {
        let trimmed = Array(stories.sorted(by: { $0.createdAt > $1.createdAt }).prefix(maxStories))
        do {
            let data = try JSONEncoder().encode(trimmed)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            // ignore (local-only)
        }
    }

    func stories(for characterId: String) -> [LocalStory] {
        loadAll().filter { $0.characterId == characterId }
            .sorted(by: { $0.createdAt > $1.createdAt })
    }

    func add(_ story: LocalStory) {
        var all = loadAll()
        all.append(story)
        saveAll(all)
    }

    func delete(_ story: LocalStory) {
        var all = loadAll()
        all.removeAll { $0.id == story.id }
        saveAll(all)
    }
}

// MARK: - Game 3 Home (你们的故事)

struct StoryHomeView: View {
    let character: CharacterModel

    @State private var stories: [LocalStory] = []
    @State private var showNewStory = false
    @State private var selectedStory: LocalStory? = nil
    @State private var showStoryDetail = false
    @State private var toastText: String = ""
    @State private var showToast = false

    var body: some View {
        ZStack {
            Color(red: 0.99, green: 0.96, blue: 0.97).ignoresSafeArea()

            VStack(spacing: 12) {
                List {
                    if stories.isEmpty {
                        VStack(spacing: 10) {
                            Text(LT("No stories yet", "まだ物語がありません", "你們還沒有故事"))
                                .font(.headline)
                                .foregroundColor(.gray)
                            Text(LT("Tap \"New Story\" below to start", "下の「新しい物語」から始めましょう", "點擊下方「新的故事」開始"))
                                .font(.subheadline)
                                .foregroundColor(.gray.opacity(0.8))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    } else {
                        ForEach(stories) { s in
                            Button(action: {
                                selectedStory = s
                                showStoryDetail = true
                            }) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(s.title)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)
                                        .lineLimit(2)

                                    Text(dateString(s.createdAt))
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            .contextMenu {
                                Button(role: .destructive) {
                                    LocalStoryStore.shared.delete(s)
                                    reload()
                                    showToastMessage(LT("Deleted", "削除しました", "已刪除"))
                                } label: {
                                    Label(LT("Delete", "削除", "刪除"), systemImage: "trash")
                                }

                                Button {
                                    saveStoryAsImage(s)
                                } label: {
                                    Label(LT("Save story to Photos", "物語を写真に保存", "保存故事到相冊"), systemImage: "square.and.arrow.down")
                                }
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())

                Button(action: { showNewStory = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text(LT("New Story", "新しい物語", "新的故事"))
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color(red: 1.0, green: 0.45, blue: 0.65))
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
            }

            if showToast {
                VStack {
                    Spacer()
                    Text(toastText)
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
        .navigationTitle(LT("Your Stories", "ふたりの物語", "你們的故事"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { reload() }
        .sheet(isPresented: $showNewStory, onDismiss: { reload() }) {
            NavigationView {
                StoryPlayView(character: character)
            }
        }
        .sheet(isPresented: $showStoryDetail) {
            if let story = selectedStory {
                NavigationView {
                    StoryDetailView(story: story, onSave: {
                        saveStoryAsImage(story)
                    })
                }
            }
        }
    }

    private func reload() {
        stories = LocalStoryStore.shared.stories(for: character.id)
    }

    private func dateString(_ d: Date) -> String {
        let f = DateFormatter()
        return LangManager.shared.dateString(d, format: "yyyy/MM/dd HH:mm")
    }

    private func showToastMessage(_ msg: String) {
        toastText = msg
        withAnimation { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation { showToast = false }
        }
    }

    private func saveStoryAsImage(_ story: LocalStory) {
        let saveAction = {
            let view = StoryImageView(story: story)
            let renderer = ImageRenderer(content: view)
            renderer.scale = UIScreen.main.scale

            guard let uiImage = renderer.uiImage else {
                showToastMessage(LT("Save failed", "保存に失敗しました", "保存失敗"))
                return
            }

            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: uiImage)
            }) { success, error in
                DispatchQueue.main.async {
                    if success {
                        showToastMessage(LT("Saved to Photos", "写真に保存しました", "已保存到相冊"))
                    } else {
                        showToastMessage(LT("Save failed", "保存に失敗しました", "保存失敗"))
                    }
                }
            }
        }

        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .authorized, .limited:
            saveAction()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized || newStatus == .limited {
                        saveAction()
                    } else {
                        showToastMessage(LT("Please allow saving to Photos", "写真への保存を許可してください", "請允許保存到相冊"))
                    }
                }
            }
        default:
            showToastMessage(LT("Please allow photo access in Settings", "設定で写真の権限を許可してください", "請在系統設定中允許相冊權限"))
        }
    }
}

struct StoryDetailView: View {
    let story: LocalStory
    let onSave: () -> Void
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ZStack {
            Color(red: 0.97, green: 0.94, blue: 0.92).ignoresSafeArea()

            VStack(spacing: 14) {
                ZStack {
                    NotebookPaperBackground()

                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(story.lines.enumerated()), id: \.offset) { idx, line in
                                StoryNotebookLine(
                                    index: idx + 1,
                                    author: (idx % 2 == 1) ? localizedMeText() : story.characterName,
                                    text: line,
                                    isUser: (idx % 2 == 1)
                                )
                            }
                        }
                        .padding(.top, 18)
                        .padding(.bottom, 16)
                    }
                }
                .cornerRadius(22)
                .shadow(color: Color.black.opacity(0.10), radius: 18, x: 0, y: 10)
                .padding(.horizontal, 16)

                Button(action: onSave) {
                    HStack(spacing: 10) {
                        Image(systemName: "square.and.arrow.down.fill")
                        Text(LT("Save to Photos", "写真に保存", "保存到相冊"))
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.black.opacity(0.88))
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 14)
            }
        }
        .navigationTitle(LT("Story Details", "物語の詳細", "故事詳情"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(leading: Button(LT("Close", "閉じる", "關閉")) {
            presentationMode.wrappedValue.dismiss()
        })
    }
}

// MARK: - Story Play View (写故事流程)

struct StoryPlayView: View {
    let character: CharacterModel

    @Environment(\.presentationMode) var presentationMode

    @State private var lines: [String] = []
    @State private var inputText: String = ""
    @State private var isAITyping = false
    @State private var hasFinished = false

    @State private var toastText: String = ""
    @State private var showToast = false

    private let minLines = 3
    private let maxLines = 10

    var body: some View {
        ZStack {
            Color(red: 0.97, green: 0.94, blue: 0.92).ignoresSafeArea()

            VStack(spacing: 14) {
                // Paper Page
                ZStack {
                    NotebookPaperBackground()

                    VStack(spacing: 0) {
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 10) {
                                    ForEach(Array(lines.enumerated()), id: \ .offset) { idx, text in
                                        StoryNotebookLine(
                                            index: idx + 1,
                                            author: (idx % 2 == 1) ? localizedMeText() : character.name,
                                            text: text,
                                            isUser: (idx % 2 == 1)
                                        )
                                        .id(idx)
                                    }

                                    if isAITyping {
                                        HStack(spacing: 8) {
                                            ProgressView().scaleEffect(0.9)
                                            Text("\(character.name) \(LT("is writing the next line…", "が次の一文を書いています…", "正在寫下一句…"))")
                                                .font(.system(size: 12))
                                                .foregroundColor(.gray)
                                        }
                                        .padding(.top, 6)
                                        .padding(.horizontal, 18)
                                    }
                                }
                                .padding(.top, 18)
                                .padding(.bottom, 16)
                            }
                            .onChange(of: lines.count) { _ in
                                withAnimation {
                                    proxy.scrollTo(max(0, lines.count - 1), anchor: .bottom)
                                }
                            }
                        }

                        Divider().opacity(0.08)

                        // Notebook-style input
                        if !hasFinished {
                            HStack(spacing: 10) {
                                Image(systemName: "pencil")
                                    .foregroundColor(Color.black.opacity(0.35))

                                TextField(LT("Write the next line…", "次の一文を書く…", "寫下一句…"), text: $inputText)
                                    .font(.system(size: 16))
                                    .disableAutocorrection(true)
                                    .textInputAutocapitalization(.never)
                                    .disabled(!isUserTurn || isAITyping)

                                Button(action: userSubmitLine) {
                                    Text(isUserTurn ? LT("Write", "書く", "落筆") : LT("Wait", "待機", "等待"))
                                        .fontWeight(.semibold)
                                        .frame(width: 72, height: 38)
                                        .background(isUserTurn && !isAITyping ? Color.black.opacity(0.85) : Color.black.opacity(0.12))
                                        .foregroundColor(isUserTurn && !isAITyping ? .white : .gray)
                                        .cornerRadius(10)
                                }
                                .disabled(!isUserTurn || isAITyping)
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                        }
                    }
                }
                .cornerRadius(22)
                .shadow(color: Color.black.opacity(0.10), radius: 18, x: 0, y: 10)
                .padding(.horizontal, 16)

                // Finish button outside the paper (like stamping)
                Button(action: finishStory) {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.seal.fill")
                        Text(LT("Finish Story", "物語を完成", "完成故事"))
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(canFinish ? Color.black.opacity(0.88) : Color.black.opacity(0.15))
                    .foregroundColor(canFinish ? .white : .gray)
                    .cornerRadius(16)
                    .padding(.horizontal, 16)
                }
                .disabled(!canFinish)
                .padding(.bottom, 14)
            }

            if showToast {
                VStack {
                    Spacer()
                    Text(toastText)
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
        .navigationTitle(LT("Write a Story", "物語を書く", "寫故事"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(leading: Button(LT("Close", "閉じる", "關閉")) {
            presentationMode.wrappedValue.dismiss()
        })
        .onAppear {
            startNewStory()
        }
    }

    private var isUserTurn: Bool {
        // AI starts (index 0), user is odd indices
        return lines.count % 2 == 1
    }

    private var canFinish: Bool {
        !hasFinished && lines.count >= minLines
    }

    private func startNewStory() {
        lines = []
        inputText = ""
        hasFinished = false
        isAITyping = false

        // AI writes the first line
        generateNextAILine()
    }

    private func userSubmitLine() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard lines.count < maxLines else {
            showToastMessage(LT("Reached the 10-line limit. Please finish the story.", "10文の上限に達しました。物語を完成してください。", "已到 10 句話上限，請完成故事"))
            return
        }
        guard isUserTurn else { return }

        lines.append(text)
        inputText = ""

        if lines.count >= maxLines {
            showToastMessage(LT("Reached the 10-line limit. Please finish the story.", "10文の上限に達しました。物語を完成してください。", "已到 10 句話上限，請完成故事"))
            return
        }

        // Then AI writes
        generateNextAILine()
    }

    private func generateNextAILine() {
        guard lines.count < maxLines else { return }
        guard !isUserTurn else { return } // only generate on AI turns

        isAITyping = true

        let prompt = buildAIPrompt(storyLines: lines, nextIndex: lines.count + 1)

        // Use existing AIService (same idea as chat/game1/game2)
        // We pass an empty history; the prompt itself includes context.
        AIService.shared.sendMessage(
            character: character,
            history: [],
            userMessage: prompt,
            virtualTime: "",
            location: ""
        ) { responses in
            DispatchQueue.main.async {
                self.isAITyping = false

                guard let responses = responses, let raw = responses.first else {
                    self.showToastMessage(LT("AI generation failed. Please try again.", "AI生成に失敗しました。もう一度お試しください。", "AI 生成失敗，請重試"))
                    return
                }

                let line = sanitizeOneSentence(raw)
                if line.isEmpty {
                    self.showToastMessage(LT("AI generation failed. Please try again.", "AI生成に失敗しました。もう一度お試しください。", "AI 生成失敗，請重試"))
                    return
                }

                self.lines.append(line)

                if self.lines.count >= self.maxLines {
                    self.showToastMessage(LT("Reached the 10-line limit. Please finish the story.", "10文の上限に達しました。物語を完成してください。", "已到 10 句話上限，請完成故事"))
                }
            }
        }
    }

    private func buildAIPrompt(storyLines: [String], nextIndex: Int) -> String {
        // Strictly ask for ONE sentence.
        var ctx = ""
        if storyLines.isEmpty {
            ctx = "" // first line
        } else {
            ctx = storyLines.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        }

        return """
        You are \(character.name). You and the user are writing a story together, one line at a time.
        Only output the next single story sentence. No numbering. No explanation. Keep it concise.
        \(currentAIResponseInstruction())
        \(ctx.isEmpty ? "Write the opening line of the story." : "Current story:\\n\(ctx)\\nWrite line \(nextIndex).")
        """
    }

    private func sanitizeOneSentence(_ text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove leading numbering like "1." "1、" "1)"
        while let first = s.first, first.isNumber {
            s.removeFirst()
        }
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix(".") || s.hasPrefix("、") || s.hasPrefix(")") {
            s.removeFirst()
        }
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)

        // Keep only first line
        if let newline = s.firstIndex(of: "\n") {
            s = String(s[..<newline]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return s
    }

    private func finishStory() {
        guard canFinish else {
            showToastMessage(LT("Write at least 3 lines before finishing.", "完成する前に最低3文書いてください。", "至少寫 3 句話才能完成"))
            return
        }

        hasFinished = true

        // Save locally
        let story = LocalStory(characterId: character.id, characterName: character.name, lines: lines)
        LocalStoryStore.shared.add(story)

        showToastMessage(LT("Story saved to Your Stories", "物語を「ふたりの物語」に保存しました", "故事已保存到你們的故事"))

        // Send post-game messages to chat (like game1/game2)
        Task {
            await sendPostGameMessages(story: story)
        }

        // Close after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            presentationMode.wrappedValue.dismiss()
        }
    }

    private func showToastMessage(_ msg: String) {
        toastText = msg
        withAnimation { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation { showToast = false }
        }
    }

    // MARK: - Post-game chat messages

    private func sendPostGameMessages(story: LocalStory) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let db = Firestore.firestore()
        let charRef = db.collection("users").document(uid)
            .collection("characters").document(character.id)

        // Ask AI to send 1-2 short post-game messages in character voice.
        let storyText = story.lines.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        let prompt = """
        You are \(character.name).
        Based on the story below, send the user 1 to 2 short follow-up chat messages in character voice, with emotion or interaction.
        Output only the message content, one per line, no numbering.
        \(currentAIResponseInstruction())
        Story:
        \(storyText)
        """

        await withCheckedContinuation { cont in
            AIService.shared.sendMessage(
                character: character,
                history: [],
                userMessage: prompt,
                virtualTime: "",
                location: ""
            ) { responses in
                let msgs = (responses ?? [])
                    .flatMap { $0.components(separatedBy: "\n") }
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }

                guard !msgs.isEmpty else {
                    cont.resume()
                    return
                }

                // Write each message and increment unreadCount for each.
                for text in msgs.prefix(2) {
                    let data: [String: Any] = [
                        "role": "ai",
                        "content": text,
                        "timestamp": Timestamp(date: Date())
                    ]
                    charRef.collection("messages").addDocument(data: data)

                    charRef.updateData([
                        "lastMessage": text,
                        "lastMessageTime": Timestamp(date: Date()),
                        "unreadCount": FieldValue.increment(Int64(1))
                    ])
                }

                cont.resume()
            }
        }
    }
}

// MARK: - UI Components

private struct NotebookPaperBackground: View {
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // Paper
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.white)

                // Left margin line
                Rectangle()
                    .fill(Color(red: 1.0, green: 0.75, blue: 0.78).opacity(0.6))
                    .frame(width: 2)
                    .padding(.leading, 26)
                    .padding(.top, 18)
                    .padding(.bottom, 18)

                // Horizontal ruled lines
                let lineSpacing: CGFloat = 28
                ForEach(0..<Int(geo.size.height / lineSpacing) + 2, id: \.self) { i in
                    Rectangle()
                        .fill(Color.black.opacity(0.04))
                        .frame(height: 1)
                        .offset(x: 0, y: 18 + CGFloat(i) * lineSpacing)
                }

                // Subtle top header
                HStack {
                    Text(LT("A Story Written Together", "いっしょに書いた物語", "一起寫的故事"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.black.opacity(0.55))
                    Spacer()
                    Text(LT("Up to 10 lines · At least 3", "最大10文・最少3文", "最多 10 句 · 最少 3 句"))
                        .font(.system(size: 12))
                        .foregroundColor(Color.black.opacity(0.35))
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
            }
        }
    }
}

private struct StoryNotebookLine: View {
    let index: Int
    let author: String
    let text: String
    let isUser: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("\(index)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.black.opacity(0.35))
                    .frame(width: 20, alignment: .trailing)

                Text(author)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isUser ? Color(red: 0.85, green: 0.25, blue: 0.45) : Color.black.opacity(0.55))

                Spacer()
            }

            Text(text)
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(Color.black.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 28)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 6)
    }
}

private struct StoryImageView: View {
    let story: LocalStory

    // Export canvas size (iPhone screenshot-like)
    private let canvasWidth: CGFloat = 1080
    private let canvasHeight: CGFloat = 1920

    var body: some View {
        ZStack {
            // Same background as the detail page
            Color(red: 0.97, green: 0.94, blue: 0.92)

            VStack(spacing: 0) {
                // Top header (matches the visible UI style)
                HStack {
                    Text(LT("Close", "閉じる", "關閉"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black.opacity(0.85))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.95))
                        .cornerRadius(22)

                    Spacer()

                    Text(LT("Story Details", "物語の詳細", "故事詳情"))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.black.opacity(0.9))

                    Spacer()

                    // Keep right side balanced (invisible placeholder)
                    Text(LT("Close", "閉じる", "關閉"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.clear)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Color.clear)
                        .cornerRadius(22)
                }
                .padding(.horizontal, 26)
                .padding(.top, 36)

                Spacer().frame(height: 18)

                // Paper area
                ZStack(alignment: .topLeading) {
                    NotebookPaperBackground()

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(story.lines.enumerated()), id: \.offset) { idx, line in
                            StoryNotebookLine(
                                index: idx + 1,
                                author: (idx % 2 == 1) ? localizedMeText() : story.characterName,
                                text: line,
                                isUser: (idx % 2 == 1)
                            )
                        }
                    }
                    .padding(.top, 18)
                    .padding(.bottom, 20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .cornerRadius(22)
                .shadow(color: Color.black.opacity(0.10), radius: 18, x: 0, y: 10)
                .padding(.horizontal, 26)

                Spacer(minLength: 18)

                // Bottom button (visual-only, but included in exported image)
                HStack {
                    Image(systemName: "square.and.arrow.down.fill")
                    Text(LT("Save to Photos", "写真に保存", "保存到相冊"))
                        .fontWeight(.semibold)
                }
                .font(.system(size: 18))
                .frame(maxWidth: .infinity)
                .frame(height: 86)
                .background(Color.black.opacity(0.88))
                .foregroundColor(.white)
                .cornerRadius(20)
                .padding(.horizontal, 26)
                .padding(.bottom, 36)
            }
        }
        .frame(width: canvasWidth, height: canvasHeight)
    }
}

// MARK: - Rounded corner helper (unique to this file)

private extension View {
    func storyCornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(StoryRoundedCorner(radius: radius, corners: corners))
    }
}

private struct StoryRoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
