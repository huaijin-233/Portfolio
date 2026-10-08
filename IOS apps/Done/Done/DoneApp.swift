//
//  DoneApp.swift
//  Done
//
//  Created by Huaijin233 on 3/11/26.
//

import SwiftUI

@main
struct DoneApp: App {
    @StateObject private var localization = LocalizationStore()
    @StateObject private var themeStore = ThemeStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
            .environmentObject(localization)
            .environmentObject(themeStore)
            .preferredColorScheme(.light)
        }
    }
}
