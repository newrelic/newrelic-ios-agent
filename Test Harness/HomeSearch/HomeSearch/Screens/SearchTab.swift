//
//  SearchTab.swift
//  HomeSearch
//
//  The search results list, and the navigation stack rooted at it.
//
//  Three MobileViews entry points meet here:
//
//    * `.NRMobileView(startsInteraction: true)` on the results list. The interaction trace gives the
//      screen code-level tracing to correlate against, which a SwiftUI view has no UIViewController
//      to get automatically. Only one trace can be open at a time, so this is on two screens in the
//      whole app rather than all of them.
//
//    * `.NRMobileDestination(for: SearchRoute.self)` — one declaration covering both pushed screens,
//      naming each from the route.
//
//    * `.NRMobileSheet(isPresented:)` for filters.
//

import SwiftUI
import NewRelic

struct SearchTab: View {

    @Environment(ListingStore.self) private var store
    @Environment(SavedHomesStore.self) private var savedHomes

    @State private var path: [SearchRoute] = []
    @State private var showingFilters = false

    var body: some View {
        NavigationStack(path: $path) {
            resultsList
                .navigationTitle("Seattle, WA")
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: Binding(
                    get: { store.query },
                    set: { store.query = $0 }
                ), prompt: "Address, neighborhood, or ZIP")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        sortMenu
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        filterButton
                    }
                }
                // Search is one of the two screens that opens an interaction trace.
                .NRMobileView(name: ViewName.search.rawValue)
                // Filters is a sheet, so it reports as its own view with Search as its referrer.
                .NRMobileSheet(isPresented: $showingFilters, name: ViewName.filters.rawValue) {
                    FilterSheetScreen()
                }
                // One destination declaration for the whole stack; the route supplies the name.
                .NRMobileDestination(for: SearchRoute.self, name: { $0.viewName }) { route in
                    switch route {
                    case .listing(let id):
                        ListingDetailScreen(listingID: id) { listingID in
                            path.append(.tourConfirmation(listingID))
                        }
                    case .tourConfirmation(let id):
                        TourConfirmationScreen(listingID: id) {
                            path.removeAll()
                        }
                    }
                }
        }
    }

    // MARK: - Results

    @ViewBuilder
    private var resultsList: some View {
        switch store.state {
        case .idle, .loading:
            ProgressView("Finding homes…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn't load listings", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") { Task { await store.load() } }
                    .buttonStyle(.borderedProminent)
            }

        case .loaded:
            if store.results.isEmpty {
                ContentUnavailableView.search
            } else {
                List {
                    Section {
                        ForEach(store.results) { listing in
                            Button {
                                path.append(.listing(listing.id))
                            } label: {
                                ListingCard(listing: listing)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text("\(store.results.count) of \(store.listings.count) homes")
                            .font(.footnote)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Toolbar

    private var sortMenu: some View {
        Menu {
            Picker("Sort", selection: Binding(
                get: { store.sortOrder },
                set: { store.sortOrder = $0 }
            )) {
                ForEach(SortOrder.allCases) { order in
                    Text(order.rawValue).tag(order)
                }
            }
        } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down")
        }
    }

    private var filterButton: some View {
        Button {
            showingFilters = true
        } label: {
            Label("Filters", systemImage: store.filters.isDefault
                  ? "line.3.horizontal.decrease.circle"
                  : "line.3.horizontal.decrease.circle.fill")
        }
        .overlay(alignment: .topTrailing) {
            if store.filters.activeCount > 0 {
                Text("\(store.filters.activeCount)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(4)
                    .background(Circle().fill(.red))
                    .offset(x: 8, y: -8)
            }
        }
    }
}
