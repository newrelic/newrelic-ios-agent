//
//  ListingPhoto.swift
//  HomeSearch
//
//  Loads a listing photo from the local stub server.
//
//  This is deliberately `AsyncImage` over HTTP rather than a locally drawn SwiftUI shape. AsyncImage
//  goes through URLSession, which the agent instruments, so every photo produces a MobileRequest
//  event — and that is what makes it possible to check which view a request gets attributed to. The
//  placeholder uses the listing's own hue so there is no flash of grey while a photo loads.
//

import SwiftUI

struct ListingPhoto: View {

    let listing: Listing
    let index: Int

    var body: some View {
        AsyncImage(url: ListingStore.photoURL(listingID: listing.id, index: index)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)

            case .failure:
                placeholder
                    .overlay {
                        Image(systemName: "photo.badge.exclamationmark")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.8))
                    }

            case .empty:
                placeholder

            @unknown default:
                placeholder
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var placeholder: some View {
        LinearGradient(
            colors: [
                Color(hue: listing.hue, saturation: 0.30, brightness: 0.92),
                Color(hue: listing.hue, saturation: 0.55, brightness: 0.62)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
