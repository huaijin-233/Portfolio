import SwiftUI

struct WordCard: View {
    let entry: WordEntry

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(badgeColor.opacity(0.16))
                    .frame(width: 50, height: 50)

                Text(String(entry.word.prefix(1)).uppercased())
                    .font(.headline.weight(.bold))
                    .foregroundStyle(badgeColor)
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .top) {
                    Text(entry.word)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(AppColors.primaryText)
                        .lineLimit(1)

                    Spacer()

                    SourceBadge(source: entry.source)
                }

                if !entry.note.isEmpty {
                    Text(entry.note)
                        .font(.subheadline)
                        .foregroundStyle(AppColors.secondaryText)
                        .lineLimit(3)
                }

                Text(entry.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(AppColors.secondaryText)
            }
        }
        .padding(18)
        .background(AppColors.elevatedCard)
        .overlay(
            RoundedRectangle(cornerRadius: AppStyle.cornerRadius, style: .continuous)
                .stroke(AppColors.cardStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppStyle.cornerRadius, style: .continuous))
        .shadow(color: AppStyle.cardShadow.opacity(0.7), radius: 10, y: 6)
    }
}

#Preview {
    WordCard(entry: .mock)
        .padding()
}

private extension WordCard {
    var badgeColor: Color {
        switch entry.source {
        case .manual:
            return AppColors.peach
        case .normalScan:
            return AppColors.primary
        case .markedScan:
            return AppColors.mint
        }
    }
}
