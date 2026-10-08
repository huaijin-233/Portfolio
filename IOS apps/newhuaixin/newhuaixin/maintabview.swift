//
//  maintabview.swift
//  Huai Xin
//
//  Created by Huaijin233 on 2/5/26.
//
import SwiftUI

struct MainTabView: View {
    @State private var unreadChatCount = 0
    @State private var unreadListener: ListenerRegistration?
    private let db = Firestore.firestore()

    var body: some View {
        TabView {
            // Tab 1: 聊天列表
            ChatListView()
                .tabItem {
                    Image(systemName: "message.fill")
                    Text(LT("Chat", "チャット", "聊天"))
                }
                .badge(unreadChatCount > 0 ? unreadChatCount : 0)
            
            // Tab 2: 人物列表
            CharacterView()
                .tabItem {
                    Image(systemName: "person.2.fill")
                    Text(LT("Contacts", "連絡先", "通訊錄"))
                }
            
            // Tab 3: 小程序
            SmallAppView()
                .tabItem {
                    Image(systemName: "square.grid.2x2.fill")
                    Text(LT("Apps", "ミニアプリ", "小程序"))
                }

            // Tab 4: 小游戏
            GameView()
                .tabItem {
                    Image(systemName: "gamecontroller.fill")
                    Text(LT("Games", "ミニゲーム", "小遊戲"))
                }
            
            // Tab 5: 我
            ProfileView()
                .tabItem {
                    Image(systemName: "person.crop.circle")
                    Text(LT("Me", "マイページ", "我"))
                }
        }
        .accentColor(Color(red: 1.0, green: 0.45, blue: 0.65)) // Matches standard premium pink
        .onAppear(perform: listenToUnreadCount)
        .onDisappear {
            unreadListener?.remove()
            unreadListener = nil
        }
    }

    func listenToUnreadCount() {
        guard unreadListener == nil, let uid = Auth.auth().currentUser?.uid else { return }
        unreadListener = db.collection("users").document(uid).collection("characters")
            .addSnapshotListener { snapshot, _ in
                let total = snapshot?.documents.reduce(0) { partial, doc in
                    partial + ((doc.data() ?? [:])["unreadCount"] as? Int ?? 0)
                } ?? 0
                unreadChatCount = total
            }
    }
}

// 简单的头像视图组件
struct AvatarView: View {
    let name: String
    let color: String // "blue" or "pink"
    let size: CGFloat
    var base64: String? = nil
    
    // Premium pastel colors
    let pinkBg = Color(red: 1.0, green: 0.94, blue: 0.96)
    let pinkText = Color(red: 0.9, green: 0.4, blue: 0.6)
    
    let blueBg = Color(red: 0.92, green: 0.96, blue: 1.0)
    let blueText = Color(red: 0.3, green: 0.6, blue: 0.9)
    
    var body: some View {
        if let base64 = base64, !base64.isEmpty,
           let data = Data(base64Encoded: base64),
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.black.opacity(0.05), lineWidth: 1)) // Subtle border
        } else {
            ZStack {
                (color == "blue" ? blueBg : pinkBg)
                
                Text(String(name.prefix(1)))
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundColor(color == "blue" ? blueText : pinkText)
            }
            .frame(width: size, height: size)
            .cornerRadius(size / 2)
        }
    }
}
