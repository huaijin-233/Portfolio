#if os(macOS)
//
//  InkApp.swift
//  Ink
//
//  Created by Huaijin233 on 3/13/26.
//

import SwiftUI

@main
struct InkApp: App {
    @StateObject private var store = JournalStore()
    @StateObject private var localization = InkLocalization()
    @StateObject private var themeController = WriteThemeController()

    var body: some Scene {
        WindowGroup(localization.libraryWindowTitle, id: "library") {
            ContentView()
                .environmentObject(store)
                .environmentObject(localization)
                .environmentObject(themeController)
                .environment(\.locale, localization.locale)
                .preferredColorScheme(.light)
        }
        .defaultSize(width: 1080, height: 720)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .newItem) {
                Button(localization.newJournal) {
                    store.createEntry()
                }
                .keyboardShortcut("n")
            }
        }

        DocumentGroup(newDocument: InkJournalDocument()) { file in
            InkJournalDocumentView(document: file.$document, fileURL: file.fileURL)
                .environmentObject(localization)
                .environmentObject(themeController)
                .environment(\.locale, localization.locale)
                .preferredColorScheme(.light)
        }
        .defaultSize(width: 960, height: 720)
        .windowResizability(.contentMinSize)
    }
}
#endif
