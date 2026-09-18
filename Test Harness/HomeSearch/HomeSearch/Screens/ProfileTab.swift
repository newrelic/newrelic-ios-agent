//
//  ProfileTab.swift
//  HomeSearch
//
//  Account and settings. Plain SwiftUI navigation: value-based `NavigationLink`s over
//  `ProfileRoute`, resolved by a single `.navigationDestination(for:)` on the stack.
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
                    NavigationLink(value: ProfileRoute.notificationSettings) {
                        Label("Notifications", systemImage: "bell")
                    }

                    NavigationLink(value: ProfileRoute.searchPreferences) {
                        Label("Search preferences", systemImage: "slider.horizontal.3")
                    }
                }

                Section {
                    // Debug Info declares its own opt-out inside DebugInfoScreen, so nothing at the
                    // presentation site names it.
                    NavigationLink(value: ProfileRoute.debugInfo) {
                        Label("Debug info", systemImage: "ladybug")
                    }
                } footer: {
                    Text("Debug info carries no MobileView modifier, so it should never appear in MobileView data.")
                }
            }
            .navigationTitle("Profile")
            //.NRMobileView(name: ViewName.profile.rawValue)
            .navigationDestination(for: ProfileRoute.self) { route in
                switch route {
                case .notificationSettings:
                    NotificationSettingsScreen()
                case .searchPreferences:
                    SearchPreferencesScreen()
                case .debugInfo:
                    DebugInfoScreen()
                }
            }
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
