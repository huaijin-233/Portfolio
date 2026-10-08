import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                ScanView()
            }
            .tabItem {
                Label("扫描", systemImage: "camera.viewfinder")
            }

            NavigationStack {
                StudyView()
            }
            .tabItem {
                Label("背单词", systemImage: "text.book.closed")
            }

            NavigationStack {
                WordSheetBooksView()
            }
            .tabItem {
                Label("做表格", systemImage: "tablecells")
            }

            NavigationStack {
                VocabularyView()
            }
            .tabItem {
                Label("书架", systemImage: "books.vertical")
            }
        }
        .tint(AppColors.primary)
        .toolbarBackground(AppColors.background.opacity(0.98), for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}

#Preview {
    RootTabView()
        .environmentObject(WordStore())
}
