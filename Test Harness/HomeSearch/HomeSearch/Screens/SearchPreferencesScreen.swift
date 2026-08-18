//
//  SearchPreferencesScreen.swift
//  HomeSearch
//
//  Pushed from Profile by NRMobileNavigationLink, which supplies the name.
//

import SwiftUI

struct SearchPreferencesScreen: View {

    @Environment(ListingStore.self) private var store

    @State private var commuteMinutes: Double = 30
    @State private var schoolRatingFloor: Int = 6
    @State private var includePending = true

    var body: some View {
        Form {
            Section("Current filters") {
                LabeledContent("Active filters", value: "\(store.filters.activeCount)")
                LabeledContent("Sort", value: store.sortOrder.rawValue)
                LabeledContent("Results", value: "\(store.results.count) of \(store.listings.count)")
            }

            Section("Commute") {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Max commute")
                        Spacer()
                        Text("\(Int(commuteMinutes)) min")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $commuteMinutes, in: 10...90, step: 5)
                }
            }

            Section("Schools") {
                Stepper("Rating \(schoolRatingFloor)+ / 10", value: $schoolRatingFloor, in: 1...10)
            }

            Section {
                Toggle("Include pending sales", isOn: $includePending)
            } footer: {
                Text("Preferences here are illustrative — only the filters set on the Search tab affect results.")
            }
        }
        .navigationTitle("Search preferences")
        .navigationBarTitleDisplayMode(.inline)
    }
}
