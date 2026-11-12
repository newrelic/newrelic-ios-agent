//
//  ExpenseListScreen.swift
//  ExpensesTracker
//
//  Port of compose/ExpenseListScreen.kt — the SwiftUI section's root: a welcome card, a total, and the list
//  of expenses, with a close button and an add button.
//
//  Two details from the Compose original are worth calling out.
//
//  Its "Total Expenses" card displayed the hardcoded string "$343.54", which happened to be the sum of the
//  five seeded entries and silently stopped being true the moment you added a sixth. It is computed here —
//  the amounts are display strings so the sum parses them, which is ugly, but a total that lies is worse.
//
//  It also embedded a native `TextView` via `AndroidView` purely to prove interop worked. The iOS analogue
//  is `UIViewRepresentable`, and it is kept for the same reason: a UIKit view inside the SwiftUI tree is a
//  case the agent's view instrumentation has to handle, and this is the only place in the app that produces
//  one.
//

import SwiftUI
import UIKit

struct ExpenseListScreen: View {

    let expenses: [ExpenseItem]
    let onClose: () -> Void
    let onAdd: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                welcomeCard
                totalCard

                Text("Recent Expenses")
                    .font(.system(size: 20, weight: .bold))

                NativeLabel(text: "Native UIKit label – showing \(expenses.count) expenses")
                    .frame(height: 20)

                LazyVStack(spacing: 8) {
                    ForEach(expenses) { expense in
                        NavigationLink(value: expense) {
                            ExpenseItemCard(expense: expense)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
        }
        .background(Color(.secondarySystemBackground))
        .navigationTitle("SwiftUI Screen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close", systemImage: "chevron.left", action: onClose)
                    .accessibilityIdentifier("swiftui.close")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add Expense", systemImage: "plus", action: onAdd)
                    .accessibilityIdentifier("swiftui.add")
            }
        }
    }

    private var welcomeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Welcome to SwiftUI!")
                .font(.system(size: 24, weight: .bold))
            Text("This half of the app is built with SwiftUI, so its views report through the MobileViews SwiftUI modifiers rather than the UIKit path.")
                .font(.system(size: 14))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(Theme.home).opacity(0.12),
                   in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var totalCard: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Total Expenses")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
            Text(formattedTotal)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(Color(Theme.home))
                .accessibilityIdentifier("swiftui.total")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.systemBackground),
                   in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// The amounts are display strings like "$125.50" — see the note in ExpenseItem about why they stay
    /// that way — so summing means stripping everything that is not a digit or a decimal point.
    private var formattedTotal: String {
        let total = expenses.reduce(0.0) { sum, expense in
            let digits = expense.amount.filter { $0.isNumber || $0 == "." }
            return sum + (Double(digits) ?? 0)
        }
        return "$" + NumberFormatting.formatBalance(total)
    }
}

/// The `AndroidView { TextView(...) }` equivalent: a genuine UIKit view living inside the SwiftUI tree.
private struct NativeLabel: UIViewRepresentable {

    let text: String

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.font = .boldSystemFont(ofSize: 14)
        label.textColor = Theme.buttonText
        label.accessibilityIdentifier = "swiftui.nativelabel"
        return label
    }

    func updateUIView(_ label: UILabel, context: Context) {
        label.text = text
    }
}
