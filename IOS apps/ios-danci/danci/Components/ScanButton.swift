import SwiftUI

struct ScanButton: View {
    let isScanning: Bool
    let modeTitle: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 112, height: 112)

                    Image(systemName: isScanning ? "hourglass" : "camera.viewfinder")
                        .font(.system(size: 48, weight: .semibold))
                }

                VStack(spacing: 8) {
                    Text(isScanning ? "正在扫描" : "开始扫描")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                }
            }
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .frame(height: 288)
            .padding(30)
            .background(tint)
            .clipShape(RoundedRectangle(cornerRadius: 38, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 38, style: .continuous)
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
            )
            .shadow(color: tint.opacity(0.22), radius: 18, y: 10)
        }
        .buttonStyle(SoftLiftButtonStyle())
        .disabled(isScanning)
    }
}

#Preview {
    ScanButton(isScanning: false, modeTitle: "普通模式", tint: AppColors.primary, action: {})
        .padding()
}

private struct SoftLiftButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .brightness(configuration.isPressed ? -0.02 : 0)
            .animation(AppStyle.quickSpring, value: configuration.isPressed)
    }
}
