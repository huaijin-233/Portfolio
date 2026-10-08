//
//  smallapp2.swift
//  newhuaixin
//
//  Created by Huaijin233 on 3/8/26.
//

import SwiftUI

struct DiaryEntry: Identifiable, Codable, Equatable {
    let id: String
    let createdAt: Date
    let content: String

    init(id: String = UUID().uuidString, createdAt: Date = Date(), content: String) {
        self.id = id
        self.createdAt = createdAt
        self.content = content
    }

    var previewTitle: String {
        let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return LT("Untitled Diary", "無題の日記", "未命名日記") }
        let firstLine = text.components(separatedBy: .newlines).first ?? text
        return firstLine.count > 18 ? String(firstLine.prefix(18)) + "..." : firstLine
    }
}

final class DiaryStore {
    static let shared = DiaryStore()

    private let defaults = UserDefaults.standard
    private let keyPrefix = "my_diary_entries_"

    private init() {}

    func loadEntries(for uid: String?) -> [DiaryEntry] {
        let key = storageKey(for: uid)
        guard let data = defaults.data(forKey: key) else { return [] }

        do {
            let entries = try JSONDecoder().decode([DiaryEntry].self, from: data)
            return entries.sorted(by: { $0.createdAt > $1.createdAt })
        } catch {
            return []
        }
    }

    func addEntry(content: String, for uid: String?) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var entries = loadEntries(for: uid)
        entries.insert(DiaryEntry(content: trimmed), at: 0)
        save(entries, for: uid)
    }

    func deleteEntry(_ entry: DiaryEntry, for uid: String?) {
        var entries = loadEntries(for: uid)
        entries.removeAll { $0.id == entry.id }
        save(entries, for: uid)
    }

    private func save(_ entries: [DiaryEntry], for uid: String?) {
        let key = storageKey(for: uid)
        if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: key)
        }
    }

    private func storageKey(for uid: String?) -> String {
        keyPrefix + (uid ?? "guest")
    }
}

struct SmallApp2View: View {
    @State private var entries: [DiaryEntry] = []

    private let store = DiaryStore.shared

    private let bgGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 1.0, green: 0.98, blue: 0.99),
            Color(red: 1.0, green: 0.95, blue: 0.97)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    private let primaryPink = Color(red: 1.0, green: 0.45, blue: 0.65)

    var body: some View {
        ZStack {
            bgGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                if entries.isEmpty {
                    VStack(spacing: 10) {
                        Spacer()
                        Image(systemName: "book.closed")
                            .font(.system(size: 34))
                            .foregroundColor(primaryPink.opacity(0.7))
                        Text(LT("No diary yet", "まだ日記がありません", "還沒有日記"))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black.opacity(0.75))
                        Text(LT("Tap \"New Diary\" below to start writing", "下の「新しい日記」から書き始めましょう", "點下方「新增日記」開始記錄"))
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                } else {
                    List {
                        ForEach(entries) { entry in
                            NavigationLink(destination: DiaryDetailView(entry: entry, onDelete: {
                                delete(entry)
                            })) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(entry.previewTitle)
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(.black.opacity(0.82))
                                        .lineLimit(1)

                                    Text(entry.content)
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray.opacity(0.9))
                                        .lineLimit(2)

                                    Text(dateText(entry.createdAt))
                                        .font(.system(size: 12))
                                        .foregroundColor(primaryPink.opacity(0.8))
                                }
                                .padding(.vertical, 8)
                            }
                        }
                        .onDelete(perform: deleteEntries)
                    }
                    .listStyle(PlainListStyle())
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                }

                NavigationLink(destination: DiaryEditorView(onSave: {
                    reloadEntries()
                })) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.pencil")
                        Text(LT("New Diary", "新しい日記", "新增日記"))
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        LinearGradient(
                            colors: [primaryPink, Color(red: 0.97, green: 0.60, blue: 0.75)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .shadow(color: primaryPink.opacity(0.24), radius: 10, x: 0, y: 5)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 18)
            }
        }
        .navigationTitle(LT("My Diary", "私の日記", "我的日記"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: reloadEntries)
    }

    private func reloadEntries() {
        entries = store.loadEntries(for: Auth.auth().currentUser?.uid)
    }

    private func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            delete(entries[index])
        }
    }

    private func delete(_ entry: DiaryEntry) {
        store.deleteEntry(entry, for: Auth.auth().currentUser?.uid)
        reloadEntries()
    }

    private func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        formatter.locale = Locale(identifier: LangManager.shared.current.localeIdentifier)
        return formatter.string(from: date)
    }
}

struct DiaryDetailView: View {
    let entry: DiaryEntry
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss

    private let bgGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 1.0, green: 0.98, blue: 0.99),
            Color(red: 1.0, green: 0.95, blue: 0.97)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    private let primaryPink = Color(red: 1.0, green: 0.45, blue: 0.65)

    var body: some View {
        ZStack {
            bgGradient.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(detailDateText(entry.createdAt))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(primaryPink.opacity(0.85))

                    Text(entry.content)
                        .font(.system(size: 17))
                        .foregroundColor(.black.opacity(0.82))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineSpacing(6)
                }
                .padding(22)
                .background(Color.white)
                .cornerRadius(22)
                .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 5)
                .padding(20)
            }
        }
        .navigationTitle(LT("My Diary", "私の日記", "我的日記"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    onDelete()
                    dismiss()
                } label: {
                    Text(LT("Delete", "削除", "刪除"))
                }
            }
        }
    }

    private func detailDateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日 HH:mm"
        formatter.locale = Locale(identifier: LangManager.shared.current.localeIdentifier)
        return formatter.string(from: date)
    }
}

struct DiaryEditorView: View {
    @State private var content = ""

    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    private let store = DiaryStore.shared
    private let bgGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 1.0, green: 0.98, blue: 0.99),
            Color(red: 1.0, green: 0.95, blue: 0.97)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    private let primaryPink = Color(red: 1.0, green: 0.45, blue: 0.65)

    var body: some View {
        ZStack {
            bgGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    if content.isEmpty {
                        Text(LT("Write today's feelings and story...", "今日の気持ちや物語を書いてください...", "寫下今天的心情和故事..."))
                            .font(.system(size: 17))
                            .foregroundColor(.gray.opacity(0.7))
                            .padding(.top, 18)
                            .padding(.leading, 18)
                    }

                    TextEditor(text: $content)
                        .scrollContentBackground(.hidden)
                        .padding(12)
                        .font(.system(size: 17))
                }
                .background(Color.white)
                .cornerRadius(24)
                .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 5)
                .padding(20)

                Spacer()
            }
        }
        .navigationTitle(LT("Diary Notebook", "日記帳", "日記本"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(LT("Done", "完了", "完成")) {
                    saveDiary()
                }
                .fontWeight(.bold)
                .foregroundColor(primaryPink)
                .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func saveDiary() {
        store.addEntry(content: content, for: Auth.auth().currentUser?.uid)
        onSave()
        dismiss()
    }
}
