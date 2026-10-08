//
//  InkIOSApp.swift
//  Ink
//
//  Created by Codex on 3/14/26.
//

import SwiftUI

@main
struct InkIOSApp: App {
    @StateObject private var store = JournalStore()
    @StateObject private var localization = InkLocalization()
    @StateObject private var themeController = WriteThemeController()

    var body: some Scene {
        WindowGroup {
            PhoneJournalRootView()
                .environmentObject(store)
                .environmentObject(localization)
                .environmentObject(themeController)
                .environment(\.locale, localization.locale)
                .preferredColorScheme(.light)
        }
    }
}
