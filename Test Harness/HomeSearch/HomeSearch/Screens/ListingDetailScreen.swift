//
//  ListingDetailScreen.swift
//  HomeSearch
//
//  A single property. The busiest screen in the app for MobileViews purposes, because it presents
//  all three kinds of modal:
//
//    .NRMobileSheet(item:)     → Contact Agent, driven by an Identifiable item rather than a Bool
//    .NRMobileFullScreenCover  → Photo Gallery
//    .NRMobilePopover          → Mortgage Calculator
//
//  Each reports as its own view with "Listing Detail" as its referrer, which is the property worth
//  checking: a modal is a view in its own right, and dismissing it should make Listing Detail
//  current again.
//
//  Note what is NOT in the view name. Every listing reports as "Listing Detail"; the address, price
//  and id ride along as attributes (see `Listing.mobileViewAttributes`). Baking the address into the
//  name would give a distinct view name per property, which makes view name useless as a facet.
//

import SwiftUI
import NewRelic

struct ListingDetailScreen: View {

    let listingID: Listing.ID
    /// Called when the tour request is submitted, so the parent stack can push the confirmation.
    let onTourRequested: (Listing.ID) -> Void

    @Environment(ListingStore.self) private var store
    @Environment(SavedHomesStore.self) private var savedHomes

    @State private var contactTarget: Listing?
    @State private var showingGallery = false
    @State private var showingMortgageCalculator = false

    var body: some View {
        Group {
            if let listing = store.listing(listingID) {
                content(for: listing)
            } else {
                ContentUnavailableView(
                    "Listing unavailable",
                    systemImage: "house.slash",
                    description: Text("Listing \(listingID) is no longer in the results.")
                )
            }
        }
    }

    @ViewBuilder
    private func content(for listing: Listing) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heroPhoto(for: listing).NRMobileView(name: Component.heroPhoto.rawValue,
                                                     attributes: Component.attributes)
                header(for: listing).NRMobileView(name: Component.header.rawValue,
                                                  attributes: Component.attributes)
                Divider()
                facts(for: listing).NRMobileView(name: Component.facts.rawValue,
                                                 attributes: Component.attributes)
                Divider()
                summary(for: listing).NRMobileView(name: Component.summary.rawValue,
                                                   attributes: Component.attributes)
                Divider()
                agentCard(for: listing).NRMobileView(name: Component.agentCard.rawValue,
                                                     attributes: Component.attributes)
            }
            .padding(.bottom, 32)
        }
        .navigationTitle(listing.shortAddress)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                saveButton(for: listing)
            }
        }
        .task {
            // Record the visit locally, and issue a detail request so there is a MobileRequest event
            // attributed to this screen rather than to Search.
            savedHomes.markViewed(listing.id)
            await store.refreshDetail(listing.id)
        }
        // The second of the two screens that open an interaction trace, and the one where custom
        // attributes are attached to the MobileView event.
        .NRMobileView(
            name: ViewName.listingDetail.rawValue,
            attributes: listing.mobileViewAttributes
        )
        // Item-driven sheet: the name closure receives the item, so it could vary per agent. It
        // deliberately does not — see the cardinality note in ViewName.
        .NRMobileSheet(item: $contactTarget, name: { _ in ViewName.contactAgent.rawValue }) { target in
            ContactAgentScreen(listing: target) {
                contactTarget = nil
                onTourRequested(target.id)
            }
        }
        .NRMobileFullScreenCover(isPresented: $showingGallery,
                                 name: ViewName.photoGallery.rawValue) {
            PhotoGalleryScreen(listing: listing)
        }
        .NRMobilePopover(isPresented: $showingMortgageCalculator,
                         name: ViewName.mortgageCalculator.rawValue) {
            MortgageCalculatorScreen(listing: listing)
        }
    }

    // MARK: - Component-level views

    /// The sections of this screen, each tracked as a view in its own right.
    ///
    /// These take the default `startsInteraction: false`, so they open no trace of their own — each
    /// records a load segment against whatever interaction is already open, which on this screen is
    /// the one the screen itself opens with `startsInteraction: true`. That is what puts several
    /// `Method/MobileView/<component>` rows into a *single* interaction's breakdown table, instead
    /// of the one row naming the screen.
    ///
    /// Names are dot-separated rather than slash-separated on purpose: `/` is one of the characters
    /// `+[NewRelicInternalUtils cleanseStringForCollector:]` rewrites to `_`, and it is also the
    /// separator in the `Method/<class>/<method>` metric grammar these names land in.
    ///
    /// The names are fixed strings, never per-listing — see the cardinality note in ViewName.
    private enum Component: String {
        case heroPhoto = "ListingDetail.HeroPhoto"
        case header    = "ListingDetail.Header"
        case facts     = "ListingDetail.Facts"
        case summary   = "ListingDetail.Summary"
        case agentCard = "ListingDetail.AgentCard"

        /// Marks the emitted MobileView events as components rather than screens. `viewName` alone
        /// cannot tell them apart — to the agent a component is just another view — so dashboards
        /// need an attribute to facet on.
        static let attributes: [String: Any] = [
            "component": true,
            "componentOf": ViewName.listingDetail.rawValue
        ]
    }

    // MARK: - Sections

    private func heroPhoto(for listing: Listing) -> some View {
        Button {
            showingGallery = true
        } label: {
            ZStack(alignment: .bottomTrailing) {
                ListingPhoto(listing: listing, index: 0)
                    .frame(height: 260)
                    .clipped()

                Label("\(listing.photoCount) photos", systemImage: "photo.on.rectangle")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.55), in: Capsule())
                    .foregroundStyle(.white)
                    .padding(12)
            }
        }
        .buttonStyle(.plain)
    }

    private func header(for listing: Listing) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(listing.formattedPrice)
                    .font(.largeTitle.bold())
                StatusBadge(status: listing.status)
                Spacer()
            }

            Text(listing.shortAddress).font(.headline)
            Text(listing.cityStateZip).foregroundStyle(.secondary)

            HStack(spacing: 14) {
                Label("\(listing.beds) bd", systemImage: "bed.double")
                Label("\(listing.formattedBaths) ba", systemImage: "shower")
                Label("\(listing.sqft.formatted()) sqft", systemImage: "square.dashed")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.top, 2)
        }
        .padding(.horizontal)
    }

    private func facts(for listing: Listing) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Facts").font(.headline)

            LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading),
                                GridItem(.flexible(), alignment: .leading)],
                      spacing: 10) {
                fact("Type", listing.propertyType.rawValue)
                fact("Built", String(listing.yearBuilt))
                fact("$/sqft", "$\(listing.pricePerSqft)")
                fact("On market", "\(listing.daysOnMarket) days")
            }

            Button {
                showingMortgageCalculator = true
            } label: {
                Label("Estimate monthly payment", systemImage: "percent")
            }
            .buttonStyle(.bordered)
            .padding(.top, 4)
        }
        .padding(.horizontal)
    }

    private func fact(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.medium))
        }
    }

    private func summary(for listing: Listing) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About this home").font(.headline)
            Text(listing.summary).font(.body)
        }
        .padding(.horizontal)
    }

    private func agentCard(for listing: Listing) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Listed by").font(.headline)

            HStack(spacing: 12) {
                Text(listing.agent.initials)
                    .font(.headline)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(.tint.opacity(0.15)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(listing.agent.name).font(.subheadline.weight(.semibold))
                    Text(listing.agent.brokerage).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }

            Button {
                contactTarget = listing
            } label: {
                Text("Request a tour").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(.horizontal)
    }

    private func saveButton(for listing: Listing) -> some View {
        Button {
            let nowSaved = savedHomes.toggleSaved(listing.id)

            // Breadcrumbs carry currentView and previousView, so this is the cheapest direct check
            // that the referrer model is working: the crumb should name Listing Detail.
            NewRelic.recordBreadcrumb(nowSaved ? "home_saved" : "home_unsaved", attributes: [
                "listingId": listing.id,
                "listingPrice": listing.price,
                "savedCount": savedHomes.savedIDs.count
            ])
        } label: {
            Image(systemName: savedHomes.isSaved(listing.id) ? "heart.fill" : "heart")
        }
        .accessibilityLabel(savedHomes.isSaved(listing.id) ? "Remove from saved" : "Save home")
    }
}
