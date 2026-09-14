//
//  ViewName.swift
//  HomeSearch
//
//  The single source of truth for every view name this app reports to New Relic.
//
//  Why this file exists: HomeSearch is a validation vehicle for the MobileViews feature, so the
//  set of names it can possibly emit needs to be reviewable in one place. Every
//  `.NRMobileView(name:)`, `.NRMobileDestination(name:)`, `.NRMobileSheet(name:)` and
//  `NewRelic.setCurrentView(_:)` call site in the app reads its name from here — nothing passes a
//  string literal. That means:
//
//    * the complete expected view inventory is `ViewName.allCases`,
//    * NRQL expectations can be written straight off this list,
//    * a typo can't silently create a phantom view name.
//
//  Cardinality note: names here are deliberately stable and low-cardinality. Per-listing detail
//  screens all report "Listing Detail" and carry the address as a custom *attribute* rather than
//  baking it into the name — that is the practice we want to recommend to customers, since view
//  name is a facet and unbounded names make it useless. `ViewName.messageThread(with:)` is the one
//  deliberate exception, kept so the dynamic-name path of `.NRMobileDestination` is exercised too.
//

import Foundation

enum ViewName: String, CaseIterable {

    // MARK: Tab roots

    case search  = "Search"
    case saved   = "Saved Homes"
    case inbox   = "Inbox"
    case profile = "Profile"

    // MARK: Saved-tab modes
    //
    // The Saved tab has two modes rendered by one SwiftUI view. Automatic instrumentation cannot
    // see the difference — to the agent it is a single view that never disappears — so the mode
    // switch is declared with `NewRelic.setCurrentView(_:)`. This is the manual-views entry point.

    case savedFavorites      = "Saved / Favorites"
    case savedRecentlyViewed = "Saved / Recently Viewed"

    // MARK: Pushed destinations

    case listingDetail        = "Listing Detail"
    case tourConfirmation     = "Tour Requested"
    case notificationSettings = "Notification Settings"
    case searchPreferences    = "Search Preferences"

    /// Reports `ignored: true`, so it must never appear in the data. Present precisely so we can
    /// assert its absence.
    case debugInfo = "Debug Info"

    // MARK: Modal presentations

    case filters            = "Filters"
    case contactAgent       = "Contact Agent"
    case photoGallery       = "Photo Gallery"
    case mortgageCalculator = "Mortgage Calculator"

    // MARK: Dynamic names

    /// Message threads name themselves after the correspondent, exercising the dynamic-name closure
    /// of `.NRMobileDestination(for:name:)`. Cardinality is bounded by the thread fixture.
    static func messageThread(with correspondent: String) -> String {
        "Message Thread — \(correspondent)"
    }

    /// Every dynamic name this app can emit, for tests that need the full expected inventory
    /// rather than just the static cases.
    static func allExpectedNames(threadCorrespondents: [String]) -> [String] {
        allCases.map(\.rawValue) + threadCorrespondents.map { messageThread(with: $0) }
    }
}
