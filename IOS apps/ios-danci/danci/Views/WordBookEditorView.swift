import SwiftUI

struct WordBookEditorView: View {
    enum Mode {
        case create
        case edit(WordBook)

        var title: String {
            switch self {
            case .create:
                return "新增单词本"
            case .edit:
                return "编辑单词本"
            }
        }

        var actionTitle: String {
            switch self {
            case .create:
                return "创建"
            case .edit:
                return "保存"
            }
        }
    }

    @EnvironmentObject private var wordStore: WordStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTitleFieldFocused: Bool

    let mode: Mode

    @State private var titleText: String
    @State private var errorMessage: String?

    init(mode: Mode) {
        self.mode = mode

        switch mode {
        case .create:
            _titleText = State(initialValue: "")
        case .edit(let book):
            _titleText = State(initialValue: book.title)
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            PlayfulBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    headerCard
                    titleInputCard

                    if case .edit(let book) = mode {
                        sourceCard(for: book)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(AppStyle.contentPadding)
                .padding(.bottom, 36)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationTitle(mode.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppColors.backgroundTop.opacity(0.98), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(mode.actionTitle) {
                    saveBook()
                }
                .fontWeight(.semibold)
            }
        }
        .onAppear {
            isTitleFieldFocused = true
        }
        .alert("保存失败", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }
}

private extension WordBookEditorView {
    var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(mode.title)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(AppColors.primaryText)

            Text("先创建一个单词本，再进入里面新增和编辑英文单词。单词本名称可以自由填写。")
                .font(.subheadline)
                .foregroundStyle(AppColors.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppStyle.cornerRadius, style: .continuous))
        .shadow(color: AppStyle.cardShadow, radius: 12, y: 8)
    }

    var titleInputCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("单词本名称")
                .font(.headline)
                .foregroundStyle(AppColors.primaryText)

            TextField("例如 高中英语第 1 章", text: $titleText)
                .focused($isTitleFieldFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(AppColors.background)
                .clipShape(RoundedRectangle(cornerRadius: AppStyle.smallCornerRadius, style: .continuous))

            Text("建议用容易区分的名字，之后在书架里会更好找。")
                .font(.footnote)
                .foregroundStyle(AppColors.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppStyle.cornerRadius, style: .continuous))
        .shadow(color: AppStyle.cardShadow, radius: 12, y: 8)
    }

    func sourceCard(for book: WordBook) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("来源")
                .font(.headline)
                .foregroundStyle(AppColors.primaryText)

            HStack {
                SourceBadge(source: book.source)
                Spacer()
                Text(book.source.subtitle)
                    .font(.footnote)
                    .foregroundStyle(AppColors.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppStyle.cornerRadius, style: .continuous))
    }

    func saveBook() {
        do {
            switch mode {
            case .create:
                _ = try wordStore.createManualBook(title: titleText)
            case .edit(let book):
                _ = try wordStore.updateBook(id: book.id, title: titleText)
            }

            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        WordBookEditorView(mode: .edit(.mock))
            .environmentObject(WordStore())
    }
}
