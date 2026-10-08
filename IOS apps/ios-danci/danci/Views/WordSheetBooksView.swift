import SwiftUI

struct WordSheetBooksView: View {
    @EnvironmentObject private var wordStore: WordStore
    @State private var searchText = ""
    @State private var contentVisible = false

    var body: some View {
        ZStack {
            PlayfulBackground()

            Group {
                if filteredBooks.isEmpty {
                    EmptyStateView(
                        title: exportableBooks.isEmpty ? "还没有可做表格的单词本" : "没有找到匹配单词本",
                        message: exportableBooks.isEmpty
                            ? "先去扫描一些英文内容，等单词本里有单词后，就能在这里做表格。"
                            : "换个关键词试试，也可以搜索单词本里的单词。"
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.bottom, AppStyle.floatingTabBarClearance * 0.4)
                } else {
                    List {
                        headerSection

                        ForEach(filteredBooks) { book in
                            ZStack {
                                tableBookCard(for: book)

                                NavigationLink {
                                    WordSheetTemplatePickerView(bookID: book.id)
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
        .navigationTitle("做表格")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppColors.backgroundTop.opacity(0.98), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .searchable(text: $searchText, prompt: "搜索可做表格的单词本或单词")
        .onAppear {
            guard !contentVisible else { return }
            withAnimation(AppStyle.softSpring.delay(0.05)) {
                contentVisible = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        WordSheetBooksView()
            .environmentObject(WordStore())
    }
}

private extension WordSheetBooksView {
    var exportableBooks: [WordBook] {
        wordStore.books.filter { !$0.words.isEmpty }
    }

    var filteredBooks: [WordBook] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return exportableBooks }

        return exportableBooks.filter { book in
            book.title.localizedCaseInsensitiveContains(query)
                || book.words.contains(where: {
                    $0.word.localizedCaseInsensitiveContains(query)
                        || $0.note.localizedCaseInsensitiveContains(query)
                })
        }
    }

    var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.white)
                            .frame(width: 64, height: 64)
                            .shadow(color: AppStyle.cardShadow.opacity(0.9), radius: 14, y: 8)

                        Image(systemName: "tablecells.badge.ellipsis")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(AppColors.primary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("做表格")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            .foregroundStyle(AppColors.primaryText)

                        Text("从单词本开始，整理出适合打印和导出的表格。")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.secondaryText)
                    }

                    Spacer(minLength: 0)
                }

                HStack(spacing: 12) {
                    statCard(title: "可做表格", value: "\(exportableBooks.count)", color: AppColors.background)
                    statCard(title: "单词", value: "\(exportableBooks.reduce(0) { $0 + $1.wordCount })", color: AppColors.background)
                }
            }
            .padding(22)
            .background(
                RoundedRectangle(cornerRadius: AppStyle.cornerRadius, style: .continuous)
                    .fill(AppColors.elevatedCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppStyle.cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.9), lineWidth: 1.2)
            )
            .shadow(color: AppStyle.cardShadow, radius: 14, y: 8)
            .opacity(contentVisible ? 1 : 0)
            .offset(y: contentVisible ? 0 : 20)
            .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 12, trailing: 20))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
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
        .background(color)
        .overlay(
            RoundedRectangle(cornerRadius: AppStyle.smallCornerRadius, style: .continuous)
                .stroke(AppColors.outline.opacity(0.7), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppStyle.smallCornerRadius, style: .continuous))
    }

    func tableBookCard(for book: WordBook) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(AppColors.background)
                        .frame(width: 58, height: 72)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(AppColors.outline.opacity(0.8), lineWidth: 1)
                        )

                    Image(systemName: "doc.text.image.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppColors.primary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 10) {
                        Text(book.title)
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(AppColors.primaryText)
                            .lineLimit(2)
                    }

                    HStack(spacing: 10) {
                        Label("\(book.wordCount) 个单词", systemImage: "text.book.closed")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColors.primaryText)

                        Text(book.updatedAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(AppColors.secondaryText)
                    }
                }
            }

            if book.previewWords.isEmpty {
                Text("还没有单词")
                    .font(.footnote)
                    .foregroundStyle(AppColors.secondaryText)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), spacing: 8)], spacing: 8) {
                    ForEach(book.previewWords, id: \.self) { word in
                        Text(word)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColors.primaryText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(AppColors.background)
                            .overlay(
                                Capsule()
                                    .stroke(AppColors.outline.opacity(0.75), lineWidth: 1)
                            )
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(18)
        .background(AppColors.elevatedCard)
        .overlay(
            RoundedRectangle(cornerRadius: AppStyle.cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.95), lineWidth: 1.2)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppStyle.cornerRadius, style: .continuous))
        .shadow(color: AppStyle.cardShadow.opacity(0.9), radius: 14, y: 8)
    }
}
