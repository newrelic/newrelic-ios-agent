//
//  TourConfirmationScreen.swift
//  HomeSearch
//
//  End of the funnel, pushed onto the Search stack after the contact sheet is submitted.
//
//  The interesting sequence: the contact sheet dismisses at the same moment this screen is pushed,
//  so the agent sees Contact Agent disappear and Tour Requested appear at nearly the same instant.
//  Which of them ends up as this view's `previousView` is exactly the kind of ordering question this
//  app exists to answer.
//

import SwiftUI

struct TourConfirmationScreen: View {

    let listingID: Listing.ID
    /// Clears the navigation stack, returning to search results.
    let onDone: () -> Void

    @Environment(ListingStore.self) private var store

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
                .padding(.top, 48)

            Text("Tour requested")
                .font(.title2.bold())

            if let listing = store.listing(listingID) {
                VStack(spacing: 6) {
                    Text(listing.shortAddress).font(.headline)
                    Text(listing.cityStateZip).foregroundStyle(.secondary)
                    Text("\(listing.agent.name) will confirm by text.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                }
                .multilineTextAlignment(.center)
            }

            Spacer()

            Button {
                onDone()
            } label: {
                Text("Back to search").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .padding(.horizontal)
        .navigationTitle("Confirmed")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
    }
}
