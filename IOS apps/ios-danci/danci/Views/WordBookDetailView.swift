import SwiftUI

struct WordBookDetailView: View {
    @EnvironmentObject private var wordStore: WordStore
    @Environment(\.dismiss) private var dismiss

    let bookID: UUID

    @State private var searchText = ""
    @State private var isPresentingNewWord = false
    @State private var isPresentingEditBook = false
    @State private var isConfirmingDeleteBook = false

    private var book: WordBook? {
        wordStore.book(with: bookID)
    }

    var body: some View {
        ZStack {
            PlayfulBackground()

            if let book {
                List {
                    headerSection(for: book)

                    if filteredWords(in: book).isEmpty {
                        emptyWordsSection(for: book)
                    } else {
                        wordsSection(for: book)
                    }

                    Color.clear
                        .frame(height: AppStyle.floatingTabBarClearance * 0.7)
                        .listRowInsets(.init())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            } else {
                EmptyStateView(
                    title: "这个单词本不见了",
                    message: "它可能已经被删除了，请返回书架看看。"
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(book?.title ?? "单词本")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppColors.background.opacity(0.98), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .searchable(text: $searchText, prompt: "搜索当前单词本里的单词")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    isPresentingNewWord = true
                }
                label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                }
                .disabled(book == nil)

                Menu {
                    Button("编辑单词本") {
                        isPresentingEditBook = true
                    }

                    Button("删除单词本", role: .destructive) {
                        isConfirmingDeleteBook = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .semibold))
                }
                .disabled(book == nil)
            }
        }
        .sheet(isPresented: $isPresentingNewWord) {
            NavigationStack {
                WordDetailView(bookID: bookID, mode: .create)
            }
        }
        .sheet(isPresented: $isPresentingEditBook) {
            if let book {
                NavigationStack {
                    WordBookEditorView(mode: .edit(book))
                }
            }
        }
        .alert("删除这个单词本？", isPresented: $isConfirmingDeleteBook) {
            Button("删除", role: .destructive) {
                let deletingBookID = bookID
                dismiss()
                Task { @MainActor in
                    wordStore.deleteBook(id: deletingBookID)
                }
            }

            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后，里面的单词也会一起删除。")
        }
    }
}

private extension WordBookDetailView {
    func filteredWords(in book: WordBook) -> [WordEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return book.words }

        return book.words.filter { entry in
            entry.word.localizedCaseInsensitiveContains(query)
                || entry.note.localizedCaseInsensitiveContains(query)
        }
    }

    func headerSection(for book: WordBook) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(AppColors.primary.opacity(0.14))
                            .frame(width: 58, height: 58)

                        Image(systemName: "text.book.closed.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppColors.primary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(book.title)
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(AppColors.primaryText)
                            .lineLimit(2)

                        HStack(spacing: 8) {
                            SourceBadge(source: book.source)

                            Text(book.createdAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.footnote)
                                .foregroundStyle(AppColors.secondaryText)
                        }
                    }

                    Spacer(minLength: 0)
                }

                HStack(spacing: 12) {
                    statCard(
                        title: "单词数",
                        value: "\(book.wordCount)",
                        color: AppColors.primary
                    )

                    statCard(
                        title: "搜索结果",
                        value: "\(filteredWords(in: book).count)",
                        color: AppColors.mint
                    )
                }

                Button {
                    isPresentingNewWord = true
                } label: {
                    Label("新增单词", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.primary)
            }
            .padding(20)
            .background(AppColors.elevatedCard)
            .overlay(
                RoundedRectangle(cornerRadius: AppStyle.cornerRadius, style: .continuous)
                    .stroke(AppColors.cardStroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppStyle.cornerRadius, style: .continuous))
            .shadow(color: AppStyle.cardShadow.opacity(0.8), radius: 12, y: 8)
            .listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
    }

    func emptyWordsSection(for book: WordBook) -> some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: "text.badge.plus")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(AppColors.primary)

                Text(book.words.isEmpty ? "这个单词本里还没有单词" : "没有找到匹配单词")
                    .font(.headline)
                    .foregroundStyle(AppColors.primaryText)

                Text(book.words.isEmpty ? "点一下按钮，先给这个单词本加一个英文单词吧。" : "换个关键词试试，或者清空搜索看看。")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.secondaryText)
                    .multilineTextAlignment(.center)

                if book.words.isEmpty {
                    Button("新增单词") {
                        isPresentingNewWord = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppColors.primary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(AppColors.card)
            .clipShape(RoundedRectangle(cornerRadius: AppStyle.cornerRadius, style: .continuous))
            .shadow(color: AppStyle.cardShadow, radius: 12, y: 8)
            .listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
    }

    func wordsSection(for book: WordBook) -> some View {
        Section {
            ForEach(filteredWords(in: book)) { word in
                ZStack {
                    WordCard(entry: word)

                    NavigationLink {
                        WordDetailView(bookID: book.id, mode: .edit(word))
                    } label: {
                        Color.clear
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .opacity(0)
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        wordStore.deleteWord(bookID: book.id, id: word.id)
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
            }
        }
    }

    func statCard(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppColors.secondaryText)

            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(AppColors.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(color.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: AppStyle.smallCornerRadius, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        WordBookDetailView(bookID: WordBook.mock.id)
            .environmentObject(WordStore())
    }
}
