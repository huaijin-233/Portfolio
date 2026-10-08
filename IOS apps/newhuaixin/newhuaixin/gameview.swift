//
//  gameview.swift
//  Huai Xin
//
//  Created by Huaijin233 on 2/16/26.
//
import SwiftUI

struct GameView: View {
    @State private var characters: [CharacterModel] = []
    @State private var selectedCharacter: CharacterModel?
    @State private var showSelectionAlert = false
    
    // Navigation State
    @State private var navigateToGomoku = false
    @State private var navigateToDrawGuess = false
    @State private var navigateToStory = false
    
    private let db = Firestore.firestore()
    
    // UI Constants
    let bgGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 1.0, green: 0.98, blue: 0.99),
            Color(red: 1.0, green: 0.95, blue: 0.97)
        ]),
        startPoint: .top,
        endPoint: .bottom
    )
    let primaryPink = Color(red: 1.0, green: 0.45, blue: 0.65)
    
    var body: some View {
        NavigationView {
            ZStack {
                bgGradient.ignoresSafeArea()
                
                // Hidden Navigation Links
                if let char = selectedCharacter {
                    NavigationLink(destination: GomokuView(character: char), isActive: $navigateToGomoku) {
                        EmptyView()
                    }
                    NavigationLink(destination: DrawGuessView(character: char), isActive: $navigateToDrawGuess) {
                        EmptyView()
                    }
                    NavigationLink(destination: StoryHomeView(character: char), isActive: $navigateToStory) {
                        EmptyView()
                    }
                }
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 40) {
                        
                        // 1. Invite Character Section
                        VStack(alignment: .leading, spacing: 20) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundColor(primaryPink)
                                Text(LT("Invite a Partner", "パートナーを選ぶ", "邀請伙伴"))
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(UIColor.darkGray))
                            }
                            .padding(.horizontal, 24)
                            
                            if characters.isEmpty {
                                Text(LT("No character yet. Please create one on the Contacts page first.", "まだキャラクターがいません。先に連絡先ページで作成してください。", "還沒有創建人物，請先去【人物】頁面創建吧~"))
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .padding(.horizontal)
                                    .padding(.vertical, 20)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 24) {
                                        ForEach(characters) { char in
                                            VStack(spacing: 12) {
                                                ZStack {
                                                    // Selection Ring
                                                    if selectedCharacter?.id == char.id {
                                                        Circle()
                                                            .strokeBorder(
                                                                LinearGradient(colors: [primaryPink, primaryPink.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                                                lineWidth: 3
                                                            )
                                                            .frame(width: 76, height: 76)
                                                    }
                                                    
                                                    AvatarView(name: char.name, color: char.avatarColor, size: 68, base64: char.avatarBase64)
                                                        .opacity(selectedCharacter?.id == char.id ? 1.0 : 0.8)
                                                    
                                                    if selectedCharacter?.id == char.id {
                                                        Image(systemName: "checkmark.circle.fill")
                                                            .font(.system(size: 20))
                                                            .foregroundColor(primaryPink)
                                                            .background(Circle().fill(.white))
                                                            .offset(x: 24, y: 24)
                                                            .shadow(color: Color.black.opacity(0.1), radius: 2)
                                                    }
                                                }
                                                .scaleEffect(selectedCharacter?.id == char.id ? 1.05 : 1.0)
                                                .animation(.spring(response: 0.3), value: selectedCharacter?.id)
                                                
                                                Text(char.name)
                                                    .font(.system(size: 13, weight: selectedCharacter?.id == char.id ? .bold : .medium))
                                                    .foregroundColor(selectedCharacter?.id == char.id ? primaryPink : .gray)
                                            }
                                            .onTapGesture {
                                                withAnimation(.spring()) {
                                                    selectedCharacter = char
                                                }
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 10)
                                }
                            }
                        }
                        
                        // 2. Game List Section
                        VStack(alignment: .leading, spacing: 20) {
                            HStack {
                                Image(systemName: "gamecontroller.fill")
                                    .foregroundColor(primaryPink)
                                Text(LT("Choose a Game", "ゲームを選ぶ", "選擇遊戲"))
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(UIColor.darkGray))
                            }
                            .padding(.horizontal, 24)
                            
                            // Game 1: Gomoku
                            Button(action: {
                                if selectedCharacter == nil {
                                    showSelectionAlert = true
                                } else {
                                    navigateToGomoku = true
                                }
                            }) {
                                GameCard(
                                    title: LT("Gomoku", "五目並べ", "五子棋"),
                                    subtitle: LT("A cozy and healing match", "やさしく癒やされる対局時間", "溫馨治癒的對弈時光"),
                                    icon: "circle.grid.3x3.fill",
                                    gradientColors: [Color.orange, Color.yellow]
                                )
                            }
                            .padding(.horizontal, 20)
                            
                            // Game 2: Draw & Guess
                            Button(action: {
                                if selectedCharacter == nil {
                                    showSelectionAlert = true
                                } else {
                                    navigateToDrawGuess = true
                                }
                            }) {
                                GameCard(
                                    title: LT("Draw & Guess", "お絵かき当て", "你畫我猜"),
                                    subtitle: LT("A tacit understanding test for artists", "お絵かきの相性を試す時間", "靈魂畫手的默契考驗"),
                                    icon: "paintbrush.fill",
                                    gradientColors: [Color.blue, Color.cyan]
                                )
                            }
                            .padding(.horizontal, 20)
                            
                            // Game 3: Story Writing
                            Button(action: {
                                if selectedCharacter == nil {
                                    showSelectionAlert = true
                                } else {
                                    navigateToStory = true
                                }
                            }) {
                                GameCard(
                                    title: LT("Story Writing", "物語づくり", "寫故事"),
                                    subtitle: LT("One line each, create a story together", "一文ずつ、いっしょに物語を作る", "你一句我一句，共創故事"),
                                    icon: "book.fill",
                                    gradientColors: [Color.purple, Color.pink]
                                )
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // 3. Placeholder for future games
                        VStack(spacing: 8) {
                            Text(LT("More games coming soon", "さらにゲーム追加予定", "更多遊戲，敬請期待"))
                                .font(.system(size: 14))
                                .foregroundColor(.gray.opacity(0.6))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .padding(.bottom, 20)
                    }
                    .padding(.top, 30)
                }
            }
            .navigationTitle(LT("Games", "ミニゲーム", "小遊戲"))
            .onAppear(perform: fetchCharacters)
            .alert(isPresented: $showSelectionAlert) {
                Alert(
                    title: Text(LT("Please choose a partner first", "先にパートナーを選んでください", "請先邀請伙伴")),
                    message: Text(LT("You need to select a character before starting a game.", "ゲームを始める前にキャラクターを選ぶ必要があります。", "需要選擇一位人物才能開始遊戲哦。")),
                    dismissButton: .default(Text(LT("OK", "OK", "好的")))
                )
            }
        }
    }
    
    func fetchCharacters() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(uid).collection("characters")
            .order(by: "lastMessageTime", descending: true)
            .addSnapshotListener { snapshot, _ in
                guard let documents = snapshot?.documents else { return }
                self.characters = documents.map { CharacterModel(id: $0.documentID, data: $0.data() ?? [:]) }
                // Optional: Auto select first if none selected
                if selectedCharacter == nil, let first = self.characters.first {
                    selectedCharacter = first
                }
            }
    }
}

struct GameCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let gradientColors: [Color]
    
    var body: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: gradientColors.map { $0.opacity(0.15) }, startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 72, height: 72)
                
                Image(systemName: icon)
                    .font(.system(size: 30))
                    .foregroundStyle(
                        LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .shadow(color: gradientColors[0].opacity(0.3), radius: 4, x: 0, y: 2)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(Color(UIColor.darkGray))
                
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color.gray.opacity(0.3))
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(32)
        .shadow(color: Color.black.opacity(0.04), radius: 15, x: 0, y: 8)
        .overlay(
            RoundedRectangle(cornerRadius: 32)
                .stroke(Color.white, lineWidth: 1)
        )
    }
}
