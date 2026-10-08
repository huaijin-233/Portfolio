import SwiftUI

struct StudyView: View {
    @EnvironmentObject private var wordStore: WordStore
    @State private var contentVisible = false

    var body: some View {
        ZStack {
            PlayfulBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    headerSection
                        .opacity(contentVisible ? 1 : 0)
                        .offset(y: contentVisible ? 0 : 20)

                    if wordStore.books.isEmpty {
                        EmptyStateView(
                            title: "还没有可以背的单词本",
                            message: "先去扫描，或者去书架新建一本。"
                        )
                        .frame(maxWidth: .infinity, minHeight: 340)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("开始练习")
                                .font(.headline)
                                .foregroundStyle(AppColors.primaryText)

                            ForEach(wordStore.books) { book in
                                NavigationLink {
                                    StudySessionView(bookID: book.id)
                                } label: {
                                    studyBookCard(for: book)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .opacity(contentVisible ? 1 : 0)
                        .offset(y: contentVisible ? 0 : 26)
                    }
                }
                .padding(.horizontal, AppStyle.contentPadding)
                .padding(.top, AppStyle.pageTopSpacing + 4)
                .padding(.bottom, AppStyle.floatingTabBarClearance)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("背单词")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppColors.backgroundTop.opacity(0.98), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            guard !contentVisible else { return }
            withAnimation(AppStyle.softSpring.delay(0.06)) {
                contentVisible = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        StudyView()
            .environmentObject(WordStore())
    }
}

private extension StudyView {
    var headerSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Text("背单词")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(AppColors.primaryText)

                Text("选一本到练习。")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.secondaryText)
            }

            HStack(spacing: 12) {
                statCard(title: "书本", value: "\(wordStore.books.count)", color: AppColors.primary)
                statCard(title: "词量", value: "\(wordStore.totalWordCount)", color: AppColors.lemon)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.elevatedCard)
        .overlay(
            RoundedRectangle(cornerRadius: AppStyle.cornerRadius, style: .continuous)
                .stroke(AppColors.cardStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppStyle.cornerRadius, style: .continuous))
        .shadow(color: AppStyle.cardShadow, radius: 16, y: 10)
    }

    func studyBookCard(for book: WordBook) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(AppColors.primary.opacity(0.14))
                    .frame(width: 64, height: 84)

                Image(systemName: "book.closed.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(AppColors.primary)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(book.title)
                    .font(.headline)
                    .foregroundStyle(AppColors.primaryText)
                    .lineLimit(2)

                HStack(spacing: 10) {
                    Label("\(book.wordCount) 个词", systemImage: "text.book.closed")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.primaryText)

                    if !book.previewWords.isEmpty {
                        Text(book.previewWords.prefix(2).joined(separator: " · "))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColors.secondaryText)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Text(book.words.isEmpty ? "先去加单词" : "开始练习")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(book.words.isEmpty ? AppColors.secondaryText : AppColors.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background((book.words.isEmpty ? AppColors.background : AppColors.primary).opacity(0.12))
                    .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .background(AppColors.elevatedCard)
        .overlay(
            RoundedRectangle(cornerRadius: AppStyle.cornerRadius, style: .continuous)
                .stroke(AppColors.cardStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppStyle.cornerRadius, style: .continuous))
        .shadow(color: AppStyle.cardShadow, radius: 12, y: 8)
        .scaleEffect(1)
        .animation(AppStyle.quickSpring, value: book.words.count)
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
