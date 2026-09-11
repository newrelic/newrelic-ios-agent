//
//  NotificationSettingsScreen.swift
//  HomeSearch
//
//  Pushed from Profile by NRMobileNavigationLink, which supplies the name.
//

import SwiftUI

struct NotificationSettingsScreen: View {

    @State private var newListings = true
    @State private var priceChanges = true
    @State private var openHouses = false
    @State private var agentMessages = true
    @State private var frequency: Frequency = .daily

    enum Frequency: String, CaseIterable, Identifiable {
        case instant = "Instantly"
        case daily = "Daily digest"
        case weekly = "Weekly digest"
        var id: String { rawValue }
    }

    var body: some View {
        Form {
            Section("Alert me about") {
                Toggle("New listings in my search", isOn: $newListings)
                Toggle("Price changes on saved homes", isOn: $priceChanges)
                Toggle("Open houses nearby", isOn: $openHouses)
                Toggle("Messages from agents", isOn: $agentMessages)
            }

            Section("How often") {
                Picker("Frequency", selection: $frequency) {
                    ForEach(Frequency.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            .disabled(!newListings && !priceChanges && !openHouses && !agentMessages)
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}
