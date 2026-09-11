//
//  SavedHomesStore.swift
//  HomeSearch
//
//  Saved homes and recently-viewed history. In memory only — there is no persistence layer here on
//  purpose, since nothing about the MobileViews feature depends on it.
//

import Foundation
import Observation

@Observable
final class SavedHomesStore {

    private(set) var savedIDs: Set<Listing.ID> = []

    /// Most-recently-viewed first, de-duplicated, capped so the list stays readable.
    private(set) var recentlyViewedIDs: [Listing.ID] = []

    private let recentlyViewedLimit = 10

    func isSaved(_ id: Listing.ID) -> Bool { savedIDs.contains(id) }

    /// Returns the new saved state so callers can report it on a breadcrumb.
    @discardableResult
    func toggleSaved(_ id: Listing.ID) -> Bool {
        if savedIDs.contains(id) {
            savedIDs.remove(id)
            return false
        }
        savedIDs.insert(id)
        return true
    }

    func markViewed(_ id: Listing.ID) {
        recentlyViewedIDs.removeAll { $0 == id }
        recentlyViewedIDs.insert(id, at: 0)
        if recentlyViewedIDs.count > recentlyViewedLimit {
            recentlyViewedIDs.removeLast(recentlyViewedIDs.count - recentlyViewedLimit)
        }
    }
}

/// The two modes the Saved tab can be in. One SwiftUI view renders both, which is exactly why the
/// mode change has to be declared manually with `NewRelic.setCurrentView(_:)` — see SavedScreen.
enum SavedMode: String, CaseIterable, Identifiable {
    case favorites = "Favorites"
    case recentlyViewed = "Recently Viewed"

    var id: String { rawValue }

    var viewName: String {
        switch self {
        case .favorites:      return ViewName.savedFavorites.rawValue
        case .recentlyViewed: return ViewName.savedRecentlyViewed.rawValue
        }
    }
}
