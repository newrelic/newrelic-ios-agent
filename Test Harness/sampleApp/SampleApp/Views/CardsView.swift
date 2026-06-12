import SwiftUI

struct CardsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(appState.cards) { card in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(card.brand).font(.caption).foregroundStyle(.secondary)
                        Text(card.cardNumber).font(.title3.monospaced())
                        HStack {
                            Text("Exp \(card.expiry)")
                            Spacer()
                            Text("CVV \(card.cvv)")
                            Spacer()
                            Text(card.cardholderName)
                        }
                        .font(.caption)
                    }
                    .padding(.vertical, 4)
                }
                Section {
                    Text("Your card details are encrypted and never shared.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Cards")
            .toolbar {
                Button("Add card") { showAdd = true }
            }
            .sheet(isPresented: $showAdd) {
                AddCardView()
            }
        }
    }
}
