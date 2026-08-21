//
//  PhotoGalleryScreen.swift
//  HomeSearch
//
//  Full-screen photo browser, presented by `.NRMobileFullScreenCover` in ListingDetailScreen.
//
//  Worth watching here: paging through photos loads each image over HTTP from the stub server, so a
//  single visit to this view produces a burst of MobileRequest events that should all be attributed
//  to Photo Gallery rather than to Listing Detail.
//

import SwiftUI

struct PhotoGalleryScreen: View {

    let listing: Listing

    @Environment(\.dismiss) private var dismiss
    @State private var selection = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $selection) {
                ForEach(0..<listing.photoCount, id: \.self) { index in
                    ListingPhoto(listing: listing, index: index)
                        .scaledToFit()
                        .tag(index)
                }
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.white)
                    }
                    .accessibilityLabel("Close gallery")
                    .padding()
                }
                Spacer()

                Text("\(selection + 1) of \(listing.photoCount) · \(listing.shortAddress)")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.bottom, 44)
            }
        }
    }
}
