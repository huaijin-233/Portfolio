//
//  smallappview.swift
//  Huai Xin
//
//  Created by Codex on 3/8/26.
//

import SwiftUI

struct SmallAppView: View {
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

                ScrollView {
                    VStack(alignment: .leading, spacing: 40) {
                        VStack(alignment: .leading, spacing: 20) {
                            HStack {
                                Image(systemName: "gamecontroller.fill")
                                    .foregroundColor(primaryPink)
                                Text(LT("Choose an App", "ミニアプリを選択", "選擇小程序"))
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(UIColor.darkGray))
                            }
                            .padding(.horizontal, 24)

                            NavigationLink(destination: SmallApp1View()) {
                                GameCard(
                                    title: LT("Avatar Studio", "アバタースタジオ", "頭像工坊"),
                                    subtitle: LT("Design your own avatar style", "自分だけのアバタースタイルを作る", "設計你的專屬頭像風格"),
                                    icon: "person.crop.circle.badge.plus",
                                    gradientColors: [Color.blue, Color.cyan]
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal, 20)

                            NavigationLink(destination: SmallApp2View()) {
                                GameCard(
                                    title: LT("Diary", "日記", "日記"),
                                    subtitle: LT("Write down today's feelings and stories", "今日の気持ちや物語を記録する", "記錄今天的心情和故事"),
                                    icon: "book.closed.fill",
                                    gradientColors: [Color.orange, Color.pink]
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal, 20)
                        }

                        VStack(spacing: 8) {
                            Text(LT("More apps coming soon", "さらに追加予定です", "更多小程序，敬請期待"))
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
            .navigationTitle(LT("Apps", "ミニアプリ", "小程序"))
        }
    }
}
