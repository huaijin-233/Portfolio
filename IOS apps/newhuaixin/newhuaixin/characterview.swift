//
//  characterview.swift
//  Huai Xin
//
//  Created by Huaijin233 on 2/5/26.
import SwiftUI

struct CharacterView: View {
    @State private var characters: [CharacterModel] = []
    @State private var groups: [GroupChatModel] = []
    @State private var showCreateSheet = false
    
    // Navigation programmatic state
    @State private var navCharacter: CharacterModel?
    @State private var navGroup: GroupChatModel?
    @State private var navigateToChar = false
    @State private var navigateToGroup = false
    
    private let db = Firestore.firestore()
    
    // UI Constants
    let bgPink = Color(red: 0.99, green: 0.96, blue: 0.97)
    let cardWhite = Color.white
    let primaryPink = Color(red: 1.0, green: 0.45, blue: 0.65)
    
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
                
                bgPink.ignoresSafeArea()
                
                List {
                    // Section: Characters
                    if !characters.isEmpty {
                        Section(header: Text(LT("Characters", "キャラクター", "人物"))) {
                            ForEach(characters) { char in
                                ZStack {
                                    // Change: Navigate to ChangeView with callback
                                    NavigationLink(destination: ChangeView(onEnterChat: { c, g in
                                        if let c = c {
                                            self.navCharacter = c
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                                self.navigateToChar = true
                                            }
                                        }
                                    }, character: char).equatable()) {
                                        EmptyView()
                                    }
                                    .opacity(0)
                                    
                                    HStack(spacing: 16) {
                                        AvatarView(name: char.name, color: char.avatarColor, size: 56, base64: char.avatarBase64)
                                        
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(char.name)
                                                .font(.system(size: 17, weight: .semibold))
                                                .foregroundColor(.black.opacity(0.85))
                                            Text(char.intro)
                                                .font(.system(size: 14))
                                                .foregroundColor(.gray.opacity(0.8))
                                                .lineLimit(2)
                                        }
                                        Spacer()
                                    }
                                    .padding(16)
                                    .background(Color.white)
                                    .cornerRadius(16)
                                    .shadow(color: Color.black.opacity(0.02), radius: 5, x: 0, y: 2)
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            }
                            .onDelete(perform: deleteCharacter)
                        }
                    }
                    
                    // Section: Groups
                    if !groups.isEmpty {
                        Section(header: Text(LT("Group Chats", "グループチャット", "群聊"))) {
                            ForEach(groups) { group in
                                ZStack {
                                    // Change: Navigate to ChangeView with group & callback
                                    NavigationLink(destination: ChangeView(onEnterChat: { c, g in
                                        if let g = g {
                                            self.navGroup = g
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                                self.navigateToGroup = true
                                            }
                                        }
                                    }, group: group).equatable()) {
                                        EmptyView()
                                    }
                                    .opacity(0)
                                    
                                    HStack(spacing: 16) {
                                        ZStack {
                                            Circle().fill(Color.pink.opacity(0.08))
                                            Image(systemName: "person.3.fill")
                                                .foregroundColor(.pink.opacity(0.8))
                                                .font(.system(size: 24))
                                        }
                                        .frame(width: 56, height: 56)
                                        
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(group.name)
                                                .font(.system(size: 17, weight: .semibold))
                                                .foregroundColor(.black.opacity(0.85))
                                            Text(group.world)
                                                .font(.system(size: 14))
                                                .foregroundColor(.gray.opacity(0.8))
                                                .lineLimit(2)
                                        }
                                        Spacer()
                                    }
                                    .padding(16)
                                    .background(Color.white)
                                    .cornerRadius(16)
                                    .shadow(color: Color.black.opacity(0.02), radius: 5, x: 0, y: 2)
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            }
                            .onDelete(perform: deleteGroup)
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle(LT("Contacts", "連絡先", "通訊錄"))
            .navigationBarItems(trailing: Button(action: {
                showCreateSheet = true
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(primaryPink)
            })
            .sheet(isPresented: $showCreateSheet) {
                CreateView(onCreate: { newChar in
                    // Automatically navigate to new chat
                    self.navCharacter = newChar
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.navigateToChar = true
                    }
                })
            }
        }
        .onAppear(perform: fetchData)
    }
    
    func fetchData() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        // Fetch Characters
        db.collection("users").document(uid).collection("characters")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else { return }
                self.characters = documents.map { CharacterModel(id: $0.documentID, data: $0.data() ?? [:]) }
            }
            
        // Fetch Groups
        db.collection("users").document(uid).collection("groups")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else { return }
                self.groups = documents.map { GroupChatModel(id: $0.documentID, data: $0.data() ?? [:]) }
            }
    }
    
    func deleteCharacter(at offsets: IndexSet) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        offsets.forEach { index in
            let charId = characters[index].id
            db.collection("users").document(uid).collection("characters").document(charId).delete()
        }
    }
    
    func deleteGroup(at offsets: IndexSet) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        offsets.forEach { index in
            let groupId = groups[index].id
            db.collection("users").document(uid).collection("groups").document(groupId).delete()
        }
    }
}
