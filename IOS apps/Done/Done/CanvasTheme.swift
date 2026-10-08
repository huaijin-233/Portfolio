//
//  CanvasTheme.swift
//  Done
//
//  Created by Codex on 3/11/26.
//

import Combine
import SwiftUI

struct ThemePalette {
    let accent: Color
    let accentDeep: Color
    let accentSoft: Color
    let backgroundTop: Color
    let backgroundBottom: Color
    let surface: Color
    let surfaceMuted: Color
    let border: Color
    let textSecondary: Color
    let shadow: Color
    let warning: Color
    let overdue: Color
    let success: Color
}

enum AppTheme: String, CaseIterable, Identifiable {
    case tiffanyBlue
    case blushPink
    case softGray
    case velvetPurple
    case sageGreen

    var id: String { rawValue }

    func shortLabel(for language: AppLanguage) -> String {
        switch (self, language) {
        case (.tiffanyBlue, .english):
            return "Blue"
        case (.tiffanyBlue, .simplifiedChinese):
            return "蓝"
        case (.blushPink, .english):
            return "Pink"
        case (.blushPink, .simplifiedChinese):
            return "粉"
        case (.softGray, .english):
            return "Gray"
        case (.softGray, .simplifiedChinese):
            return "灰"
        case (.velvetPurple, .english):
            return "Purple"
        case (.velvetPurple, .simplifiedChinese):
            return "紫"
        case (.sageGreen, .english):
            return "Green"
        case (.sageGreen, .simplifiedChinese):
            return "绿"
        }
    }

    func displayName(for language: AppLanguage) -> String {
        switch (self, language) {
        case (.tiffanyBlue, .english):
            return "Tiffany Blue"
        case (.tiffanyBlue, .simplifiedChinese):
            return "蒂芙尼蓝"
        case (.blushPink, .english):
            return "Blush Pink"
        case (.blushPink, .simplifiedChinese):
            return "浅粉色"
        case (.softGray, .english):
            return "Soft Gray"
        case (.softGray, .simplifiedChinese):
            return "灰白简洁色"
        case (.velvetPurple, .english):
            return "Velvet Purple"
        case (.velvetPurple, .simplifiedChinese):
            return "紫色"
        case (.sageGreen, .english):
            return "Sage Green"
        case (.sageGreen, .simplifiedChinese):
            return "浅绿色"
        }
    }

    var palette: ThemePalette {
        switch self {
        case .tiffanyBlue:
            return ThemePalette(
                accent: Color(red: 0.17, green: 0.77, blue: 0.73),
                accentDeep: Color(red: 0.08, green: 0.48, blue: 0.50),
                accentSoft: Color(red: 0.84, green: 0.96, blue: 0.94),
                backgroundTop: Color(red: 0.95, green: 0.99, blue: 0.98),
                backgroundBottom: Color(red: 0.85, green: 0.95, blue: 0.94),
                surface: Color.white.opacity(0.92),
                surfaceMuted: Color(red: 0.93, green: 0.98, blue: 0.97),
                border: Color(red: 0.80, green: 0.92, blue: 0.90),
                textSecondary: Color(red: 0.27, green: 0.38, blue: 0.38),
                shadow: Color(red: 0.08, green: 0.48, blue: 0.50),
                warning: Color(red: 0.90, green: 0.63, blue: 0.16),
                overdue: Color(red: 0.80, green: 0.28, blue: 0.26),
                success: Color(red: 0.20, green: 0.61, blue: 0.39)
            )
        case .blushPink:
            return ThemePalette(
                accent: Color(red: 0.96, green: 0.70, blue: 0.79),
                accentDeep: Color(red: 0.78, green: 0.45, blue: 0.62),
                accentSoft: Color(red: 1.00, green: 0.92, blue: 0.95),
                backgroundTop: Color(red: 1.00, green: 0.97, blue: 0.98),
                backgroundBottom: Color(red: 0.98, green: 0.90, blue: 0.94),
                surface: Color.white.opacity(0.92),
                surfaceMuted: Color(red: 0.99, green: 0.94, blue: 0.96),
                border: Color(red: 0.95, green: 0.84, blue: 0.89),
                textSecondary: Color(red: 0.47, green: 0.33, blue: 0.41),
                shadow: Color(red: 0.78, green: 0.45, blue: 0.62),
                warning: Color(red: 0.91, green: 0.58, blue: 0.23),
                overdue: Color(red: 0.78, green: 0.28, blue: 0.35),
                success: Color(red: 0.30, green: 0.63, blue: 0.45)
            )
        case .softGray:
            return ThemePalette(
                accent: Color(red: 0.55, green: 0.58, blue: 0.63),
                accentDeep: Color(red: 0.31, green: 0.34, blue: 0.39),
                accentSoft: Color(red: 0.92, green: 0.93, blue: 0.95),
                backgroundTop: Color(red: 0.98, green: 0.98, blue: 0.99),
                backgroundBottom: Color(red: 0.91, green: 0.92, blue: 0.94),
                surface: Color.white.opacity(0.90),
                surfaceMuted: Color(red: 0.95, green: 0.95, blue: 0.96),
                border: Color(red: 0.84, green: 0.86, blue: 0.89),
                textSecondary: Color(red: 0.36, green: 0.39, blue: 0.44),
                shadow: Color(red: 0.40, green: 0.43, blue: 0.48),
                warning: Color(red: 0.78, green: 0.57, blue: 0.27),
                overdue: Color(red: 0.68, green: 0.31, blue: 0.32),
                success: Color(red: 0.33, green: 0.58, blue: 0.41)
            )
        case .velvetPurple:
            return ThemePalette(
                accent: Color(red: 0.59, green: 0.45, blue: 0.90),
                accentDeep: Color(red: 0.34, green: 0.22, blue: 0.62),
                accentSoft: Color(red: 0.92, green: 0.89, blue: 0.98),
                backgroundTop: Color(red: 0.97, green: 0.95, blue: 1.00),
                backgroundBottom: Color(red: 0.89, green: 0.86, blue: 0.97),
                surface: Color.white.opacity(0.91),
                surfaceMuted: Color(red: 0.95, green: 0.93, blue: 0.99),
                border: Color(red: 0.85, green: 0.81, blue: 0.95),
                textSecondary: Color(red: 0.37, green: 0.30, blue: 0.49),
                shadow: Color(red: 0.34, green: 0.22, blue: 0.62),
                warning: Color(red: 0.93, green: 0.63, blue: 0.24),
                overdue: Color(red: 0.78, green: 0.29, blue: 0.39),
                success: Color(red: 0.31, green: 0.63, blue: 0.47)
            )
        case .sageGreen:
            return ThemePalette(
                accent: Color(red: 0.58, green: 0.79, blue: 0.63),
                accentDeep: Color(red: 0.32, green: 0.55, blue: 0.37),
                accentSoft: Color(red: 0.91, green: 0.97, blue: 0.92),
                backgroundTop: Color(red: 0.96, green: 1.00, blue: 0.96),
                backgroundBottom: Color(red: 0.88, green: 0.96, blue: 0.89),
                surface: Color.white.opacity(0.91),
                surfaceMuted: Color(red: 0.94, green: 0.98, blue: 0.94),
                border: Color(red: 0.82, green: 0.92, blue: 0.82),
                textSecondary: Color(red: 0.31, green: 0.42, blue: 0.33),
                shadow: Color(red: 0.32, green: 0.55, blue: 0.37),
                warning: Color(red: 0.84, green: 0.63, blue: 0.24),
                overdue: Color(red: 0.74, green: 0.31, blue: 0.30),
                success: Color(red: 0.23, green: 0.57, blue: 0.31)
            )
        }
    }
}

@MainActor
final class ThemeStore: ObservableObject {
    @Published var theme: AppTheme {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: storageKey)
        }
    }

    private let storageKey = "done.theme.v1"

    init() {
        let savedValue = UserDefaults.standard.string(forKey: storageKey)
        theme = AppTheme(rawValue: savedValue ?? "") ?? .tiffanyBlue
    }
}

struct CanvasCardModifier: ViewModifier {
    @EnvironmentObject private var themeStore: ThemeStore

    let padding: CGFloat

    func body(content: Content) -> some View {
        let palette = themeStore.theme.palette

        content
            .padding(padding)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    palette.surface.opacity(0.98),
                                    palette.surfaceMuted.opacity(0.96)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.62),
                                    Color.white.opacity(0.10),
                                    .clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.72),
                                palette.border.opacity(0.92)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: palette.shadow.opacity(0.14), radius: 26, x: 0, y: 14)
            .shadow(color: Color.white.opacity(0.34), radius: 8, x: 0, y: -2)
    }
}

struct HeroCardModifier: ViewModifier {
    @EnvironmentObject private var themeStore: ThemeStore

    func body(content: Content) -> some View {
        let palette = themeStore.theme.palette

        content
            .padding(26)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    ThemeHeroSurface()

                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.20),
                                    Color.white.opacity(0.05),
                                    .clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: palette.shadow.opacity(0.22), radius: 30, x: 0, y: 14)
    }
}

struct ToolbarCapsuleModifier: ViewModifier {
    @EnvironmentObject private var themeStore: ThemeStore

    func body(content: Content) -> some View {
        let palette = themeStore.theme.palette

        content
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                palette.surface.opacity(0.98),
                                palette.surfaceMuted.opacity(0.92)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.68),
                                palette.border.opacity(0.9)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: palette.shadow.opacity(0.10), radius: 14, x: 0, y: 6)
    }
}

struct PremiumFieldModifier: ViewModifier {
    @EnvironmentObject private var themeStore: ThemeStore

    func body(content: Content) -> some View {
        let palette = themeStore.theme.palette

        content
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                palette.surfaceMuted.opacity(0.96),
                                palette.surface.opacity(0.94)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.70),
                                palette.border.opacity(0.92)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

struct PrimaryActionButtonModifier: ViewModifier {
    @EnvironmentObject private var themeStore: ThemeStore

    let isEnabled: Bool

    func body(content: Content) -> some View {
        let palette = themeStore.theme.palette

        content
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: isEnabled
                                ? [palette.accent, palette.accentDeep]
                                : [palette.accent.opacity(0.42), palette.accentDeep.opacity(0.34)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(isEnabled ? 0.18 : 0.08), lineWidth: 1)
            )
            .shadow(color: palette.shadow.opacity(isEnabled ? 0.18 : 0.08), radius: 18, x: 0, y: 10)
    }
}

extension View {
    func canvasCard(padding: CGFloat = 18) -> some View {
        modifier(CanvasCardModifier(padding: padding))
    }

    func heroCard() -> some View {
        modifier(HeroCardModifier())
    }

    func toolbarCapsule() -> some View {
        modifier(ToolbarCapsuleModifier())
    }

    func premiumField() -> some View {
        modifier(PremiumFieldModifier())
    }

    func primaryActionButton(isEnabled: Bool = true) -> some View {
        modifier(PrimaryActionButtonModifier(isEnabled: isEnabled))
    }
}

struct MetricBadge: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(title)
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.82))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.11))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SectionHeader<Trailing: View>: View {
    @EnvironmentObject private var themeStore: ThemeStore

    let title: String
    let subtitle: String?
    @ViewBuilder let trailing: Trailing

    init(title: String, subtitle: String? = nil, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        let palette = themeStore.theme.palette

        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 23, weight: .bold, design: .serif))

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(palette.textSecondary)
                }
            }

            Spacer(minLength: 8)

            trailing
        }
    }
}

struct ThemedScreenBackground: View {
    @EnvironmentObject private var themeStore: ThemeStore

    var body: some View {
        let palette = themeStore.theme.palette

        ZStack {
            LinearGradient(
                colors: [palette.backgroundTop, palette.backgroundBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            ThemeBackdropDecoration()
        }
        .ignoresSafeArea()
    }
}

private struct ThemeHeroSurface: View {
    @EnvironmentObject private var themeStore: ThemeStore

    var body: some View {
        let palette = themeStore.theme.palette

        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [palette.accent, palette.accentDeep],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            ThemeHeroDecoration(theme: themeStore.theme)
        }
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
    }
}

private struct ThemeBackdropDecoration: View {
    @EnvironmentObject private var themeStore: ThemeStore

    var body: some View {
        let palette = themeStore.theme.palette

        ZStack {
            Circle()
                .fill(palette.accent.opacity(0.16))
                .frame(width: 240, height: 240)
                .blur(radius: 20)
                .offset(x: 140, y: -280)

            Circle()
                .fill(palette.accentDeep.opacity(0.10))
                .frame(width: 220, height: 220)
                .blur(radius: 25)
                .offset(x: -150, y: -120)

            Circle()
                .fill(palette.accent.opacity(0.08))
                .frame(width: 280, height: 280)
                .blur(radius: 30)
                .offset(x: -120, y: 320)

            RoundedRectangle(cornerRadius: 72, style: .continuous)
                .stroke(palette.border.opacity(0.30), lineWidth: 1)
                .frame(width: 320, height: 320)
                .rotationEffect(.degrees(16))
                .offset(x: 118, y: 126)

            RoundedRectangle(cornerRadius: 64, style: .continuous)
                .stroke(Color.white.opacity(0.26), lineWidth: 1)
                .frame(width: 250, height: 250)
                .rotationEffect(.degrees(-14))
                .offset(x: -150, y: 232)
        }
    }
}

private struct ThemeHeroDecoration: View {
    let theme: AppTheme

    @ViewBuilder
    var body: some View {
        switch theme {
        case .tiffanyBlue:
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.16))
                    .frame(width: 180, height: 180)
                    .offset(x: 110, y: -55)

                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 180, height: 54)
                    .rotationEffect(.degrees(-28))
                    .offset(x: 82, y: 58)
            }
        case .blushPink:
            ZStack {
                Ellipse()
                    .fill(Color.white.opacity(0.14))
                    .frame(width: 210, height: 120)
                    .rotationEffect(.degrees(-18))
                    .offset(x: 78, y: -26)

                Circle()
                    .stroke(Color.white.opacity(0.22), lineWidth: 2)
                    .frame(width: 130, height: 130)
                    .offset(x: 128, y: 66)
            }
        case .softGray:
            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 170, height: 70)
                    .rotationEffect(.degrees(-10))
                    .offset(x: 88, y: -30)

                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1.5)
                    .frame(width: 140, height: 100)
                    .offset(x: 118, y: 54)
            }
        case .velvetPurple:
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 170, height: 170)
                    .offset(x: 120, y: -52)

                Ellipse()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 200, height: 82)
                    .rotationEffect(.degrees(24))
                    .offset(x: 72, y: 70)
            }
        case .sageGreen:
            ZStack {
                Ellipse()
                    .fill(Color.white.opacity(0.13))
                    .frame(width: 170, height: 90)
                    .rotationEffect(.degrees(-30))
                    .offset(x: 110, y: -30)

                Ellipse()
                    .stroke(Color.white.opacity(0.18), lineWidth: 2)
                    .frame(width: 120, height: 170)
                    .rotationEffect(.degrees(22))
                    .offset(x: 110, y: 54)
            }
        }
    }
}
