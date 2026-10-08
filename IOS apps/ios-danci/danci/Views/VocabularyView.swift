import SwiftUI

struct VocabularyView: View {
    @EnvironmentObject private var wordStore: WordStore
    @StateObject private var viewModel = VocabularyViewModel()
    @State private var contentVisible = false
    @State private var isMergingBooks = false
    @State private var selectedBookIDs: Set<UUID> = []
    @State private var mergeAlert: MergeAlert?

    var body: some View {
        ZStack {
            PlayfulBackground()

            Group {
                if filteredBooks.isEmpty {
                    EmptyStateView(
                        title: wordStore.books.isEmpty ? "书架上还没有单词本" : "没有找到匹配单词本",
                        message: wordStore.books.isEmpty
                            ? "去扫描英文内容，或者先手动新建一个单词本吧。"
                            : "换个关键词试试，也可以搜索单词本里的单词。"
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.bottom, AppStyle.floatingTabBarClearance * 0.4)
                } else {
                    List {
                        headerSection

                        ForEach(filteredBooks) { book in
                            if isMergingBooks {
                                mergeSelectionRow(for: book)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                            } else {
                                ZStack {
                                    WordBookCard(book: book)

                                    NavigationLink {
                                        WordBookDetailView(bookID: book.id)
                                    } label: {
                                        Color.clear
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    }
                                    .opacity(0)
                                }
                                .buttonStyle(.plain)
                                .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        wordStore.deleteBook(id: book.id)
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                            }
                        }

                        Color.clear
                            .frame(height: AppStyle.floatingTabBarClearance)
                            .listRowInsets(.init())
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("书架")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppColors.backgroundTop.opacity(0.98), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .searchable(text: $viewModel.searchText, prompt: "搜索单词本或单词")
        .alert(item: $mergeAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("知道了"))
            )
        }
        .onAppear {
            guard !contentVisible else { return }
            withAnimation(AppStyle.softSpring.delay(0.05)) {
                contentVisible = true
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if isMergingBooks {
                    HStack(spacing: 10) {
                        Button {
                            confirmMerge()
                        } label: {
                            Image(systemName: "checkmark")
                                .font(.system(size: 15, weight: .bold))
                                .frame(width: 36, height: 36)
                        }
                        .foregroundStyle(Color.white)
                        .background(AppColors.primary)
                        .clipShape(Circle())

                        Button {
                            exitMergeMode()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .bold))
                                .frame(width: 36, height: 36)
                        }
                        .foregroundStyle(AppColors.primaryText)
                        .background(AppColors.elevatedCard)
                        .clipShape(Circle())
                    }
                } else {
                    Button("合成") {
                        enterMergeMode()
                    }
                    .font(.subheadline.weight(.bold))
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                if !isMergingBooks {
                    Button {
                        viewModel.prepareForNewBook()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .bold))
                            .frame(width: 36, height: 36)
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.isPresentingNewBook) {
            NavigationStack {
                WordBookEditorView(mode: .create)
            }
        }
    }
}

#Preview {
    NavigationStack {
        VocabularyView()
            .environmentObject(WordStore())
    }
}

private struct MergeAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private extension VocabularyView {
    var filteredBooks: [WordBook] {
        let query = viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return wordStore.books }

        return wordStore.books.filter { book in
            book.title.localizedCaseInsensitiveContains(query)
                || book.words.contains(where: {
                    $0.word.localizedCaseInsensitiveContains(query)
                        || $0.note.localizedCaseInsensitiveContains(query)
                })
        }
    }

    var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("书架")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(AppColors.primaryText)

                    Text("收好每一本单词本。")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.secondaryText)
                }

                HStack(spacing: 12) {
                    statCard(title: "单词本", value: "\(wordStore.books.count)", color: AppColors.primary)
                    statCard(title: "单词", value: "\(wordStore.totalWordCount)", color: AppColors.mint)
                }
            }
            .padding(20)
            .background(AppColors.elevatedCard)
            .overlay(
                RoundedRectangle(cornerRadius: AppStyle.cornerRadius, style: .continuous)
                    .stroke(AppColors.cardStroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppStyle.cornerRadius, style: .continuous))
            .shadow(color: AppStyle.cardShadow, radius: 14, y: 8)
            .opacity(contentVisible ? 1 : 0)
            .offset(y: contentVisible ? 0 : 20)
            .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 12, trailing: 20))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
    }

    func mergeSelectionRow(for book: WordBook) -> some View {
        Button {
            toggleMergeSelection(for: book.id)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: selectedBookIDs.contains(book.id) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(selectedBookIDs.contains(book.id) ? AppColors.primary : AppColors.secondaryText)
                    .frame(width: 30)

                WordBookCard(book: book)
            }
        }
        .buttonStyle(.plain)
    }

    func enterMergeMode() {
        selectedBookIDs = []
        withAnimation(AppStyle.softSpring) {
            isMergingBooks = true
        }
    }

    func exitMergeMode() {
        selectedBookIDs = []
        withAnimation(AppStyle.softSpring) {
            isMergingBooks = false
        }
    }

    func toggleMergeSelection(for id: UUID) {
        if selectedBookIDs.contains(id) {
            selectedBookIDs.remove(id)
        } else {
            selectedBookIDs.insert(id)
        }
    }

    func confirmMerge() {
        guard selectedBookIDs.count >= 2 else {
            mergeAlert = MergeAlert(
                title: "还不能合成",
                message: "请至少选择两个单词本。"
            )
            return
        }

        do {
            _ = try wordStore.mergeBooks(ids: selectedBookIDs)
            exitMergeMode()
        } catch {
            mergeAlert = MergeAlert(
                title: "合成失败",
                message: error.localizedDescription
            )
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
        .padding(16)
        .background(color.opacity(0.16))
        .clipShape(RoundedRectangle(cornerRadius: AppStyle.smallCornerRadius, style: .continuous))
    }
}
