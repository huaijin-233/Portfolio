//
//  ContentView.swift
//  Done
//
//  Created by Huaijin233 on 3/11/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var localization: LocalizationStore
    @EnvironmentObject private var themeStore: ThemeStore
    @StateObject private var groupStore: GroupStore
    @StateObject private var store: TaskStore

    init() {
        let cloudKit = CloudKitService()
        let groupStore = GroupStore(cloudKit: cloudKit)
        _groupStore = StateObject(wrappedValue: groupStore)
        _store = StateObject(wrappedValue: TaskStore(cloudKit: cloudKit, groupStore: groupStore))
    }

    var body: some View {
        TabView {
            NavigationStack {
                AssignView(store: store, groupStore: groupStore)
            }
            .environmentObject(localization)
            .environmentObject(themeStore)
            .tabItem {
                Label(localization.text(.assignTab), systemImage: "square.and.pencil")
            }

            NavigationStack {
                TodoView(store: store)
            }
            .environmentObject(localization)
            .environmentObject(themeStore)
            .tabItem {
                Label(localization.text(.todoTab), systemImage: "checklist")
            }

            NavigationStack {
                CalendarView(store: store)
            }
            .environmentObject(localization)
            .environmentObject(themeStore)
            .tabItem {
                Label(localization.text(.calendarTab), systemImage: "calendar")
            }

            NavigationStack {
                GroupsView(groupStore: groupStore)
            }
            .environmentObject(localization)
            .environmentObject(themeStore)
            .tabItem {
                Label(localization.text(.groupTab), systemImage: "person.3.sequence.fill")
            }
        }
        .tint(themeStore.theme.palette.accent)
        .environment(\.locale, localization.locale)
        .toolbarBackground(themeStore.theme.palette.surface.opacity(0.96), for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .onAppear {
            store.updateLanguage(localization.language)
        }
        .onChange(of: localization.language) { _, newLanguage in
            store.updateLanguage(newLanguage)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await groupStore.refreshIfNeeded(maxAge: 0)
                await store.refreshGroupTasksNow()
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(LocalizationStore())
        .environmentObject(ThemeStore())
}
