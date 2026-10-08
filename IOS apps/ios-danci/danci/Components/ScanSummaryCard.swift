import SwiftUI

struct ScanSummaryCard: View {
    let summary: ScanSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(summary.title)
                        .font(.headline)
                        .foregroundStyle(AppColors.primaryText)

                    Text(summary.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppColors.secondaryText)
                }

                Spacer()

                Image(systemName: summary.mode.iconName)
                    .font(.title2)
                    .foregroundStyle(AppColors.primary)
                    .padding(12)
                    .background(AppColors.background)
                    .clipShape(Circle())
            }

            HStack(spacing: 10) {
                metricPill(title: "新增", value: "\(summary.addedCount)", color: AppColors.primary)
                metricPill(title: "识别", value: "\(summary.detectedCount)", color: AppColors.mint)
            }

            if let createdBookTitle = summary.createdBookTitle {
                Label("单词本：\(createdBookTitle)", systemImage: "books.vertical")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppColors.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(AppColors.primary.opacity(0.12))
                    .clipShape(Capsule())
            }

            if !summary.previewWords.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 86), spacing: 8)], spacing: 8) {
                    ForEach(summary.previewWords, id: \.self) { word in
                        Text(word)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppColors.primaryText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(AppColors.background)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppStyle.cornerRadius, style: .continuous))
        .shadow(color: AppStyle.cardShadow, radius: 12, y: 8)
    }

    private func metricPill(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .foregroundStyle(AppColors.primaryText)

            Text(title)
                .font(.caption)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: AppStyle.smallCornerRadius, style: .continuous))
    }
}

#Preview {
    ScanSummaryCard(
        summary: ScanSummary(
            mode: .marked,
            pageCount: 1,
            detectedCount: 12,
            addedCount: 5,
            createdBookTitle: "标记扫描 4月9日 17:40",
            previewWords: ["effort", "gaze", "outline", "glow"]
        )
    )
    .padding()
}
