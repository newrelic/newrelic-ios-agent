//
//  RootTabView.swift
//  HomeSearch
//
//  The tab bar, and the one place tab changes are reported from.
//
//  `.NRMobileTabTracking(selection:name:)` watches the selection binding and emits a MobileView for
//  the newly selected tab after a short dwell, so flicking through tabs to reach the fourth one does
//  not report the two you passed through. Each tab root additionally carries its own
//  `.NRMobileView`, which is what reports on first appearance and on return from a pushed screen.
//

import SwiftUI
import NewRelic

struct RootTabView: View {

    @State private var selectedTab: AppTab = .search
    @Environment(ListingStore.self) private var store

    var body: some View {
        TabView(selection: $selectedTab) {
            SearchTab()
                .tabItem { Label(AppTab.search.title, systemImage: AppTab.search.symbol) }
                .tag(AppTab.search)

            SavedTab()
                .tabItem { Label(AppTab.saved.title, systemImage: AppTab.saved.symbol) }
                .tag(AppTab.saved)

            InboxTab()
                .tabItem { Label(AppTab.inbox.title, systemImage: AppTab.inbox.symbol) }
                .tag(AppTab.inbox)
                .badge(store.unreadThreadCount)

            ProfileTab()
                .tabItem { Label(AppTab.profile.title, systemImage: AppTab.profile.symbol) }
                .tag(AppTab.profile)
        }
        // Names come from the AppTab enum, which reads them from ViewName — no literals here.
        .NRMobileTabTracking(selection: $selectedTab) { tab in tab.viewName }
    }
}
