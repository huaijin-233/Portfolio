//
//  game1.swift
//  Huai Xin
//
//  Created by Huaijin233 on 2/16/26.
//
import SwiftUI
import Combine

// MARK: - Game Constants & Models

enum GamePiece: Equatable {
    case user
    case ai
}

enum GameState: Equatable {
    case playing
    case won(GamePiece)
    case draw
}

class GomokuEngine: ObservableObject {
    // 12x12 Board
    @Published var board: [[GamePiece?]] = Array(repeating: Array(repeating: nil, count: 12), count: 12)
    @Published var isUserTurn = true
    @Published var gameState: GameState = .playing
    @Published var winningLine: [(Int, Int)] = []
    
    // In-game chatter
    @Published var currentChatter: String? = nil
    @Published var showChatter: Bool = false
    
    let character: CharacterModel
    
    init(character: CharacterModel) {
        self.character = character
    }
    
    func resetGame() {
        board = Array(repeating: Array(repeating: nil, count: 12), count: 12)
        isUserTurn = true
        gameState = .playing
        winningLine = []
        currentChatter = nil
        showChatter = false
    }
    
    func userMove(row: Int, col: Int) {
        guard gameState == .playing, isUserTurn, board[row][col] == nil else { return }
        
        makeMove(row: row, col: col, piece: .user)
        
        if gameState == .playing {
            // Capture board state for AI calculation to avoid threading issues
            let currentBoard = self.board
            // Trigger AI on background thread
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.5) {
                self.aiMove(startingBoard: currentBoard)
            }
        }
    }
    
    func aiMove(startingBoard: [[GamePiece?]]) {
        // Perform calculation on a copy of the board to prevent visual glitches
        var simulationBoard = startingBoard
        
        // Use Minimax for strong play
        // Depth 2 allows AI to see: "If I play here, opponent plays there..."
        if let (r, c) = getBestMove(board: &simulationBoard, depth: 2) {
            DispatchQueue.main.async {
                guard self.gameState == .playing else { return }
                self.makeMove(row: r, col: c, piece: .ai)
                
                if self.gameState == .playing {
                     self.triggerRealTimeChatter()
                }
            }
        }
    }
    
    private func makeMove(row: Int, col: Int, piece: GamePiece) {
        board[row][col] = piece
        
        if let line = checkWin(board: board, row: row, col: col, piece: piece) {
            winningLine = line
            gameState = .won(piece)
        } else if checkDraw() {
            gameState = .draw
        } else {
            isUserTurn = (piece == .ai)
        }
    }
    
    // MARK: - Strong AI Implementation (Minimax with Alpha-Beta)
    
    private func getBestMove(board: inout [[GamePiece?]], depth: Int) -> (Int, Int)? {
        // 1. Initial candidates (radius 2 from existing pieces)
        let candidates = getCandidateMoves(board: board)
        // Center of 12x12 is 6,6
        if candidates.isEmpty { return (6, 6) }
        
        var bestScore = -Int.max
        var bestMove: (Int, Int)? = nil
        
        // 2. Alpha-Beta Search
        // We want to maximize AI score.
        var alpha = -Int.max
        let beta = Int.max
        
        for move in candidates {
            // AI plays
            board[move.0][move.1] = .ai
            
            // Check immediate win to save time
            if checkWinQuick(board: board, row: move.0, col: move.1, piece: .ai) {
                board[move.0][move.1] = nil
                return move
            }
            
            // Go to Min node (User's turn)
            let score = minimax(board: &board, depth: depth - 1, alpha: alpha, beta: beta, isMaximizing: false)
            
            // Backtrack
            board[move.0][move.1] = nil
            
            if score > bestScore {
                bestScore = score
                bestMove = move
            }
            alpha = max(alpha, score)
        }
        
        return bestMove
    }
    
    private func minimax(board: inout [[GamePiece?]], depth: Int, alpha: Int, beta: Int, isMaximizing: Bool) -> Int {
        if depth == 0 {
            return evaluateBoard(board: board)
        }
        
        let candidates = getCandidateMoves(board: board)
        if candidates.isEmpty { return evaluateBoard(board: board) }
        
        var currentAlpha = alpha
        var currentBeta = beta
        
        if isMaximizing {
            var maxEval = -Int.max
            for move in candidates {
                board[move.0][move.1] = .ai
                
                // Immediate win check optimization
                if checkWinQuick(board: board, row: move.0, col: move.1, piece: .ai) {
                    board[move.0][move.1] = nil
                    return 100_000_000 // Victory score
                }
                
                let eval = minimax(board: &board, depth: depth - 1, alpha: currentAlpha, beta: currentBeta, isMaximizing: false)
                board[move.0][move.1] = nil
                
                maxEval = max(maxEval, eval)
                currentAlpha = max(currentAlpha, eval)
                if currentBeta <= currentAlpha { break }
            }
            return maxEval
        } else {
            var minEval = Int.max
            for move in candidates {
                board[move.0][move.1] = .user
                
                // Immediate loss check optimization
                if checkWinQuick(board: board, row: move.0, col: move.1, piece: .user) {
                    board[move.0][move.1] = nil
                    return -100_000_000 // Loss score
                }
                
                let eval = minimax(board: &board, depth: depth - 1, alpha: currentAlpha, beta: currentBeta, isMaximizing: true)
                board[move.0][move.1] = nil
                
                minEval = min(minEval, eval)
                currentBeta = min(currentBeta, eval)
                if currentBeta <= currentAlpha { break }
            }
            return minEval
        }
    }
    
    // Global board evaluation
    private func evaluateBoard(board: [[GamePiece?]]) -> Int {
        var score = 0
        let size = 12
        
        // Scan Rows
        for r in 0..<size {
            score += evaluateLine(board: board, row: r, col: 0, dr: 0, dc: 1, length: size)
        }
        // Scan Cols
        for c in 0..<size {
            score += evaluateLine(board: board, row: 0, col: c, dr: 1, dc: 0, length: size)
        }
        // Scan Diagonals
        // (0,0) to (11,11) type
        for k in 0..<size {
            // Top row starts (0,0) -> (0,11)
            score += evaluateLine(board: board, row: 0, col: k, dr: 1, dc: 1, length: size - k)
            if k > 0 { // Left col starts (1,0) -> (11,0)
                score += evaluateLine(board: board, row: k, col: 0, dr: 1, dc: 1, length: size - k)
            }
        }
        // (0,11) to (11,0) type
        for k in 0..<size {
            // Top row starts (0,0) -> (0,11)
            score += evaluateLine(board: board, row: 0, col: k, dr: 1, dc: -1, length: k + 1)
            if k < (size - 1) { // Right col starts (1,11) -> (11,11)
                score += evaluateLine(board: board, row: k + 1, col: size - 1, dr: 1, dc: -1, length: (size - 1) - k)
            }
        }
        
        return score
    }
    
    private func evaluateLine(board: [[GamePiece?]], row: Int, col: Int, dr: Int, dc: Int, length: Int) -> Int {
        var score = 0
        var r = row, c = col
        
        // Convert line to array for easier pattern matching
        var line: [GamePiece?] = []
        for _ in 0..<length {
            line.append(board[r][c])
            r += dr
            c += dc
        }
        
        score += evaluateSequence(line, for: .ai)
        score -= evaluateSequence(line, for: .user) * 2 // Defensive multiplier: slightly prefer blocking
        
        return score
    }
    
    private func evaluateSequence(_ line: [GamePiece?], for player: GamePiece) -> Int {
        var score = 0
        // Heuristic Scoring
        // 5: 100,000,000
        // Open 4: 10,000,000
        // Closed 4: 1,000,000
        // Open 3: 1,000,000 (Very dangerous)
        // Closed 3: 10,000
        // Open 2: 1,000
        
        let count = line.count
        if count < 5 { return 0 }
        
        var currentRun = 0
        var spacesBefore = false
        
        for i in 0..<count {
            if line[i] == player {
                currentRun += 1
            } else {
                if currentRun > 0 {
                    let spacesAfter = (line[i] == nil)
                    
                    if currentRun >= 5 { score += 100_000_000 }
                    else if currentRun == 4 {
                        if spacesBefore && spacesAfter { score += 10_000_000 } // Open 4
                        else if spacesBefore || spacesAfter { score += 1_000_000 } // Closed 4
                    }
                    else if currentRun == 3 {
                        if spacesBefore && spacesAfter { score += 1_000_000 } // Open 3
                        else if spacesBefore || spacesAfter { score += 10_000 } // Closed 3
                    }
                    else if currentRun == 2 {
                        if spacesBefore && spacesAfter { score += 1_000 } // Open 2
                    }
                }
                currentRun = 0
                spacesBefore = (line[i] == nil)
            }
        }
        // End of line check
        if currentRun > 0 {
            if currentRun >= 5 { score += 100_000_000 }
            else if currentRun == 4 && spacesBefore { score += 1_000_000 }
            else if currentRun == 3 && spacesBefore { score += 10_000 }
        }
        
        return score
    }
    
    private func getCandidateMoves(board: [[GamePiece?]]) -> [(Int, Int)] {
        var moves: Set<String> = [] // Use string key "r,c" for uniqueness
        var result: [(Int, Int)] = []
        let range = 2
        let size = 12
        
        for r in 0..<size {
            for c in 0..<size {
                if board[r][c] != nil {
                    // Add neighbors
                    for i in max(0, r - range)...min(size - 1, r + range) {
                        for j in max(0, c - range)...min(size - 1, c + range) {
                            if board[i][j] == nil {
                                let key = "\(i),\(j)"
                                if !moves.contains(key) {
                                    moves.insert(key)
                                    result.append((i, j))
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // If empty (start of game), center
        if result.isEmpty {
            for r in 0..<size {
                for c in 0..<size {
                    if board[r][c] == nil { return [(6, 6)] }
                }
            }
        }
        return result
    }
    
    private func checkWinQuick(board: [[GamePiece?]], row: Int, col: Int, piece: GamePiece) -> Bool {
         return checkWin(board: board, row: row, col: col, piece: piece) != nil
    }
    
    // Existing checkWin
    private func checkWin(board: [[GamePiece?]], row: Int, col: Int, piece: GamePiece) -> [(Int, Int)]? {
        let directions = [(0, 1), (1, 0), (1, 1), (1, -1)]
        let size = 12
        
        for dir in directions {
            var line: [(Int, Int)] = [(row, col)]
            
            var r = row + dir.0
            var c = col + dir.1
            while r >= 0 && r < size && c >= 0 && c < size && board[r][c] == piece {
                line.append((r, c))
                r += dir.0
                c += dir.1
            }
            
            r = row - dir.0
            c = col - dir.1
            while r >= 0 && r < size && c >= 0 && c < size && board[r][c] == piece {
                line.append((r, c))
                r -= dir.0
                c -= dir.1
            }
            
            if line.count >= 5 {
                return line
            }
        }
        return nil
    }
    
    private func checkDraw() -> Bool {
        return !board.flatMap({ $0 }).contains(nil)
    }
    
    // MARK: - Real-Time Chatter Logic
    
    private func triggerRealTimeChatter() {
        // Chance to chat: 40%
        guard Bool.random() && Bool.random() || Bool.random() else { return }
        
        // Construct prompt context
        let prompt = """
        (System: You are currently playing a Gomoku (Five-in-a-row) game with the user.
        The game is ongoing.
        Please provide a SHORT, spontaneous, in-game reaction (max 1 sentence, max 15 words).
        \(currentAIResponseInstruction())
        React to the current game tension or your own move.
        Do NOT mention coordinates like '7,7'.
        Speak in your character's voice/personality.)
        """
        
        // Create a dummy history to pass context (without polluting actual chat DB)
        // We just want the AI response text.
        let dummyHistory: [MessageModel] = []
        
        AIService.shared.sendMessage(
            character: character,
            history: dummyHistory,
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
                
                // Hide after 4 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                    withAnimation { self.showChatter = false }
                }
            }
        }
    }
}

// MARK: - Views

struct GomokuView: View {
    @StateObject var engine: GomokuEngine
    @Environment(\.presentationMode) var presentationMode
    @State private var showExitAlert = false
    
    init(character: CharacterModel) {
        _engine = StateObject(wrappedValue: GomokuEngine(character: character))
    }
    
    // Hello Kitty / Kawaii Colors
    let pastelPink = Color(red: 1.0, green: 0.92, blue: 0.95) // Soft background
    let gridColor = Color(red: 0.85, green: 0.8, blue: 0.85) // Soft elegant grid
    let uiAccent = Color(red: 1.0, green: 0.5, blue: 0.7) // Hot pink for accents
    
    var body: some View {
        ZStack {
            pastelPink.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: Custom Nav Bar
                HStack {
                    Button(action: { showExitAlert = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .bold))
                            Text(LT("Exit", "退出", "退出"))
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundColor(uiAccent)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(color: uiAccent.opacity(0.1), radius: 5, y: 2)
                    }
                    
                    Spacer()
                    
                    // Character Info
                    HStack(spacing: 10) {
                        AvatarView(name: engine.character.name, color: engine.character.avatarColor, size: 32, base64: engine.character.avatarBase64)
                        Text(engine.character.name)
                            .font(.headline)
                            .foregroundColor(.black.opacity(0.7))
                    }
                    
                    Spacer()
                    // Balance space
                    Color.clear.frame(width: 80, height: 44)
                }
                .padding(.top, 10)
                .padding(.horizontal)
                .padding(.bottom, 20)
                
                // MARK: Game Area
                Spacer()
                
                // Chatter Bubble
                ZStack {
                    if engine.showChatter, let text = engine.currentChatter {
                        Text(text)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.black.opacity(0.8))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.1), radius: 8, y: 4)
                            .overlay(
                                Image(systemName: "arrowtriangle.down.fill")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .offset(y: 5)
                                , alignment: .bottom
                            )
                            .offset(y: -50)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(height: 20)
                .zIndex(10)
                
                // Board Container
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.05), radius: 15, x: 0, y: 8)
                    
                    // Board
                    GeometryReader { geo in
                        // Use full available width, maximize size
                        let sideLength = geo.size.width
                        let gridSize = 12
                        let cellSize = sideLength / CGFloat(gridSize)
                        
                        // Center in container
                        ZStack {
                            // Grid Lines (Drawing cells)
                            Path { path in
                                // Horizontal lines
                                for i in 0...gridSize {
                                    let y = CGFloat(i) * cellSize
                                    path.move(to: CGPoint(x: 0, y: y))
                                    path.addLine(to: CGPoint(x: sideLength, y: y))
                                }
                                // Vertical lines
                                for i in 0...gridSize {
                                    let x = CGFloat(i) * cellSize
                                    path.move(to: CGPoint(x: x, y: 0))
                                    path.addLine(to: CGPoint(x: x, y: sideLength))
                                }
                            }
                            .stroke(gridColor, lineWidth: 1)
                            
                            // Pieces
                            ForEach(0..<gridSize, id: \.self) { r in
                                ForEach(0..<gridSize, id: \.self) { c in
                                    if let piece = engine.board[r][c] {
                                        PieceView(piece: piece, size: cellSize * 0.8)
                                            .position(
                                                x: CGFloat(c) * cellSize + cellSize / 2,
                                                y: CGFloat(r) * cellSize + cellSize / 2
                                            )
                                    }
                                }
                            }
                            
                            // Winning Line
                            if !engine.winningLine.isEmpty {
                                Path { path in
                                    let startR = engine.winningLine.first!.0
                                    let startC = engine.winningLine.first!.1
                                    let endR = engine.winningLine.last!.0
                                    let endC = engine.winningLine.last!.1
                                    
                                    path.move(to: CGPoint(
                                        x: CGFloat(startC) * cellSize + cellSize / 2,
                                        y: CGFloat(startR) * cellSize + cellSize / 2
                                    ))
                                    path.addLine(to: CGPoint(
                                        x: CGFloat(endC) * cellSize + cellSize / 2,
                                        y: CGFloat(endR) * cellSize + cellSize / 2
                                    ))
                                }
                                .stroke(Color.green.opacity(0.7), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            }
                            
                            // Touch Input
                            Color.clear
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onEnded { value in
                                            let x = value.location.x
                                            let y = value.location.y
                                            
                                            // Determine cell based on floor
                                            let col = Int(floor(x / cellSize))
                                            let row = Int(floor(y / cellSize))
                                            
                                            if row >= 0 && row < gridSize && col >= 0 && col < gridSize {
                                                engine.userMove(row: row, col: col)
                                            }
                                        }
                                )
                        }
                        .frame(width: sideLength, height: sideLength)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                .padding(8) // Minimal padding to maximize board size
                
                // Status / Footer
                Spacer()
                
                HStack(spacing: 40) {
                    // Player (Cat)
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 1.0, green: 0.9, blue: 0.95))
                                .frame(width: 64, height: 64)
                                .overlay(Circle().stroke(Color.pink.opacity(0.2), lineWidth: 2))
                            
                            Image("game1-cat")
                                .resizable()
                                .scaledToFit()
                                .padding(4)
                        }
                        Text(localizedMeText())
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(engine.isUserTurn ? uiAccent : .gray)
                        
                        if engine.isUserTurn && engine.gameState == .playing {
                            Capsule()
                                .fill(uiAccent)
                                .frame(width: 40, height: 4)
                        } else {
                            Capsule().fill(Color.clear).frame(height: 4)
                        }
                    }
                    .scaleEffect(engine.isUserTurn ? 1.1 : 1.0)
                    .animation(.spring(), value: engine.isUserTurn)
                    
                    // VS
                    Text("VS")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(Color.gray.opacity(0.3))
                    
                    // AI (Dog)
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.9, green: 0.95, blue: 1.0))
                                .frame(width: 64, height: 64)
                                .overlay(Circle().stroke(Color.blue.opacity(0.2), lineWidth: 2))
                            
                            Image("game1-dog")
                                .resizable()
                                .scaledToFit()
                                .padding(12)
                        }
                        Text(engine.character.name)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(!engine.isUserTurn ? Color.blue : .gray)
                        
                        if !engine.isUserTurn && engine.gameState == .playing {
                            Capsule()
                                .fill(Color.blue.opacity(0.6))
                                .frame(width: 40, height: 4)
                        } else {
                            Capsule().fill(Color.clear).frame(height: 4)
                        }
                    }
                    .scaleEffect(!engine.isUserTurn ? 1.1 : 1.0)
                    .animation(.spring(), value: engine.isUserTurn)
                }
                .padding(.bottom, 50)
            }
            
            // Result Overlay
            if case .won(let winner) = engine.gameState {
                ResultOverlay(
                    title: winner == .user ? LT("Victory!", "勝利！", "勝利！") : LT("So Close", "惜しい", "惜敗"),
                    message: winner == .user ? LT("Amazing! You beat ", "すごい！あなたの勝ち！ ", "太棒了！你贏了 ") + engine.character.name : LT("So close... almost had it.", "あと少しで勝てたのに…", "哎呀，差一點點就贏了..."),
                    onPlayAgain: engine.resetGame,
                    onExit: { exitGame(result: winner == .user ? "Win" : "Lose") }
                )
            } else if case .draw = engine.gameState {
                ResultOverlay(
                    title: LT("Draw", "引き分け", "平局"),
                    message: LT("An evenly matched and exciting game!", "互角で素晴らしい対局でした！", "勢均力敵的精彩對局！"),
                    onPlayAgain: engine.resetGame,
                    onExit: { exitGame(result: "Draw") }
                )
            }
        }
        .navigationBarHidden(true)
        .alert(isPresented: $showExitAlert) {
            Alert(
                title: Text(LT("Exit Game", "ゲーム終了", "退出遊戲")),
                message: Text(LT("Are you sure you want to end this match?", "この対局を終了しますか？", "確定要結束現在的對局嗎？")),
                primaryButton: .destructive(Text(LT("Exit", "退出", "退出"))) {
                    exitGame(result: "Quit")
                },
                secondaryButton: .cancel(Text(LT("Cancel", "キャンセル", "取消")))
            )
        }
    }
    
    // Pieces View
    struct PieceView: View {
        let piece: GamePiece
        let size: CGFloat
        
        var body: some View {
            ZStack {
                if piece == .user {
                    Image("game1-cat")
                        .resizable()
                        .scaledToFit()
                        .frame(width: size, height: size)
                        .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 2)
                } else {
                    Image("game1-dog")
                        .resizable()
                        .scaledToFit()
                        .frame(width: size, height: size)
                        .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 2)
                }
            }
            .frame(width: size, height: size)
            .transition(.scale)
        }
    }
    
    // Exit Logic
    func exitGame(result: String) {
        // Only send message if game was actually played/finished or quit
        sendPostGameMessage(result: result)
        presentationMode.wrappedValue.dismiss()
    }
    
    func sendPostGameMessage(result: String) {
        let db = Firestore.firestore()
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        var prompt = ""
        if result == "Quit" {
            prompt = """
            System: The player quit the Gomoku game midway.
            Reply naturally in \(LangManager.shared.current.aiLanguageName) as \(engine.character.name).
            """
        } else {
            let resultDesc: String
            if result == "Win" {
                resultDesc = "The player won and \(engine.character.name) lost."
            } else if result == "Lose" {
                resultDesc = "\(engine.character.name) won and the player lost."
            } else {
                resultDesc = "It was a draw."
            }
            prompt = """
            System: You and the player just finished a Gomoku game.
            Result: \(resultDesc)
            Reply naturally as \(engine.character.name), stay consistent with this result, and briefly comment on the game.
            \(currentAIResponseInstruction())
            """
        }
        
        let charRef = db.collection("users").document(uid).collection("characters").document(engine.character.id)
        
        charRef.collection("messages").order(by: "timestamp", descending: false).limit(toLast: 10).getDocuments { snapshot, _ in
            var history: [MessageModel] = []
            if let docs = snapshot?.documents {
                history = docs.map { MessageModel(id: $0.documentID, data: $0.data() ?? [:]) }
            }
            
            AIService.shared.sendMessage(
                character: engine.character,
                history: history,
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
                    delay += Double.random(in: 1.0...2.0)
                }
            }
        }
    }
}

struct ResultOverlay: View {
    let title: String
    let message: String
    let onPlayAgain: () -> Void
    let onExit: () -> Void
    
    var body: some View {
        ZStack {
            Color.white.opacity(0.5).ignoresSafeArea()
            VisualEffectBlur(blurStyle: .systemUltraThinMaterial)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Text(title)
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundColor(Color(red: 1.0, green: 0.45, blue: 0.65))
                
                Text(message)
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                HStack(spacing: 20) {
                    Button(action: onExit) {
                        Text(LT("Exit", "退出", "退出"))
                            .fontWeight(.bold)
                            .foregroundColor(.gray)
                            .frame(width: 130, height: 54)
                            .background(Color.white)
                            .cornerRadius(20)
                            .shadow(color: Color.black.opacity(0.05), radius: 5, y: 2)
                    }
                    
                    Button(action: onPlayAgain) {
                        Text(LT("Play Again", "もう一局", "再來一局"))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(width: 130, height: 54)
                            .background(Color(red: 1.0, green: 0.45, blue: 0.65))
                            .cornerRadius(20)
                            .shadow(color: Color(red: 1.0, green: 0.45, blue: 0.65).opacity(0.3), radius: 8, y: 4)
                    }
                }
            }
            .padding(40)
            .background(Color.white)
            .cornerRadius(32)
            .shadow(color: Color.black.opacity(0.1), radius: 30, x: 0, y: 15)
            .padding(.horizontal, 30)
        }
    }
}

struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}
