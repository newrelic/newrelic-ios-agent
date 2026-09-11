//
//  ProfileTab.swift
//  HomeSearch
//
//  Account and settings. Uses `NRMobileNavigationLink` for its rows — the wrapper around the
//  destination-and-label form of NavigationLink, for pushes that carry no route value.
//
//  Both value-based navigation (Search, Saved, Inbox) and link-based navigation (here) are in the
//  app on purpose, since they take different paths through SwiftUI and there is no reason to assume
//  they report identically.
//

import SwiftUI
import NewRelic

struct ProfileTab: View {

    @Environment(ListingStore.self) private var store
    @Environment(SavedHomesStore.self) private var savedHomes

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        Circle()
                            .fill(.tint.opacity(0.15))
                            .frame(width: 52, height: 52)
                            .overlay {
                                Image(systemName: "person.fill")
                                    .font(.title3)
                                    .foregroundStyle(.tint)
                            }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Jordan Alvarez").font(.headline)
                            Text("jordan@example.com")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Activity") {
                    statRow("Saved homes", value: savedHomes.savedIDs.count, symbol: "heart.fill")
                    statRow("Recently viewed", value: savedHomes.recentlyViewedIDs.count,
                            symbol: "clock.fill")
                    statRow("Conversations", value: store.threads.count, symbol: "envelope.fill")
                }

                Section("Settings") {
                    NRMobileNavigationLink(name: ViewName.notificationSettings.rawValue) {
                        NotificationSettingsScreen()
                    } label: {
                        Label("Notifications", systemImage: "bell")
                    }

                    NRMobileNavigationLink(name: ViewName.searchPreferences.rawValue) {
                        SearchPreferencesScreen()
                    } label: {
                        Label("Search preferences", systemImage: "slider.horizontal.3")
                    }
                }

                Section {
                    // Deliberately a plain NavigationLink, not NRMobileNavigationLink.
                    //
                    // NRMobileNavigationLink always attaches a *reporting* .NRMobileView to its
                    // destination, so wrapping Debug Info in one would emit an event no matter what
                    // the destination itself asks for — the `ignored: true` inside DebugInfoScreen
                    // would be overridden by the link. Opting a screen out means not naming it at
                    // the presentation site and letting the screen declare the opt-out itself.
                    NavigationLink {
                        DebugInfoScreen()
                    } label: {
                        Label("Debug info", systemImage: "ladybug")
                    }
                } footer: {
                    Text("Debug info opts out of view tracking, so it should never appear in MobileView data.")
                }
            }
            .navigationTitle("Profile")
            .NRMobileView(name: ViewName.profile.rawValue)
        }
    }

    private func statRow(_ title: String, value: Int, symbol: String) -> some View {
        HStack {
            Label(title, systemImage: symbol)
            Spacer()
            Text("\(value)")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}
