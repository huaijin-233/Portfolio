import SwiftUI

@main
struct ShengliWordsApp: App {
    @StateObject private var wordStore = WordStore()

    var body: some Scene {
        WindowGroup {
            AppLaunchView()
                .environmentObject(wordStore)
                .preferredColorScheme(.light)
        }
    }
}
