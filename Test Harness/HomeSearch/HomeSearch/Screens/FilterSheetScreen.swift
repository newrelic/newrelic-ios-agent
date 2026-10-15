//
//  FilterSheetScreen.swift
//  HomeSearch
//
//  The filter sheet. Presented by `.NRMobileSheet(isPresented:)` in SearchTab, so this file has no
//  MobileViews call of its own — the modifier at the presentation site names it. That is the shape
//  we want customers to copy: instrumentation attached where the presentation is declared, not
//  scattered inside the presented view.
//

import SwiftUI
import NewRelic

struct FilterSheetScreen: View {

    @Environment(ListingStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// Edited locally so Cancel is a real cancel and the results list does not churn while dragging
    /// a slider.
    @State private var draft = Filters()
    @State private var didLoadDraft = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Price") {
                    priceRow("Minimum", value: $draft.minPrice)
                    priceRow("Maximum", value: $draft.maxPrice)
                }

                Section("Bedrooms & bathrooms") {
                    Stepper("Beds: \(draft.minBeds)+", value: $draft.minBeds, in: 0...6)
                    Stepper("Baths: \(draft.minBaths)+", value: $draft.minBaths, in: 0...5)
                }

                Section("Property type") {
                    ForEach(Listing.PropertyType.allCases, id: \.self) { type in
                        Toggle(type.rawValue, isOn: Binding(
                            get: { draft.propertyTypes.contains(type) },
                            set: { isOn in
                                if isOn {
                                    draft.propertyTypes.insert(type)
                                } else if draft.propertyTypes.count > 1 {
                                    // Keep at least one type selected so the list is never empty
                                    // for a reason the user cannot see.
                                    draft.propertyTypes.remove(type)
                                }
                            }
                        ))
                    }
                }

                Section {
                    Toggle("New listings only", isOn: $draft.newListingsOnly)
                }

                Section {
                    Button("Reset all filters") { draft = Filters() }
                        .disabled(draft.isDefault)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { apply() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                guard !didLoadDraft else { return }
                draft = store.filters
                didLoadDraft = true
            }
        }
    }

    private func priceRow(_ label: String, value: Binding<Int>) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(label)
                Spacer()
                Text(value.wrappedValue.formatted(.currency(code: "USD").precision(.fractionLength(0))))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(
                value: Binding(
                    get: { Double(value.wrappedValue) },
                    set: { value.wrappedValue = Int($0 / 25_000) * 25_000 }
                ),
                in: 0...Double(Filters.priceCeiling)
            )
        }
    }

    private func apply() {
        store.filters = draft

        // Recorded from inside the sheet, so this crumb should name Filters as the current view and
        // Search as the previous one.
        NewRelic.recordBreadcrumb("filters_applied", attributes: draft.breadcrumbAttributes)

        dismiss()
    }
}
