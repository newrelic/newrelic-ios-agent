//
//  Route.swift
//  HomeSearch
//
//  Value-based navigation routes, one enum per tab.
//
//  Each tab owns a `NavigationStack(path:)` over its own route type, and each route type gets a
//  single `.NRMobileDestination(for:name:)` declaration. That keeps the mapping from "route" to
//  "view name" in exactly two places — this file for the shape, ViewName for the strings.
//

import Foundation

enum SearchRoute: Hashable {
    case listing(Listing.ID)
    case tourConfirmation(Listing.ID)

    var viewName: String {
        switch self {
        case .listing:          return ViewName.listingDetail.rawValue
        case .tourConfirmation: return ViewName.tourConfirmation.rawValue
        }
    }
}

enum SavedRoute: Hashable {
    case listing(Listing.ID)

    var viewName: String {
        switch self {
        case .listing: return ViewName.listingDetail.rawValue
        }
    }
}

enum InboxRoute: Hashable {
    case thread(MessageThread.ID)
}

enum ProfileRoute: Hashable {
    case notificationSettings
    case searchPreferences
    case debugInfo

    var viewName: String {
        switch self {
        case .notificationSettings: return ViewName.notificationSettings.rawValue
        case .searchPreferences:    return ViewName.searchPreferences.rawValue
        case .debugInfo:            return ViewName.debugInfo.rawValue
        }
    }

    /// `Debug Info` opts out of view tracking entirely via `.NRMobileView(ignored: true)`.
    var isIgnored: Bool { self == .debugInfo }
}

/// Tabs are a `Hashable` selection type so `.NRMobileTabTracking(selection:name:)` can name them.
///
/// Named `AppTab` rather than `Tab` on purpose: SwiftUI ships its own `Tab<Value, Content, Label>`
/// type on iOS 18+, and a local `Tab` shadows it in confusing ways.
enum AppTab: String, Hashable, CaseIterable {
    case search, saved, inbox, profile

    var viewName: String {
        switch self {
        case .search:  return ViewName.search.rawValue
        case .saved:   return ViewName.saved.rawValue
        case .inbox:   return ViewName.inbox.rawValue
        case .profile: return ViewName.profile.rawValue
        }
    }

    var title: String {
        switch self {
        case .search:  return "Search"
        case .saved:   return "Saved"
        case .inbox:   return "Inbox"
        case .profile: return "Profile"
        }
    }

    var symbol: String {
        switch self {
        case .search:  return "magnifyingglass"
        case .saved:   return "heart"
        case .inbox:   return "envelope"
        case .profile: return "person.crop.circle"
        }
    }
}
