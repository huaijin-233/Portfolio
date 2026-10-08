//
//  game2.swift
//  Huai Xin
//
//  Created by Huaijin233 on 2/16/26.
//
import SwiftUI
import Combine

// MARK: - Game Models

enum DrawGameState {
    case lobby
    case preparing  // System is generating a word
    case playing    // User is drawing
    case guessing   // AI is analyzing image
    case result     // Win/Lose
}

struct DrawingLine: Identifiable {
    let id = UUID()
    var points: [CGPoint]
    var color: Color = .black
    var lineWidth: CGFloat = 4.0
}

// MARK: - Game Engine

class DrawGuessEngine: ObservableObject {
    @Published var gameState: DrawGameState = .lobby
    
    // Canvas Data
    @Published var lines: [DrawingLine] = []
    @Published var currentLine: DrawingLine? = nil
    
    // Game Data
    @Published var currentWord: String = ""
    @Published var aiGuesses: [String] = []
    @Published var roundResultText: String = ""
    @Published var isWin: Bool = false
    
    // In-game chatter
    @Published var currentChatter: String? = nil
    @Published var showChatter: Bool = false
    
    // Timer for chatter
    private var chatterTimer: Timer?
    
    let character: CharacterModel
    
    // API Constants (Local for Vision)
    private let apiKey = "sk-SqztARuLPfz2Hu7rGgLlZWrgdUpf6rN7f48RFOsgG2qlUelg"
    private let apiUrl = "https://api.302.ai/v1/chat/completions"
    
    init(character: CharacterModel) {
        self.character = character
    }
    
    // MARK: - Game Flow Control
    
    func startGame() {
        generateWord()
    }
    
    private func generateWord() {
        gameState = .preparing
        lines = []
        aiGuesses = []
        
        // System generates the word (using AI API as a random generator)
        let prompt = """
        (System: Function as a random word generator for a "Draw & Guess" game.
        Task: Generate 1 random, simple, concrete noun (for example: apple, cat, elephant, pig, cow, monkey, sun, girl, cookie, hero, princess, castle, astronaut).
        Language: \(currentAILanguageName()).
        Output ONLY the word. Do not add punctuation, quotes, or explanation.)
        """
        
        AIService.shared.sendMessage(
            character: character,
            history: [],
            userMessage: prompt,
            virtualTime: character.virtualTime,
            location: character.location
        ) { responses in
            DispatchQueue.main.async {
                guard let word = responses?.first?.trimmingCharacters(in: .whitespacesAndNewlines), !word.isEmpty else {
                    self.currentWord = LT("heart", "ハート", "愛心")
                    self.startPlaying()
                    return
                }
                
                let cleanWord = self.cleanGuessString(word)
                self.currentWord = cleanWord
                self.startPlaying()
            }
        }
    }
    
    private func startPlaying() {
        gameState = .playing
        startChatterTimer()
        triggerChatter(context: "The game has started. You are waiting for the user to draw. You do NOT know the word. Encourage the user to start. \(currentAIResponseInstruction())")
    }
    
    // Submit the drawing for AI VISION analysis
    func submitDrawingToAI(canvasSize: CGSize) {
        guard gameState == .playing else { return }
        stopChatterTimer()
        gameState = .guessing
        
        // 1. Render Drawing to Image
        guard let base64Image = renderDrawingToBase64(size: canvasSize) else {
            handleAIGuesses(guesses: [
                LT("I can't see it...", "見えないかも...", "我看不到..."),
                LT("Is it blank?", "真っ白かな？", "是空白的嗎?"),
                LT("Try again?", "もう一度試してみる？", "再試一次?")
            ])
            return
        }
        
        // 2. Perform Vision API Request
        performVisionGuess(base64Image: base64Image)
    }
    
    private func performVisionGuess(base64Image: String) {
        let systemPrompt = """
        You are playing "Draw & Guess" (你画我猜). You are the guesser.
        The user has drawn a picture.
        Task:
        1. Look at the image visually. Analyze shapes, lines, and composition.
        2. Describe what you see in the image briefly.
        3. Make 3 honest guesses based ONLY on the visual image.
        
        Requirements:
        - All output must be in \(currentAILanguageName()).
        - Keep it natural and casual.
        
        Output Format:
        [Visual Analysis] ||| [Guess 1] ||| [Guess 2] ||| [Guess 3]
        
        Example:
        "I see a red round object with a stem." ||| "apple" ||| "cherry" ||| "tomato"
        """
        
        let userPrompt = "Here is my drawing. What is it?"
        
        // Construct Payload for Vision Model
        let messages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": [
                ["type": "text", "text": userPrompt],
                ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64Image)"]]
            ]]
        ]
        
        let body: [String: Any] = [
            "model": "qwen/qwen3-vl-30b-a3b-instruct", // Vision capable model
            "messages": messages
        ]
        
        guard let url = URL(string: apiUrl) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("Error encoding JSON: \(error)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                DispatchQueue.main.async {
                    self.handleAIGuesses(guesses: [
                        LT("Network error...", "ネットワークエラー...", "網路錯誤..."),
                        LT("I'm dizzy...", "頭がくらくら...", "我暈了..."),
                        "???"
                    ])
                }
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    
                    let parts = content.components(separatedBy: "|||").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    
                    DispatchQueue.main.async {
                        // Handle Analysis
                        var finalGuesses = parts
                        if !finalGuesses.isEmpty {
                            let analysis = finalGuesses.removeFirst()
                            if analysis.count > 1 {
                                self.triggerChatter(context: "You analyzed the image: '\(analysis)'. Comment on this analysis. \(currentAIResponseInstruction())")
                            }
                        }
                        
                        // Handle Guesses
                        if finalGuesses.isEmpty {
                            finalGuesses = ["???", "???", "???"]
                        }
                        self.handleAIGuesses(guesses: finalGuesses)
                    }
                } else {
                    DispatchQueue.main.async {
                        self.handleAIGuesses(guesses: [LT("Thinking failed...", "考えに失敗...", "思考失敗..."), "???", "???"])
                    }
                }
            } catch {
                print("JSON Error: \(error)")
                DispatchQueue.main.async {
                    self.handleAIGuesses(guesses: [LT("Something went wrong...", "エラーが発生しました...", "出錯了..."), "???", "???"])
                }
            }
        }.resume()
    }
    
    // MARK: - Win/Loss Logic
    
    private func handleAIGuesses(guesses: [String]) {
        // 1. Determine win status immediately to decide flow
        var winningIndex: Int? = nil
        
        // Check ALL guesses. If ANY matches, it's a win.
        for (index, guess) in guesses.enumerated() {
            if isMatch(guess: guess) {
                winningIndex = index
                break
            }
        }
        
        let hasWon = (winningIndex != nil)
        // If won, only show guesses up to the winning one to avoid awkward wrong guesses after a right one.
        // Or show all if you prefer, but usually we stop at the right answer.
        let displayCount = hasWon ? (winningIndex! + 1) : guesses.count
        
        var currentDelay = 0.5
        
        // 2. Schedule Guesses Display
        for i in 0..<displayCount {
            let guess = guesses[i]
            DispatchQueue.main.asyncAfter(deadline: .now() + currentDelay) {
                withAnimation {
                    self.aiGuesses.append(guess)
                }
                
                let clean = self.cleanGuessString(guess)
                
                if self.isMatch(guess: guess) {
                    // Winning guess reaction
                    self.triggerChatter(context: "You guessed '\(clean)' and it was correct! Celebrate. \(currentAIResponseInstruction())")
                } else {
                    // Wrong guess reaction
                    // Only react to the last one if we lost, or occasionally in between
                    if i == displayCount - 1 && !hasWon {
                        self.triggerChatter(context: "You guessed '\(clean)' but it was wrong. You are confused. \(currentAIResponseInstruction())")
                    }
                }
            }
            currentDelay += 2.0
        }
        
        // 3. Schedule Result
        DispatchQueue.main.asyncAfter(deadline: .now() + currentDelay + 0.5) {
            self.isWin = hasWon
            self.roundResultText = hasWon
                ? LT("Correct! The answer was ", "正解！答えは ", "猜對了！答案就是 ") + self.currentWord
                : LT("Not guessed. The answer was ", "当たりませんでした。答えは ", "沒猜中，答案是 ") + self.currentWord
            self.gameState = .result
        }
    }
    
    private func isMatch(guess: String) -> Bool {
        let cleanGuess = cleanGuessString(guess).lowercased()
        let cleanWord = cleanGuessString(currentWord).lowercased()
        
        guard !cleanGuess.isEmpty && !cleanWord.isEmpty else { return false }
        
        // Loose matching: contains
        return cleanGuess.contains(cleanWord) || cleanWord.contains(cleanGuess)
    }
    
    private func cleanGuessString(_ str: String) -> String {
        return str.replacingOccurrences(of: "？", with: "")
                  .replacingOccurrences(of: "?", with: "")
                  .replacingOccurrences(of: "。", with: "")
                  .replacingOccurrences(of: ".", with: "")
                  .replacingOccurrences(of: "\"", with: "")
                  .replacingOccurrences(of: "“", with: "")
                  .replacingOccurrences(of: "”", with: "")
                  .replacingOccurrences(of: "！", with: "")
                  .replacingOccurrences(of: "!", with: "")
                  .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Image Rendering
    
    private func renderDrawingToBase64(size: CGSize) -> String? {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            // White Background
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            
            // Draw Lines
            for line in lines {
                if line.points.isEmpty { continue }
                
                let path = UIBezierPath()
                path.move(to: line.points[0])
                for i in 1..<line.points.count {
                    path.addLine(to: line.points[i])
                }
                
                path.lineWidth = line.lineWidth
                path.lineCapStyle = .round
                path.lineJoinStyle = .round
                UIColor.black.setStroke()
                path.stroke()
            }
        }
        
        return image.jpegData(compressionQuality: 0.5)?.base64EncodedString()
    }
    
    // MARK: - Chatter Logic
    
    func startChatterTimer() {
        stopChatterTimer()
        chatterTimer = Timer.scheduledTimer(withTimeInterval: 12.0, repeats: true) { [weak self] _ in
            self?.checkDrawingAndChat()
        }
    }
    
    func stopChatterTimer() {
        chatterTimer?.invalidate()
        chatterTimer = nil
    }
    
    func checkDrawingAndChat() {
        guard gameState == .playing, !lines.isEmpty else { return }
        triggerChatter(context: "Watching the user draw. Comment on the strokes briefly. Do NOT guess yet. \(currentAIResponseInstruction())")
    }
    
    func triggerChatter(context: String) {
        let prompt = """
        (System: In-game reaction. \(context)
        Output a SHORT bubble text (max 8 words). Casual tone. Speak as \(character.name).
        \(currentAIResponseInstruction()))
        """
        
        AIService.shared.sendMessage(
            character: character,
            history: [],
            userMessage: prompt,
            virtualTime: character.virtualTime,
            location: character.location
        ) { responses in
            guard let responses = responses, let text = responses.first else { return }
            
            DispatchQueue.main.async {
                withAnimation {
                    self.currentChatter = text
                    self.showChatter = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                    withAnimation { self.showChatter = false }
                }
            }
        }
    }
    
    func resetCanvas() {
        lines = []
        currentLine = nil
        aiGuesses = []
        showChatter = false
    }
}

// MARK: - Views

struct DrawGuessView: View {
    @StateObject var engine: DrawGuessEngine
    @Environment(\.presentationMode) var presentationMode
    @State private var showExitAlert = false
    
    init(character: CharacterModel) {
        _engine = StateObject(wrappedValue: DrawGuessEngine(character: character))
    }
    
    // UI Theme
    let bgYellow = Color(red: 1.0, green: 0.98, blue: 0.94) // Warm paper-like
    let accentOrange = Color(red: 1.0, green: 0.65, blue: 0.3)
    
    var body: some View {
        ZStack {
            bgYellow.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { showExitAlert = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                            Text(LT("Exit", "退出", "退出"))
                        }
                        .fontWeight(.bold)
                        .foregroundColor(accentOrange)
                        .padding(8)
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.05), radius: 3)
                    }
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Text(engine.character.name)
                            .font(.headline)
                            .foregroundColor(accentOrange)
                        AvatarView(name: engine.character.name, color: engine.character.avatarColor, size: 36, base64: engine.character.avatarBase64)
                    }
                }
                .padding()
                
                Spacer()
                
                // Chatter Bubble
                if engine.showChatter, let text = engine.currentChatter {
                    Text(text)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.black.opacity(0.8))
                        .padding(12)
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.1), radius: 5, y: 2)
                        .padding(.horizontal)
                        .padding(.bottom, 10)
                        .transition(.scale.combined(with: .opacity))
                        .zIndex(10)
                }
                
                // Main Game Content
                VStack {
                    switch engine.gameState {
                    case .lobby:
                        lobbyView
                    case .preparing:
                        preparingView
                    case .playing, .guessing:
                        playingView
                    case .result:
                        resultView
                    }
                }
                
                Spacer()
            }
        }
        .navigationBarHidden(true)
        .alert(isPresented: $showExitAlert) {
            Alert(
                title: Text(LT("Exit Game", "ゲーム終了", "退出遊戲")),
                message: Text(LT("Are you sure you want to leave?", "本当に離れますか？", "確定要離開嗎？")),
                primaryButton: .destructive(Text(LT("Exit", "退出", "退出"))) {
                    exitGame(result: "Quit")
                },
                secondaryButton: .cancel(Text(LT("Cancel", "キャンセル", "取消")))
            )
        }
    }
    
    // Sub-views for different states
    
    var lobbyView: some View {
        VStack(spacing: 30) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 120, height: 120)
                    .shadow(color: accentOrange.opacity(0.2), radius: 10)
                Image(systemName: "paintbrush.pointed.fill")
                    .font(.system(size: 60))
                    .foregroundColor(accentOrange)
            }
            
            VStack(spacing: 10) {
                Text(LT("Draw & Guess", "お絵かき当て", "你畫我猜"))
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundColor(accentOrange)
                
                Text(LT("Time to test your tacit understanding!\n", "息を合わせる時間です！\n", "考驗默契的時候到了！\n") + engine.character.name + LT(" will guess based on your drawing.", " があなたの絵を見て当てます。", " 會根據你的畫作來猜測。"))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gray)
                    .lineSpacing(4)
            }
            
            Button(action: { engine.startGame() }) {
                Text(LT("Start Game", "ゲーム開始", "開始遊戲"))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 220, height: 60)
                    .background(accentOrange)
                    .cornerRadius(30)
                    .shadow(color: accentOrange.opacity(0.4), radius: 10, y: 5)
            }
            Spacer()
            Spacer()
        }
    }
    
    var preparingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text(LT("Generating a word...", "お題を生成中...", "正在生成題目..."))
                .font(.headline)
                .foregroundColor(.gray)
            Spacer()
        }
    }
    
    var playingView: some View {
        VStack(spacing: 16) {
            // Target Word
            HStack {
                Text(LT("Draw:", "描いて:", "請畫:"))
                    .foregroundColor(.gray)
                Text(engine.currentWord)
                    .font(.title)
                    .fontWeight(.heavy)
                    .foregroundColor(.black.opacity(0.8))
            }
            .padding(.top, 10)
            
            // Canvas
            GeometryReader { geo in
                DrawingCanvas(lines: $engine.lines, currentLine: $engine.currentLine)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .background(Color.white)
                    .cornerRadius(24)
                    .shadow(color: Color.black.opacity(0.05), radius: 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                    )
                
                // Overlay Submit Button (Only when playing)
                if engine.gameState == .playing {
                    VStack {
                        Spacer()
                        HStack {
                            Button(action: { engine.lines = [] }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 20))
                                    .foregroundColor(.gray)
                                    .padding(12)
                                    .background(Color.white)
                                    .clipShape(Circle())
                                    .shadow(radius: 2)
                            }
                            
                            Spacer()
                            
                            Button(action: { engine.submitDrawingToAI(canvasSize: geo.size) }) {
                                Text(LT("Done, start guessing!", "描けた、当てて！", "畫好了，猜吧！"))
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(accentOrange)
                                    .cornerRadius(24)
                                    .shadow(color: accentOrange.opacity(0.3), radius: 5, y: 3)
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .frame(height: 400) // Fixed height
            .padding(.horizontal)
            .disabled(engine.gameState == .guessing)
            
            // Guessing Status
            if engine.gameState == .guessing {
                VStack(spacing: 12) {
                    if engine.aiGuesses.isEmpty {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("\(engine.character.name) \(LT("is observing...", "が見ています...", "正在觀察..."))")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    ForEach(engine.aiGuesses, id: \.self) { guess in
                        HStack {
                            Image(systemName: "bubble.left.fill")
                                .foregroundColor(accentOrange.opacity(0.8))
                            Text(LT("Guess: ", "予想: ", "猜測：") + guess)
                                .fontWeight(.medium)
                                .foregroundColor(.black.opacity(0.8))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(radius: 2)
                        .transition(.scale.combined(with: .slide))
                    }
                }
                .frame(minHeight: 100)
            } else {
                Spacer().frame(height: 100) // Placeholder
            }
        }
    }
    
    var resultView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: engine.isWin ? "star.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(engine.isWin ? .yellow : .gray)
                .shadow(radius: 10)
            
            VStack(spacing: 10) {
                Text(engine.isWin ? LT("Correct!", "正解！", "猜對了！") : LT("Not guessed", "当たりませんでした", "沒猜中"))
                    .font(.title)
                    .fontWeight(.heavy)
                    .foregroundColor(engine.isWin ? .orange : .gray)
                
                Text(engine.roundResultText)
                    .font(.headline)
                    .foregroundColor(.black.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Preview
            DrawingCanvas(lines: $engine.lines, currentLine: .constant(nil))
                .frame(width: 200, height: 200)
                .background(Color.white)
                .cornerRadius(16)
                .shadow(radius: 5)
                .disabled(true)
            
            HStack(spacing: 20) {
                Button(action: { exitGame(result: engine.isWin ? "Win" : "Lose") }) {
                    Text(LT("End Game", "ゲーム終了", "結束遊戲"))
                        .fontWeight(.medium)
                        .foregroundColor(.gray)
                        .frame(width: 120, height: 50)
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(radius: 3)
                }
                
                Button(action: { engine.startGame() }) {
                    Text(LT("Play Again", "もう一回", "再玩一局"))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: 120, height: 50)
                        .background(accentOrange)
                        .cornerRadius(20)
                        .shadow(color: accentOrange.opacity(0.3), radius: 5)
                }
            }
            Spacer()
        }
        .transition(.opacity)
    }
    
    // Exit Logic
    func exitGame(result: String) {
        engine.stopChatterTimer()
        sendPostGameMessage(result: result)
        presentationMode.wrappedValue.dismiss()
    }
    
    func sendPostGameMessage(result: String) {
        let db = Firestore.firestore()
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        var prompt = ""
        if result == "Quit" {
            prompt = """
            System: The player quit the drawing game.
            Reply naturally as \(engine.character.name).
            \(currentAIResponseInstruction())
            """
        } else {
            let context = result == "Win"
                ? "You guessed the player's drawing correctly."
                : "You did not guess the player's drawing."
            prompt = """
            System: You and the player just played Draw & Guess.
            Result: \(context)
            Target word: \(engine.currentWord)
            Reply as \(engine.character.name) and comment on the game naturally. You were always the guessing side, so you may praise the drawing, complain it was hard to guess, or show off your guessing skill.
            \(currentAIResponseInstruction())
            """
        }
        
        let charRef = db.collection("users").document(uid).collection("characters").document(engine.character.id)
        
        AIService.shared.sendMessage(
            character: engine.character,
            history: [],
            userMessage: prompt,
            virtualTime: engine.character.virtualTime,
            location: engine.character.location
        ) { responses in
            guard let responses = responses else { return }
            var delay = 1.0
            for text in responses {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        let msg = MessageModel(role: "ai", content: text, timestamp: Date())
                        charRef.collection("messages").addDocument(data: msg.toDictionary())
                        charRef.updateData([
                            "lastMessage": text,
                            "lastMessageTime": Timestamp(date: Date()),
                            "unreadCount": FieldValue.increment(Int64(1))
                        ])
                    }
                    delay += 1.5
                }
            }
    }
}

// MARK: - Canvas Component

struct DrawingCanvas: View {
    @Binding var lines: [DrawingLine]
    @Binding var currentLine: DrawingLine?
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.white
                
                // Existing Lines
                ForEach(lines) { line in
                    Path { path in
                        addPoints(to: &path, points: line.points)
                    }
                    .stroke(line.color, style: StrokeStyle(lineWidth: line.lineWidth, lineCap: .round, lineJoin: .round))
                }
                
                // Current Line
                if let current = currentLine {
                    Path { path in
                        addPoints(to: &path, points: current.points)
                    }
                    .stroke(current.color, style: StrokeStyle(lineWidth: current.lineWidth, lineCap: .round, lineJoin: .round))
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let point = value.location
                        // Clamp points to bounds
                        if geo.frame(in: .local).contains(point) {
                            if currentLine == nil {
                                currentLine = DrawingLine(points: [point])
                            } else {
                                currentLine?.points.append(point)
                            }
                        }
                    }
                    .onEnded { _ in
                        if let current = currentLine {
                            lines.append(current)
                            currentLine = nil
                        }
                    }
            )
        }
    }
    
    func addPoints(to path: inout Path, points: [CGPoint]) {
        guard let first = points.first else { return }
        path.move(to: first)
        for i in 1..<points.count {
            path.addLine(to: points[i])
        }
    }
}
