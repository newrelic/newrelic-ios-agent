//
//  SavedTab.swift
//  HomeSearch
//
//  Saved homes, in two modes — Favorites and Recently Viewed — and the only place in this app that
//  calls the manual view API.
//
//  Why manual here. Both modes are rendered by this one SwiftUI view. Switching between them changes
//  what the user is looking at completely, but nothing appears or disappears from the agent's point
//  of view, so automatic instrumentation cannot see it: it would report a single "Saved Homes" view
//  that stays current across both. Declaring each mode with `NewRelic.setCurrentView(_:attributes:)`
//  is the fix, and it is the same situation a React Native bridge is in — one host view controller,
//  many logical screens.
//
//  Each call closes the previous manual view (emitting its timeVisible) and opens the new one with
//  the previous as `previousView`, so toggling back and forth should produce an alternating referrer
//  chain between the two mode names.
//
//  Note there is no `.NRMobileView` on the mode content itself — that would double-report. The tab
//  root keeps its own `.NRMobileView` for the tab-level view, and modes are manual on top of it.
//

import SwiftUI
import NewRelic

struct SavedTab: View {

    @Environment(ListingStore.self) private var store
    @Environment(SavedHomesStore.self) private var savedHomes

    @State private var path: [SavedRoute] = []
    @State private var mode: SavedMode = .favorites

    private var listings: [Listing] {
        switch mode {
        case .favorites:
            // Preserve results order rather than set order, so the list is stable between visits.
            return store.listings.filter { savedHomes.isSaved($0.id) }
        case .recentlyViewed:
            return store.listings(ids: savedHomes.recentlyViewedIDs)
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                Picker("Mode", selection: $mode) {
                    ForEach(SavedMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)

                content
            }
            .navigationTitle("Saved")
            .NRMobileView(name: ViewName.saved.rawValue)
            .NRMobileDestination(for: SavedRoute.self, name: { $0.viewName }) { route in
                switch route {
                case .listing(let id):
                    // Reached from Saved rather than Search, so this exercises the `restarted`
                    // attribute: the same Listing Detail view appearing again later in the session.
                    ListingDetailScreen(listingID: id) { _ in path.removeAll() }
                }
            }
            // Declare the initial mode, and re-declare on every change. `.task(id:)` covers both:
            // it runs once on appear and again each time `mode` changes.
            .task(id: mode) {
                declareCurrentView()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if listings.isEmpty {
            ContentUnavailableView {
                Label(emptyTitle, systemImage: mode == .favorites ? "heart" : "clock.arrow.circlepath")
            } description: {
                Text(emptyMessage)
            }
        } else {
            List {
                ForEach(listings) { listing in
                    Button {
                        path.append(.listing(listing.id))
                    } label: {
                        ListingCard(listing: listing)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
        }
    }

    private var emptyTitle: String {
        mode == .favorites ? "No saved homes" : "Nothing viewed yet"
    }

    private var emptyMessage: String {
        mode == .favorites
            ? "Tap the heart on a listing to keep it here."
            : "Homes you open will show up here."
    }

    /// The manual view declaration. Attributes ride along on the MobileView event so the mode is
    /// queryable without having to parse it back out of the view name.
    private func declareCurrentView() {
        NewRelic.setCurrentView(mode.viewName, attributes: [
            "savedMode": mode.rawValue,
            "savedCount": savedHomes.savedIDs.count,
            "recentlyViewedCount": savedHomes.recentlyViewedIDs.count,
            "resultCount": listings.count
        ])
    }
}
