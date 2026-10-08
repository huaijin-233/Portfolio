import SwiftUI

struct StudySessionView: View {
    @EnvironmentObject private var wordStore: WordStore
    @StateObject private var viewModel = StudySessionViewModel()
    @State private var contentVisible = false

    let bookID: UUID

    private var book: WordBook? {
        wordStore.book(with: bookID)
    }

    private var words: [WordEntry] {
        book?.words ?? []
    }

    private var currentWord: WordEntry? {
        viewModel.currentWord(in: words)
    }

    private var wordIDs: [UUID] {
        words.map(\.id)
    }

    var body: some View {
        ZStack(alignment: .top) {
            PlayfulBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    if let book {
                        headerCard(for: book)
                            .opacity(contentVisible ? 1 : 0)
                            .offset(y: contentVisible ? 0 : 18)

                        if words.isEmpty {
                            emptyWordsCard(for: book)
                        } else {
                            navigationCard
                            wordCard
                            meaningToggleCard
                            meaningCard
                        }
                    } else {
                        EmptyStateView(
                            title: "这个单词本不见了",
                            message: "它可能已经被删除了，请返回背单词页重新选择。"
                        )
                        .frame(maxWidth: .infinity, minHeight: 420)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(AppStyle.contentPadding)
                .padding(.bottom, 36)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationTitle(book?.title ?? "背单词")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppColors.backgroundTop.opacity(0.98), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            viewModel.sync(with: words)
            guard !contentVisible else { return }
            withAnimation(AppStyle.softSpring.delay(0.04)) {
                contentVisible = true
            }
        }
        .onChange(of: wordIDs) { _, _ in
            viewModel.sync(with: words)
        }
        .animation(AppStyle.softSpring, value: viewModel.isMeaningVisible)
        .animation(AppStyle.softSpring, value: currentWord?.id)
    }
}

#Preview {
    NavigationStack {
        StudySessionView(bookID: WordBook.mock.id)
            .environmentObject(WordStore())
    }
}

private extension StudySessionView {
    var currentWordIndexText: String {
        guard let currentIndex = viewModel.currentIndex(in: words) else {
            return "0 / 0"
        }

        return "\(currentIndex + 1) / \(words.count)"
    }

    var progressValue: Double {
        guard let currentIndex = viewModel.currentIndex(in: words),
              !words.isEmpty else {
            return 0
        }

        return Double(currentIndex + 1) / Double(words.count)
    }

    var navigationCard: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.goPrevious(in: words)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.bordered)
            .tint(AppColors.primary)
            .disabled(!viewModel.canGoPrevious(in: words))

            VStack(spacing: 8) {
                Text("进度")
                    .font(.caption)
                    .foregroundStyle(AppColors.secondaryText)

                Text(currentWordIndexText)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(AppColors.primaryText)

                ProgressView(value: progressValue)
                    .tint(AppColors.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)

            Button {
                viewModel.goNext(in: words)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.primary)
            .disabled(!viewModel.canGoNext(in: words))
        }
        .padding(18)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppStyle.cornerRadius, style: .continuous))
        .shadow(color: AppStyle.cardShadow, radius: 12, y: 8)
    }

    var wordCard: some View {
        VStack(spacing: 18) {
            Text(currentWord?.word ?? "-")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.primaryText)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
                .lineLimit(2)
                .contentTransition(.opacity)

            HStack(spacing: 10) {
                Image(systemName: "book.pages")
                    .foregroundStyle(AppColors.primary)

                Text("来自《\(book?.title ?? "")》")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppColors.secondaryText)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 20)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: AppStyle.cardShadow, radius: 16, y: 10)
    }

    var meaningToggleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $viewModel.isMeaningVisible) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.isMeaningVisible ? "隐藏意思" : "显示意思")
                        .font(.headline)
                        .foregroundStyle(AppColors.primaryText)

                    Text("先想一想，再看答案。")
                        .font(.footnote)
                        .foregroundStyle(AppColors.secondaryText)
                }
            }
            .tint(AppColors.primary)
        }
        .padding(18)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppStyle.cornerRadius, style: .continuous))
        .shadow(color: AppStyle.cardShadow, radius: 12, y: 8)
    }

    var meaningCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("意思", systemImage: viewModel.isMeaningVisible ? "eye.fill" : "eye.slash")
                .font(.headline)
                .foregroundStyle(AppColors.primaryText)

            if viewModel.isMeaningVisible {
                if let currentWord, !currentWord.note.isEmpty {
                    Text(currentWord.note)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(AppColors.primaryText)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("这个单词还没有意思。")
                            .font(.body)
                            .foregroundStyle(AppColors.primaryText)

                        Text("可以回到单词本里补充备注。")
                            .font(.footnote)
                            .foregroundStyle(AppColors.secondaryText)
                    }
                }
            } else {
                Text("先自己回忆，再打开查看。")
                    .font(.body)
                    .foregroundStyle(AppColors.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppStyle.cornerRadius, style: .continuous))
        .shadow(color: AppStyle.cardShadow, radius: 12, y: 8)
    }

    func headerCard(for book: WordBook) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppColors.lemon.opacity(0.9))
                        .frame(width: 58, height: 58)

                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(AppColors.primaryText)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(book.title)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(AppColors.primaryText)

                    Text("\(book.wordCount) 个单词")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.secondaryText)
                }
            }

            Text("先看词，再看意思。")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppColors.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppStyle.cornerRadius, style: .continuous))
        .shadow(color: AppStyle.cardShadow, radius: 16, y: 10)
    }

    func emptyWordsCard(for book: WordBook) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "text.badge.plus")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(AppColors.primary)

            Text("这个单词本里还没有单词")
                .font(.headline)
                .foregroundStyle(AppColors.primaryText)

            Text("先回到《\(book.title)》里加几个单词，这里就能开始背了。")
                .font(.subheadline)
                .foregroundStyle(AppColors.secondaryText)
                .multilineTextAlignment(.center)

            NavigationLink {
                WordBookDetailView(bookID: book.id)
            } label: {
                Label("去这个单词本加单词", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppStyle.cornerRadius, style: .continuous))
        .shadow(color: AppStyle.cardShadow, radius: 12, y: 8)
    }

}
