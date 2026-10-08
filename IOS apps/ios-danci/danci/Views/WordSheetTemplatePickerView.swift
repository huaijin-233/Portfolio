import SwiftUI

struct WordSheetTemplatePickerView: View {
    @EnvironmentObject private var wordStore: WordStore

    let bookID: UUID

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    private var book: WordBook? {
        wordStore.book(with: bookID)
    }

    var body: some View {
        ZStack {
            PlayfulBackground()

            if let book {
                if book.words.isEmpty {
                    EmptyStateView(
                        title: "这个单词本里还没有单词",
                        message: "先加一些单词，再来导出表格。"
                    )
                    .padding(AppStyle.contentPadding)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 18) {
                            headerCard(for: book)

                            LazyVGrid(columns: columns, spacing: 14) {
                                ForEach(WordSheetTemplate.all) { template in
                                    NavigationLink {
                                        WordSheetPreviewView(bookID: book.id, template: template)
                                    } label: {
                                        templateCard(for: template)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(AppStyle.contentPadding)
                        .padding(.bottom, 24)
                    }
                }
            } else {
                EmptyStateView(
                    title: "这个单词本不见了",
                    message: "它可能已经被删除了，请返回【做表格】重新选择。"
                )
                .padding(AppStyle.contentPadding)
            }
        }
        .navigationTitle("选择表格")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppColors.backgroundTop.opacity(0.98), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

private extension WordSheetTemplatePickerView {
    func headerCard(for book: WordBook) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("选择一个表格模板")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(AppColors.primaryText)

            Text(book.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.secondaryText)

            Text("不同模板每页容量不同，会自动分页。")
                .font(.subheadline)
                .foregroundStyle(AppColors.secondaryText)

            Text("备注会自动整理成更简洁的释义。")
                .font(.footnote)
                .foregroundStyle(AppColors.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(AppColors.elevatedCard)
        .overlay(
            RoundedRectangle(cornerRadius: AppStyle.cornerRadius, style: .continuous)
                .stroke(AppColors.cardStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppStyle.cornerRadius, style: .continuous))
        .shadow(color: AppStyle.cardShadow, radius: 12, y: 8)
    }

    func templateCard(for template: WordSheetTemplate) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(template.assetName)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Text(template.title)
                .font(.headline)
                .foregroundStyle(AppColors.primaryText)

            Text("每页 \(template.wordsPerPage) 个词")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppColors.secondaryText)
        }
        .padding(14)
        .background(AppColors.elevatedCard)
        .overlay(
            RoundedRectangle(cornerRadius: AppStyle.smallCornerRadius, style: .continuous)
                .stroke(AppColors.cardStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppStyle.smallCornerRadius, style: .continuous))
        .shadow(color: AppStyle.cardShadow, radius: 10, y: 6)
    }
}

#Preview {
    NavigationStack {
        WordSheetTemplatePickerView(bookID: WordBook.mock.id)
            .environmentObject(WordStore())
    }
}
