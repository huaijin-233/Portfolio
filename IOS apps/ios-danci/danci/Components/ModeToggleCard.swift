import SwiftUI

struct ModeToggleCard: View {
    @Binding var selectedMode: ScanMode
    @Binding var detailedTranslationEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("扫描模式")
                    .font(.headline)
                    .foregroundStyle(AppColors.primaryText)
            }

            HStack(spacing: 10) {
                ForEach(ScanMode.allCases) { mode in
                    Button {
                        withAnimation(AppStyle.softSpring) {
                            selectedMode = mode
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: mode.iconName)
                                .font(.body.weight(.semibold))

                            Text(mode.title)
                                .font(.subheadline.weight(.semibold))

                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 56, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(cardBackground(for: mode))
                        .foregroundStyle(selectedMode == mode ? Color.white : AppColors.primaryText)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(ModeToggleLiftButtonStyle())
                }
            }

            Toggle(isOn: $detailedTranslationEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("详细翻译")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.primaryText)

                    Text("打开后会尽量保留更多常见意思。")
                        .font(.caption)
                        .foregroundStyle(AppColors.secondaryText)
                }
            }
            .toggleStyle(.switch)
            .tint(AppColors.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(AppColors.background)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .padding(16)
        .background(AppColors.elevatedCard)
        .overlay(
            RoundedRectangle(cornerRadius: AppStyle.cornerRadius, style: .continuous)
                .stroke(AppColors.cardStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppStyle.cornerRadius, style: .continuous))
        .shadow(color: AppStyle.cardShadow, radius: 14, y: 8)
        .animation(AppStyle.softSpring, value: selectedMode)
    }

    func cardBackground(for mode: ScanMode) -> Color {
        if selectedMode == mode {
            return mode == .normal ? AppColors.primary : AppColors.peach
        }

        return AppColors.background
    }
}

#Preview {
    ModeToggleCard(
        selectedMode: .constant(.normal),
        detailedTranslationEnabled: .constant(false)
    )
        .padding()
}

private struct ModeToggleLiftButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .brightness(configuration.isPressed ? -0.02 : 0)
            .animation(AppStyle.quickSpring, value: configuration.isPressed)
    }
}
