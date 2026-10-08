import SwiftUI

struct PlayfulBackground: View {
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()

            Ellipse()
                .fill(AppColors.lemon.opacity(0.42))
                .frame(width: 250, height: 170)
                .offset(x: -120, y: -320)

            Ellipse()
                .fill(AppColors.primary.opacity(0.16))
                .frame(width: 300, height: 210)
                .offset(x: 120, y: -180)

            Circle()
                .fill(AppColors.mint.opacity(0.22))
                .frame(width: 220, height: 220)
                .offset(x: 160, y: 120)

            Circle()
                .fill(AppColors.peach.opacity(0.24))
                .frame(width: 200, height: 200)
                .offset(x: 130, y: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
}

#Preview {
    PlayfulBackground()
}
