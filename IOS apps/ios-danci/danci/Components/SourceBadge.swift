import SwiftUI

struct SourceBadge: View {
    let source: WordSource

    var body: some View {
        Label(source.title, systemImage: source.iconName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(tint.opacity(0.14))
            .clipShape(Capsule())
    }

    private var tint: Color {
        switch source {
        case .manual:
            return AppColors.peach
        case .normalScan:
            return AppColors.primary
        case .markedScan:
            return AppColors.mint
        }
    }
}

#Preview {
    SourceBadge(source: .manual)
        .padding()
}
