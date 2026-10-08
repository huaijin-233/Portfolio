//
//  LanguageMenu.swift
//  Done
//
//  Created by Codex on 3/11/26.
//

import SwiftUI

struct LanguageMenu: View {
    @EnvironmentObject private var localization: LocalizationStore
    @EnvironmentObject private var themeStore: ThemeStore

    var body: some View {
        Menu {
            ForEach(AppLanguage.allCases) { language in
                Button {
                    localization.language = language
                } label: {
                    if localization.language == language {
                        Label(localization.label(for: language), systemImage: "checkmark")
                    } else {
                        Text(localization.label(for: language))
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                Text(localization.text(.language))
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(themeStore.theme.palette.accentDeep)
            .toolbarCapsule()
        }
    }
}
