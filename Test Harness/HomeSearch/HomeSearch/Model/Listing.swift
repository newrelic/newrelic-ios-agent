//
//  Listing.swift
//  HomeSearch
//
//  Domain models. Decoded from the JSON the local stub server serves — see ListingStubServer.
//

import Foundation

struct Listing: Identifiable, Hashable, Codable {
    let id: String
    let address: String
    let city: String
    let state: String
    let zip: String
    let price: Int
    let beds: Int
    let baths: Double
    let sqft: Int
    let yearBuilt: Int
    let propertyType: PropertyType
    let status: Status
    let daysOnMarket: Int
    let summary: String
    let agent: Agent
    let photoCount: Int
    /// Drives the procedural photo colour so imagery is deterministic across runs.
    let hue: Double

    enum PropertyType: String, Codable, CaseIterable, Hashable {
        case house = "House"
        case condo = "Condo"
        case townhouse = "Townhouse"
    }

    enum Status: String, Codable, Hashable {
        case forSale = "For Sale"
        case newListing = "New"
        case pending = "Pending"
    }

    var shortAddress: String { address }
    var cityStateZip: String { "\(city), \(state) \(zip)" }

    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: price as NSNumber) ?? "$\(price)"
    }

    var pricePerSqft: Int { sqft > 0 ? price / sqft : 0 }

    var formattedBaths: String {
        baths == baths.rounded() ? String(Int(baths)) : String(format: "%.1f", baths)
    }

    /// Attributes attached to the Listing Detail MobileView event. This is where per-listing
    /// identity lives — deliberately *not* in the view name, to keep view-name cardinality bounded.
    var mobileViewAttributes: [String: Any] {
        [
            "listingId": id,
            "listingCity": city,
            "listingState": state,
            "listingPrice": price,
            "listingBeds": beds,
            "listingPropertyType": propertyType.rawValue,
            "listingStatus": status.rawValue,
            "listingDaysOnMarket": daysOnMarket
        ]
    }
}

struct Agent: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let brokerage: String
    let phone: String

    var initials: String {
        name.split(separator: " ").compactMap(\.first).map(String.init).joined()
    }
}

struct MessageThread: Identifiable, Hashable, Codable {
    let id: String
    let correspondent: String
    let brokerage: String
    let preview: String
    let unread: Bool
    let messages: [Message]

    struct Message: Identifiable, Hashable, Codable {
        let id: String
        let body: String
        let fromAgent: Bool
        let sentAgo: String
    }
}

/// The payload the stub server returns from `/api/listings`.
struct ListingsResponse: Codable {
    let listings: [Listing]
    let threads: [MessageThread]
}

/// The payload the stub server returns from `/api/listings/page` — one page of the browse feed.
///
/// `hasMore` is what the infinite list keys off: it stops asking for pages when the server says
/// there are none left, so the "scrolled to the true end" case is reachable rather than endless.
struct BrowsePage: Codable {
    let listings: [Listing]
    let page: Int
    let pageSize: Int
    let hasMore: Bool
    let totalPages: Int
}
