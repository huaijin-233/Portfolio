//
//  InkEditorComponents.swift
//  Ink
//
//  Created by Codex on 3/13/26.
//

import Combine
import SwiftUI

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

enum WriteTheme: String, CaseIterable, Identifiable, Sendable {
    case `default`
    case pink
    case blue
    case green
    case silver

    var id: String { rawValue }

    func displayName(for language: InkLanguage) -> String {
        switch (self, language) {
        case (.default, .english):
            return "Default"
        case (.default, .simplifiedChinese):
            return "默认"
        case (.pink, .english):
            return "Pink"
        case (.pink, .simplifiedChinese):
            return "粉"
        case (.blue, .english):
            return "Blue"
        case (.blue, .simplifiedChinese):
            return "蓝"
        case (.green, .english):
            return "Green"
        case (.green, .simplifiedChinese):
            return "绿"
        case (.silver, .english):
            return "Silver"
        case (.silver, .simplifiedChinese):
            return "银"
        }
    }
}

struct WriteThemePalette {
    let canvasStart: Color
    let canvasEnd: Color
    let sidebarStart: Color
    let sidebarEnd: Color
    let orbPrimary: Color
    let orbSecondary: Color
    let orbTertiary: Color
    let surfaceFill: Color
    let surfaceStroke: Color
    let elevatedSurfaceFill: Color
    let elevatedSurfaceStroke: Color
    let buttonFill: Color
    let buttonStroke: Color
    let pillFill: Color
    let pillStroke: Color
    let selectionStart: Color
    let selectionEnd: Color
    let accent: Color
    let accentMuted: Color
    let divider: Color
}

@MainActor
final class WriteThemeController: ObservableObject {
    @Published private(set) var theme: WriteTheme

    private let defaults: UserDefaults
    private let defaultsKey = "write.theme"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let storedValue = defaults.string(forKey: defaultsKey),
           let storedTheme = WriteTheme(rawValue: storedValue) {
            theme = storedTheme
        } else {
            theme = .default
        }
    }

    var palette: WriteThemePalette {
        switch theme {
        case .default:
            return WriteThemePalette(
                canvasStart: Color(red: 0.94, green: 0.92, blue: 0.87),
                canvasEnd: Color(red: 0.89, green: 0.88, blue: 0.84),
                sidebarStart: Color(red: 0.87, green: 0.84, blue: 0.78),
                sidebarEnd: Color(red: 0.82, green: 0.79, blue: 0.74),
                orbPrimary: Color.white.opacity(0.72),
                orbSecondary: Color(red: 0.80, green: 0.75, blue: 0.64).opacity(0.35),
                orbTertiary: Color.white.opacity(0.4),
                surfaceFill: Color.white.opacity(0.3),
                surfaceStroke: Color.white.opacity(0.42),
                elevatedSurfaceFill: Color.white.opacity(0.72),
                elevatedSurfaceStroke: Color.white.opacity(0.74),
                buttonFill: Color.white.opacity(0.72),
                buttonStroke: Color.white.opacity(0.8),
                pillFill: Color.white.opacity(0.5),
                pillStroke: Color.white.opacity(0.62),
                selectionStart: Color.white.opacity(0.98),
                selectionEnd: Color(red: 0.96, green: 0.94, blue: 0.89),
                accent: Color.black.opacity(0.74),
                accentMuted: Color(red: 0.63, green: 0.57, blue: 0.46).opacity(0.35),
                divider: Color.black.opacity(0.08)
            )
        case .pink:
            return WriteThemePalette(
                canvasStart: Color(red: 0.99, green: 0.94, blue: 0.95),
                canvasEnd: Color(red: 0.95, green: 0.88, blue: 0.91),
                sidebarStart: Color(red: 0.94, green: 0.85, blue: 0.89),
                sidebarEnd: Color(red: 0.89, green: 0.80, blue: 0.85),
                orbPrimary: Color.white.opacity(0.74),
                orbSecondary: Color(red: 0.91, green: 0.63, blue: 0.72).opacity(0.3),
                orbTertiary: Color(red: 1.0, green: 0.94, blue: 0.96).opacity(0.52),
                surfaceFill: Color.white.opacity(0.34),
                surfaceStroke: Color.white.opacity(0.5),
                elevatedSurfaceFill: Color.white.opacity(0.78),
                elevatedSurfaceStroke: Color.white.opacity(0.82),
                buttonFill: Color(red: 1.0, green: 0.97, blue: 0.98).opacity(0.84),
                buttonStroke: Color.white.opacity(0.92),
                pillFill: Color.white.opacity(0.56),
                pillStroke: Color.white.opacity(0.7),
                selectionStart: Color(red: 1.0, green: 0.98, blue: 0.99),
                selectionEnd: Color(red: 0.98, green: 0.92, blue: 0.95),
                accent: Color(red: 0.63, green: 0.33, blue: 0.43),
                accentMuted: Color(red: 0.91, green: 0.63, blue: 0.72).opacity(0.42),
                divider: Color(red: 0.29, green: 0.13, blue: 0.18).opacity(0.09)
            )
        case .blue:
            return WriteThemePalette(
                canvasStart: Color(red: 0.91, green: 0.98, blue: 0.97),
                canvasEnd: Color(red: 0.83, green: 0.94, blue: 0.92),
                sidebarStart: Color(red: 0.77, green: 0.90, blue: 0.88),
                sidebarEnd: Color(red: 0.70, green: 0.84, blue: 0.82),
                orbPrimary: Color.white.opacity(0.7),
                orbSecondary: Color(red: 0.34, green: 0.82, blue: 0.78).opacity(0.26),
                orbTertiary: Color(red: 0.92, green: 1.0, blue: 1.0).opacity(0.48),
                surfaceFill: Color.white.opacity(0.3),
                surfaceStroke: Color.white.opacity(0.46),
                elevatedSurfaceFill: Color.white.opacity(0.76),
                elevatedSurfaceStroke: Color.white.opacity(0.82),
                buttonFill: Color(red: 0.97, green: 1.0, blue: 0.99).opacity(0.84),
                buttonStroke: Color.white.opacity(0.94),
                pillFill: Color.white.opacity(0.55),
                pillStroke: Color.white.opacity(0.68),
                selectionStart: Color(red: 0.98, green: 1.0, blue: 1.0),
                selectionEnd: Color(red: 0.90, green: 0.98, blue: 0.97),
                accent: Color(red: 0.12, green: 0.54, blue: 0.55),
                accentMuted: Color(red: 0.34, green: 0.82, blue: 0.78).opacity(0.42),
                divider: Color(red: 0.05, green: 0.26, blue: 0.28).opacity(0.08)
            )
        case .green:
            return WriteThemePalette(
                canvasStart: Color(red: 0.93, green: 1.0, blue: 0.95),
                canvasEnd: Color(red: 0.85, green: 0.96, blue: 0.89),
                sidebarStart: Color(red: 0.79, green: 0.93, blue: 0.83),
                sidebarEnd: Color(red: 0.72, green: 0.87, blue: 0.77),
                orbPrimary: Color.white.opacity(0.7),
                orbSecondary: Color(red: 0.45, green: 0.88, blue: 0.58).opacity(0.24),
                orbTertiary: Color(red: 0.97, green: 1.0, blue: 0.97).opacity(0.5),
                surfaceFill: Color.white.opacity(0.31),
                surfaceStroke: Color.white.opacity(0.46),
                elevatedSurfaceFill: Color.white.opacity(0.76),
                elevatedSurfaceStroke: Color.white.opacity(0.82),
                buttonFill: Color(red: 0.98, green: 1.0, blue: 0.98).opacity(0.84),
                buttonStroke: Color.white.opacity(0.92),
                pillFill: Color.white.opacity(0.54),
                pillStroke: Color.white.opacity(0.68),
                selectionStart: Color(red: 0.99, green: 1.0, blue: 0.99),
                selectionEnd: Color(red: 0.91, green: 0.99, blue: 0.93),
                accent: Color(red: 0.19, green: 0.56, blue: 0.25),
                accentMuted: Color(red: 0.45, green: 0.88, blue: 0.58).opacity(0.38),
                divider: Color(red: 0.06, green: 0.22, blue: 0.08).opacity(0.08)
            )
        case .silver:
            return WriteThemePalette(
                canvasStart: Color(red: 0.95, green: 0.96, blue: 0.98),
                canvasEnd: Color(red: 0.86, green: 0.88, blue: 0.91),
                sidebarStart: Color(red: 0.84, green: 0.86, blue: 0.89),
                sidebarEnd: Color(red: 0.77, green: 0.79, blue: 0.83),
                orbPrimary: Color.white.opacity(0.68),
                orbSecondary: Color(red: 0.66, green: 0.71, blue: 0.8).opacity(0.22),
                orbTertiary: Color.white.opacity(0.45),
                surfaceFill: Color.white.opacity(0.28),
                surfaceStroke: Color.white.opacity(0.42),
                elevatedSurfaceFill: Color.white.opacity(0.74),
                elevatedSurfaceStroke: Color.white.opacity(0.8),
                buttonFill: Color.white.opacity(0.8),
                buttonStroke: Color.white.opacity(0.9),
                pillFill: Color.white.opacity(0.5),
                pillStroke: Color.white.opacity(0.64),
                selectionStart: Color.white.opacity(0.98),
                selectionEnd: Color(red: 0.93, green: 0.95, blue: 0.98),
                accent: Color(red: 0.29, green: 0.34, blue: 0.42),
                accentMuted: Color(red: 0.66, green: 0.71, blue: 0.8).opacity(0.38),
                divider: Color.black.opacity(0.07)
            )
        }
    }

    func setTheme(_ theme: WriteTheme) {
        guard self.theme != theme else {
            return
        }

        withAnimation(.spring(duration: 0.42, bounce: 0.08)) {
            self.theme = theme
        }
        defaults.set(theme.rawValue, forKey: defaultsKey)
    }
}

struct JournalTitleField: View {
    @EnvironmentObject private var localization: InkLocalization

    @Binding var text: String
    let isFocused: FocusState<Bool>.Binding

    var body: some View {
        ZStack(alignment: .leading) {
            if shouldShowPlaceholder {
                Text(localization.titlePlaceholder)
                    .font(.system(size: 44, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.primary.opacity(0.36))
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            TextField("", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 44, weight: .semibold, design: .serif))
                .lineSpacing(4)
                .foregroundStyle(Color.black.opacity(0.88))
                .focused(isFocused)
        }
        .animation(.easeOut(duration: 0.16), value: shouldShowPlaceholder)
    }

    private var shouldShowPlaceholder: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isFocused.wrappedValue
    }
}

struct LanguageMenuButton: View {
    @EnvironmentObject private var localization: InkLocalization
    @EnvironmentObject private var themeController: WriteThemeController

    var body: some View {
        Menu {
            ForEach(InkLanguage.allCases) { language in
                Button {
                    localization.setLanguage(language)
                } label: {
                    if localization.language == language {
                        Label(language.displayName, systemImage: "checkmark")
                    } else {
                        Text(language.displayName)
                    }
                }
            }
        } label: {
            ZStack {
                Image(systemName: "globe")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(Color.primary.opacity(0.84))
            .frame(width: 34, height: 34)
            .background(
                Circle()
                    .fill(themeController.palette.buttonFill)
            )
            .overlay(
                Circle()
                    .strokeBorder(themeController.palette.buttonStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help(localization.languageMenuHelp)
        .shadow(color: .black.opacity(0.05), radius: 12, y: 6)
        .animation(.easeInOut(duration: 0.18), value: localization.language)
    }
}

struct ThemeMenuButton: View {
    @EnvironmentObject private var localization: InkLocalization
    @EnvironmentObject private var themeController: WriteThemeController

    var body: some View {
        Menu {
            ForEach(WriteTheme.allCases) { theme in
                Button {
                    themeController.setTheme(theme)
                } label: {
                    if themeController.theme == theme {
                        Label(theme.displayName(for: localization.language), systemImage: "checkmark")
                    } else {
                        Text(theme.displayName(for: localization.language))
                    }
                }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(themeController.palette.buttonFill)

                Circle()
                    .strokeBorder(themeController.palette.buttonStroke, lineWidth: 1)

                Image(systemName: "paintpalette")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(0.84))

                Circle()
                    .fill(themeController.palette.accent)
                    .frame(width: 8, height: 8)
                    .offset(x: 10, y: 10)
            }
            .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .help(themeMenuHelp)
        .shadow(color: .black.opacity(0.05), radius: 12, y: 6)
        .animation(.easeInOut(duration: 0.2), value: themeController.theme)
    }

    private var themeMenuHelp: String {
        switch localization.language {
        case .english:
            return "Change Theme"
        case .simplifiedChinese:
            return "切换主题"
        }
    }
}

#if os(macOS)
struct SystemContainerBackgroundClearer: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        view.isHidden = true
        applyClearBackground(from: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        applyClearBackground(from: nsView)
    }

    private func applyClearBackground(from view: NSView) {
        DispatchQueue.main.async {
            var currentView: NSView? = view
            while let unwrappedView = currentView {
                unwrappedView.wantsLayer = true
                unwrappedView.layer?.backgroundColor = NSColor.clear.cgColor
                currentView = unwrappedView.superview
            }

            if let window = view.window {
                window.isOpaque = false
                window.backgroundColor = .clear
            }
        }
    }
}
#elseif os(iOS)
struct SystemContainerBackgroundClearer: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isHidden = true
        applyClearBackground(from: view)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        applyClearBackground(from: uiView)
    }

    private func applyClearBackground(from view: UIView) {
        DispatchQueue.main.async {
            var currentView: UIView? = view
            while let unwrappedView = currentView {
                unwrappedView.backgroundColor = .clear
                currentView = unwrappedView.superview
            }

            view.window?.backgroundColor = .clear
        }
    }
}
#endif
