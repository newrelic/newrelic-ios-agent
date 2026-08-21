//
//  HomeSearchApp.swift
//  HomeSearch
//
//  A property-search app, built to exercise the New Relic iOS agent's MobileViews feature from a
//  realistic SwiftUI navigation graph rather than a grid of demo screens.
//
//  Every public MobileViews entry point is used somewhere in this app by a surface that would exist
//  anyway:
//
//    .NRMobileTabTracking      → the tab bar                       (RootTabView)
//    .NRMobileView             → each tab root                     (RootTabView)
//    .NRMobileDestination      → listing detail, message threads    (SearchTab, InboxTab)
//    NRMobileNavigationLink    → profile settings rows              (ProfileTab)
//    .NRMobileSheet(isPresented:) → the filter sheet                (SearchTab)
//    .NRMobileSheet(item:)     → contact agent                      (ListingDetailScreen)
//    .NRMobileFullScreenCover  → the photo gallery                  (ListingDetailScreen)
//    .NRMobilePopover          → the mortgage calculator            (ListingDetailScreen)
//    ignored: true             → Debug Info, which must never report (DebugInfoScreen)
//    startsInteraction: true   → Search and Listing Detail
//    NewRelic.setCurrentView   → the Saved tab's two modes          (SavedTab)
//
//  See ViewName for the complete inventory of names this app can emit.
//

import SwiftUI

@main
struct HomeSearchApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @State private var store = ListingStore()
    @State private var savedHomes = SavedHomesStore()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(store)
                .environment(savedHomes)
                .task { await store.loadIfNeeded() }
        }
    }
}
