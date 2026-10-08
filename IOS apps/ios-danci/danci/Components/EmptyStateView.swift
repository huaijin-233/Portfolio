import SwiftUI

struct EmptyStateView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppColors.lemon.opacity(0.9))
                    .frame(width: 92, height: 92)

                Image(systemName: "books.vertical")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(AppColors.primaryText)
            }

            Text(title)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(AppColors.primaryText)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppColors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}

#Preview {
    EmptyStateView(title: "还没有单词", message: "去扫描英文内容，或者手动新增一个单词吧")
}
