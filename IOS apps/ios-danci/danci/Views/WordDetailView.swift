import SwiftUI

struct WordDetailView: View {
    enum Mode {
        case create
        case edit(WordEntry)

        var title: String {
            switch self {
            case .create:
                return "新增单词"
            case .edit:
                return "编辑单词"
            }
        }

        var actionTitle: String {
            switch self {
            case .create:
                return "添加"
            case .edit:
                return "保存"
            }
        }
    }

    @EnvironmentObject private var wordStore: WordStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isWordFieldFocused: Bool

    let bookID: UUID
    let mode: Mode

    @State private var wordText: String
    @State private var noteText: String
    @State private var errorMessage: String?

    init(bookID: UUID, mode: Mode) {
        self.bookID = bookID
        self.mode = mode

        switch mode {
        case .create:
            _wordText = State(initialValue: "")
            _noteText = State(initialValue: "")
        case .edit(let entry):
            _wordText = State(initialValue: entry.word)
            _noteText = State(initialValue: entry.note)
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            PlayfulBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    headerCard
                    wordInputCard
                    noteInputCard

                    if case .edit(let entry) = mode {
                        sourceCard(source: entry.source)
                        deleteCard(for: entry)
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
                    saveWord()
                }
                .fontWeight(.semibold)
            }
        }
        .onAppear {
            if case .create = mode {
                isWordFieldFocused = true
            }
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

#Preview {
    NavigationStack {
        WordDetailView(bookID: WordBook.mock.id, mode: .edit(.mock))
            .environmentObject(WordStore())
    }
}

private extension WordDetailView {
    var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(mode.title)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(AppColors.primaryText)

            Text("当前单词本：\(wordStore.book(with: bookID)?.title ?? "未找到单词本")")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.primary)

            Text("只支持英文单词。你可以修改单词、补充备注，也可以删除当前条目。")
                .font(.subheadline)
                .foregroundStyle(AppColors.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppStyle.cornerRadius, style: .continuous))
        .shadow(color: AppStyle.cardShadow, radius: 12, y: 8)
    }

    var wordInputCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("单词")
                .font(.headline)
                .foregroundStyle(AppColors.primaryText)

            TextField("例如 effort", text: $wordText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isWordFieldFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(AppColors.background)
                .clipShape(RoundedRectangle(cornerRadius: AppStyle.smallCornerRadius, style: .continuous))

            Text("输入英文单词即可，保存时会自动统一成小写。")
                .font(.footnote)
                .foregroundStyle(AppColors.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppStyle.cornerRadius, style: .continuous))
        .shadow(color: AppStyle.cardShadow, radius: 12, y: 8)
    }

    var noteInputCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("备注")
                .font(.headline)
                .foregroundStyle(AppColors.primaryText)

            TextEditor(text: $noteText)
                .frame(minHeight: 150)
                .padding(10)
                .scrollContentBackground(.hidden)
                .background(AppColors.background)
                .clipShape(RoundedRectangle(cornerRadius: AppStyle.smallCornerRadius, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppStyle.cornerRadius, style: .continuous))
        .shadow(color: AppStyle.cardShadow, radius: 12, y: 8)
    }

    func sourceCard(source: WordSource) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("来源")
                .font(.headline)
                .foregroundStyle(AppColors.primaryText)

            HStack {
                SourceBadge(source: source)
                Spacer()
                Text(source.subtitle)
                    .font(.footnote)
                    .foregroundStyle(AppColors.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppStyle.cornerRadius, style: .continuous))
    }

    func deleteCard(for entry: WordEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("删除当前单词")
                .font(.headline)
                .foregroundStyle(AppColors.primaryText)

            Button(role: .destructive) {
                wordStore.deleteWord(bookID: bookID, id: entry.id)
                dismiss()
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("删除这个单词")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.danger)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppStyle.cornerRadius, style: .continuous))
    }

    func saveWord() {
        do {
            switch mode {
            case .create:
                try wordStore.addWord(toBook: bookID, word: wordText, note: noteText)
            case .edit(let entry):
                try wordStore.updateWord(bookID: bookID, id: entry.id, word: wordText, note: noteText)
            }

            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
