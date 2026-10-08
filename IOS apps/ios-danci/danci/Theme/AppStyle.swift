import SwiftUI

enum AppStyle {
    static let cornerRadius: CGFloat = 30
    static let smallCornerRadius: CGFloat = 20
    static let contentPadding: CGFloat = 20
    static let pageTopSpacing: CGFloat = 16
    static let floatingTabBarClearance: CGFloat = 110
    static let cardShadow = Color.black.opacity(0.07)
    static let softSpring = Animation.spring(response: 0.42, dampingFraction: 0.84)
    static let quickSpring = Animation.spring(response: 0.30, dampingFraction: 0.82)
}
