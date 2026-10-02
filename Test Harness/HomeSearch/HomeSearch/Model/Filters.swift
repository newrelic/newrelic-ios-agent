//
//  Filters.swift
//  HomeSearch
//
//  Search filter state, applied client-side to whatever the stub server returned.
//

import Foundation

struct Filters: Equatable {
    var minPrice: Int = 0
    var maxPrice: Int = 3_000_000
    var minBeds: Int = 0
    var minBaths: Int = 0
    var propertyTypes: Set<Listing.PropertyType> = Set(Listing.PropertyType.allCases)
    var newListingsOnly: Bool = false

    static let priceCeiling = 3_000_000

    func matches(_ listing: Listing) -> Bool {
        guard listing.price >= minPrice, listing.price <= maxPrice else { return false }
        guard listing.beds >= minBeds else { return false }
        guard Int(listing.baths.rounded(.down)) >= minBaths else { return false }
        guard propertyTypes.contains(listing.propertyType) else { return false }
        if newListingsOnly && listing.status != .newListing { return false }
        return true
    }

    /// How many filters differ from the default — drives the badge on the Filters button and is
    /// reported as an attribute on the filter breadcrumb.
    var activeCount: Int {
        var count = 0
        if minPrice != 0 { count += 1 }
        if maxPrice != Filters.priceCeiling { count += 1 }
        if minBeds != 0 { count += 1 }
        if minBaths != 0 { count += 1 }
        if propertyTypes != Set(Listing.PropertyType.allCases) { count += 1 }
        if newListingsOnly { count += 1 }
        return count
    }

    var isDefault: Bool { activeCount == 0 }

    var breadcrumbAttributes: [String: Any] {
        [
            "filterCount": activeCount,
            "minPrice": minPrice,
            "maxPrice": maxPrice,
            "minBeds": minBeds,
            "minBaths": minBaths,
            "propertyTypes": propertyTypes.map(\.rawValue).sorted().joined(separator: ","),
            "newListingsOnly": newListingsOnly
        ]
    }
}

enum SortOrder: String, CaseIterable, Identifiable {
    case newest = "Newest"
    case priceLowHigh = "Price ↑"
    case priceHighLow = "Price ↓"
    case sqft = "Sq Ft"

    var id: String { rawValue }

    func sort(_ listings: [Listing]) -> [Listing] {
        switch self {
        case .newest:       return listings.sorted { $0.daysOnMarket < $1.daysOnMarket }
        case .priceLowHigh: return listings.sorted { $0.price < $1.price }
        case .priceHighLow: return listings.sorted { $0.price > $1.price }
        case .sqft:         return listings.sorted { $0.sqft > $1.sqft }
        }
    }
}
