import SwiftUI

struct AddCardView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var cardNumber = ""
    @State private var cvv = ""
    @State private var expiry = ""
    @State private var name = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Card details") {
                    TextField("Card number", text: $cardNumber)
                    TextField("CVV", text: $cvv)
                    TextField("Expiry MM/YY", text: $expiry)
                    TextField("Cardholder name", text: $name)
                }
                Section {
                    Text("We use bank-level encryption to protect your information.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add Card")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        appState.cards.append(
                            PaymentCard(brand: "Visa", cardNumber: cardNumber, cvv: cvv,
                                        expiry: expiry, cardholderName: name)
                        )
                        dismiss()
                    }
                }
            }
        }
    }
}
