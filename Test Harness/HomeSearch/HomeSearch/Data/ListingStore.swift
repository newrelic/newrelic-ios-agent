//
//  ListingStore.swift
//  HomeSearch
//
//  Fetches listings and threads from the local stub server over HTTP, and holds search state.
//
//  The fetch is deliberately a real URLSession call (see ListingStubServer for why) and carries an
//  artificial delay so `loadTime` on the Search view is a number with some spread in it rather than
//  a constant near zero.
//

import Foundation
import Observation

@Observable
final class ListingStore {

    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    private(set) var state: LoadState = .idle
    private(set) var listings: [Listing] = []
    private(set) var threads: [MessageThread] = []

    var filters = Filters()
    var sortOrder: SortOrder = .newest
    var query: String = ""

    /// Simulated server think-time, so load timings vary in a realistic way.
    private let artificialDelay: Duration = .milliseconds(220)

    // MARK: - Derived

    var results: [Listing] {
        let filtered = listings.filter { listing in
            guard filters.matches(listing) else { return false }
            guard !query.isEmpty else { return true }
            let haystack = "\(listing.address) \(listing.city) \(listing.zip)".lowercased()
            return haystack.contains(query.lowercased())
        }
        return sortOrder.sort(filtered)
    }

    func listing(_ id: Listing.ID) -> Listing? {
        listings.first { $0.id == id }
    }

    func thread(_ id: MessageThread.ID) -> MessageThread? {
        threads.first { $0.id == id }
    }

    func listings(ids: [Listing.ID]) -> [Listing] {
        ids.compactMap { id in listings.first { $0.id == id } }
    }

    var unreadThreadCount: Int { threads.filter(\.unread).count }

    // MARK: - Loading

    func loadIfNeeded() async {
        guard state == .idle || isFailed else { return }
        await load()
    }

    private var isFailed: Bool {
        if case .failed = state { return true }
        return false
    }

    func load() async {
        state = .loading

        do {
            try? await Task.sleep(for: artificialDelay)

            guard let url = URL(string: "\(ListingStubServer.baseURL)/api/listings") else {
                state = .failed("Bad stub server URL")
                return
            }

            let (data, response) = try await URLSession.shared.data(from: url)

            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                state = .failed("Stub server returned HTTP \(http.statusCode)")
                return
            }

            let decoded = try JSONDecoder().decode(ListingsResponse.self, from: data)
            listings = decoded.listings
            threads = decoded.threads
            state = .loaded
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Fetches a single listing so the detail screen issues its own request. The result is discarded
    /// — the point is the MobileRequest event and which view it gets attributed to.
    func refreshDetail(_ id: Listing.ID) async {
        guard let url = URL(string: "\(ListingStubServer.baseURL)/api/listings/\(id)") else { return }
        _ = try? await URLSession.shared.data(from: url)
    }

    // MARK: - Photo URLs

    static func photoURL(listingID: Listing.ID, index: Int) -> URL? {
        URL(string: "\(ListingStubServer.baseURL)/photo/\(listingID)/\(index).png")
    }
}
