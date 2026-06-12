import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Hello, \(appState.profile.fullName)")
                            .font(.headline)
                        Text(appState.account.nickname)
                            .foregroundStyle(.secondary)
                        Text("•••• \(appState.account.accountNumberLast4)")
                            .font(.subheadline.monospaced())
                        Text(appState.account.balance, format: .currency(code: "USD"))
                            .font(.system(size: 34, weight: .bold))
                    }
                }
                Section("Promotions") {
                    Text("Earn 2% cash back on groceries this month!")
                }
                Section("Recent activity") {
                    ForEach(appState.transactions) { tx in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(tx.merchant)
                                Text(tx.category).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(tx.amount, format: .currency(code: "USD"))
                            Text(tx.date).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Home")
        }
    }
}
