import SwiftUI

struct WordBookCard: View {
    let book: WordBook

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(AppColors.sunshine)
                        .frame(width: 58, height: 72)

                    Image(systemName: "books.vertical.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppColors.primaryText)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 10) {
                        Text(book.title)
                            .font(.headline)
                            .foregroundStyle(AppColors.primaryText)
                            .lineLimit(2)

                        Spacer(minLength: 8)
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
                            .background(Color.white)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(18)
        .background(AppColors.sunshineSoft)
        .clipShape(RoundedRectangle(cornerRadius: AppStyle.cornerRadius, style: .continuous))
        .shadow(color: AppColors.sunshine.opacity(0.18), radius: 12, y: 8)
    }
}

#Preview {
    WordBookCard(book: .mock)
        .padding()
}
