//
//  ThemeMenu.swift
//  Done
//
//  Created by Codex on 3/11/26.
//

import SwiftUI

struct ThemeMenu: View {
    @EnvironmentObject private var localization: LocalizationStore
    @EnvironmentObject private var themeStore: ThemeStore

    var body: some View {
        Menu {
            ForEach(AppTheme.allCases) { theme in
                Button {
                    themeStore.theme = theme
                } label: {
                    if themeStore.theme == theme {
                        Label(theme.shortLabel(for: localization.language), systemImage: "checkmark")
                    } else {
                        Text(theme.shortLabel(for: localization.language))
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                themeStore.theme.palette.accent,
                                themeStore.theme.palette.accentDeep
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 12, height: 12)

                Text(themeStore.theme.shortLabel(for: localization.language))
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(themeStore.theme.palette.accentDeep)
            .toolbarCapsule()
        }
    }
}
