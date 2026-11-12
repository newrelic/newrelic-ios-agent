//
//  ListingCard.swift
//  HomeSearch
//
//  The row used by both Search results and the Saved tab.
//

import SwiftUI

struct ListingCard: View {

    let listing: Listing

    @Environment(SavedHomesStore.self) private var savedHomes

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                ListingPhoto(listing: listing, index: 0)
                    .frame(height: 180)
                    .clipped()

                StatusBadge(status: listing.status)
                    .padding(10)
            }
            .overlay(alignment: .topTrailing) {
                if savedHomes.isSaved(listing.id) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                        .padding(12)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(listing.formattedPrice)
                    .font(.title3.bold())

                HStack(spacing: 10) {
                    Text("\(listing.beds) bd")
                    Text("\(listing.formattedBaths) ba")
                    Text("\(listing.sqft.formatted()) sqft")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Text(listing.shortAddress)
                    .font(.subheadline)
                Text(listing.cityStateZip)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 10)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(Rectangle())
    }
}

struct StatusBadge: View {

    let status: Listing.Status

    var body: some View {
        Text(status.rawValue.uppercased())
            .font(.system(size: 10, weight: .heavy))
            .tracking(0.6)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(background, in: Capsule())
    }

    private var background: Color {
        switch status {
        case .newListing: return .green
        case .forSale:    return .blue
        case .pending:    return .orange
        }
    }
}
