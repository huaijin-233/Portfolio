//
//  loginview.swift
//  Huai Xin
//
//  Created by Huaijin233 on 2/5/26.
import SwiftUI
import Combine
import Combine

struct LoginView: View {
    @ObservedObject private var lang = LangManager.shared
    @State private var username = ""
    @State private var password = ""
    @State private var isRegistering = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    
    // UI Constants
    let bgPink = Color(red: 0.99, green: 0.96, blue: 0.97)
    let primaryPink = Color(red: 1.0, green: 0.45, blue: 0.65)
    
    var body: some View {
        ZStack {
            bgPink.ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                // Header
                VStack(spacing: 12) {
                    Text("WhyAI")
                        .font(.system(size: 52, weight: .heavy, design: .serif))
                        .foregroundColor(primaryPink)
                        .shadow(color: primaryPink.opacity(0.2), radius: 8, x: 0, y: 4)
                    
                    Text(LT("Begin your story", "物語を始めよう", "開啟你的故事"))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray.opacity(0.8))
                        .tracking(1.5) // Letter spacing
                }
                .padding(.bottom, 30)
                
                // Form Container
                VStack(spacing: 24) {
                    VStack(spacing: 14) {
                        AnimatedLanguageHintView()

                        Picker("", selection: Binding(
                            get: { lang.current },
                            set: { lang.setLanguage($0) }
                        )) {
                            ForEach(AppLanguage.allCases) { language in
                                Text(language.label).tag(language)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }

                    // Toggle
                    HStack(spacing: 0) {
                        Button(action: { withAnimation(.easeInOut) { isRegistering = false } }) {
                            VStack(spacing: 8) {
                                Text(LT("Sign In", "ログイン", "登入"))
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(isRegistering ? .gray.opacity(0.5) : primaryPink)
                                Rectangle()
                                    .fill(isRegistering ? Color.clear : primaryPink)
                                    .frame(height: 2.5)
                                    .cornerRadius(1)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        
                        Button(action: { withAnimation(.easeInOut) { isRegistering = true } }) {
                            VStack(spacing: 8) {
                                Text(LT("Register", "登録", "註冊"))
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(isRegistering ? primaryPink : .gray.opacity(0.5))
                                Rectangle()
                                    .fill(isRegistering ? primaryPink : Color.clear)
                                    .frame(height: 2.5)
                                    .cornerRadius(1)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.bottom, 10)
                    
                    // Inputs
                    VStack(spacing: 18) {
                        TextField(LT("Username", "ユーザー名", "用戶名"), text: $username)
                            .padding()
                            .frame(height: 52)
                            .background(Color(UIColor.systemGray6).opacity(0.6))
                            .cornerRadius(16)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        SecureField(LT("Password", "パスワード", "密碼"), text: $password)
                            .padding()
                            .frame(height: 52)
                            .background(Color(UIColor.systemGray6).opacity(0.6))
                            .cornerRadius(16)
                    }
                    
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Action Button
                    Button(action: handleAuth) {
                        ZStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text(isRegistering ? LT("Create Account", "今すぐ登録", "立即註冊") : LT("Enter Huai Xin", "懐信に入る", "進入懷信"))
                                    .font(.headline)
                                    .fontWeight(.bold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(username.isEmpty || password.isEmpty ? Color.gray.opacity(0.3) : primaryPink)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .shadow(color: username.isEmpty || password.isEmpty ? Color.clear : primaryPink.opacity(0.4), radius: 8, x: 0, y: 4)
                        .scaleEffect(isLoading ? 0.98 : 1)
                    }
                    .disabled(username.isEmpty || password.isEmpty || isLoading)
                }
                .padding(32)
                .background(Color.white)
                .cornerRadius(30)
                .shadow(color: Color.black.opacity(0.04), radius: 20, x: 0, y: 10)
                .padding(.horizontal, 24)
                
                Spacer()
                Spacer()
            }
        }
    }
    
    func handleAuth() {
        let cleanName = username.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanName.isEmpty || password.isEmpty { return }
        
        isLoading = true
        errorMessage = ""
        
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        let email = cleanName.contains("@") ? cleanName : "\(cleanName)@huaixin.app"
        
        if isRegistering {
            Auth.auth().createUser(withEmail: email, password: password) { result, error in
                if let error = error {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    return
                }
                
                guard let user = result?.user else { return }
                
                let changeRequest = user.createProfileChangeRequest()
                changeRequest.displayName = cleanName
                changeRequest.commitChanges(completion: nil)
                
                let db = Firestore.firestore()
                db.collection("users").document(user.uid).setData([
                    "username": cleanName,
                    "email": email,
                    "freeMessageCount": 100, // Updated: Default to 100 free messages
                    "createdAt": Timestamp(date: Date())
                ]) { _ in
                    isLoading = false
                }
            }
        } else {
            Auth.auth().signIn(withEmail: email, password: password) { result, error in
                isLoading = false
                if let error = error {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

private struct AnimatedLanguageHintView: View {
    @State private var currentIndex = 0
    private let timer = Timer.publish(every: 1.8, on: .main, in: .common).autoconnect()
    private let phrases = [
        "请选择您的语言",
        "Please choose your language",
        "言語を選択してください"
    ]

    var body: some View {
        ZStack {
            ForEach(Array(phrases.enumerated()), id: \.offset) { index, phrase in
                Text(phrase)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.45, blue: 0.65),
                                Color(red: 1.0, green: 0.63, blue: 0.76),
                                Color(red: 0.95, green: 0.52, blue: 0.70)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .opacity(currentIndex == index ? 1 : 0)
                    .scaleEffect(currentIndex == index ? 1 : 0.96)
                    .animation(.easeInOut(duration: 0.45), value: currentIndex)
            }
        }
        .frame(height: 22)
        .onReceive(timer) { _ in
            currentIndex = (currentIndex + 1) % phrases.count
        }
    }
}
