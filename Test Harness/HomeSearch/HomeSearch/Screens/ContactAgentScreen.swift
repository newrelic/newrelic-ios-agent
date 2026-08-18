//
//  ContactAgentScreen.swift
//  HomeSearch
//
//  Tour request form. Presented by `.NRMobileSheet(item:)` from ListingDetailScreen — the
//  item-driven variant, so the sheet's identity comes from the listing being asked about.
//
//  Submitting completes the funnel this app is built to produce:
//
//      Search → Listing Detail → Contact Agent → Tour Requested
//
//  which is the referrer chain to check `previousView` against.
//

import SwiftUI
import NewRelic

struct ContactAgentScreen: View {

    let listing: Listing
    let onSubmit: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var message = ""
    @State private var preferredDay: TourDay = .saturday

    enum TourDay: String, CaseIterable, Identifiable {
        case saturday = "Saturday"
        case sunday = "Sunday"
        case weekday = "A weekday"
        var id: String { rawValue }
    }

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        email.contains("@")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(listing.shortAddress).font(.subheadline.weight(.semibold))
                        Text(listing.formattedPrice).foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Property")
                }

                Section("Your details") {
                    TextField("Full name", text: $name)
                        .textContentType(.name)
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    TextField("Phone (optional)", text: $phone)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                }

                Section("When works for you?") {
                    Picker("Preferred day", selection: $preferredDay) {
                        ForEach(TourDay.allCases) { day in
                            Text(day.rawValue).tag(day)
                        }
                    }
                }

                Section("Anything else?") {
                    TextField("Message to \(listing.agent.name)",
                              text: $message,
                              axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Button {
                        submit()
                    } label: {
                        Text("Send request").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSubmit)
                }
            }
            .navigationTitle("Request a tour")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func submit() {
        // Deliberately no PII on the breadcrumb — name, email and phone stay on the device. What is
        // useful for validation is which listing and which agent, plus the funnel step.
        NewRelic.recordBreadcrumb("tour_requested", attributes: [
            "listingId": listing.id,
            "agentId": listing.agent.id,
            "preferredDay": preferredDay.rawValue,
            "hasMessage": !message.trimmingCharacters(in: .whitespaces).isEmpty,
            "funnelStep": "contact_submitted"
        ])

        onSubmit()
    }
}
