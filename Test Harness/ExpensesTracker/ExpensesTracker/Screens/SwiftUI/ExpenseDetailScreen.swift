//
//  ExpenseDetailScreen.swift
//  ExpensesTracker
//
//  Port of compose/ExpenseDetailScreen.kt — a hero image, the amount, the name, date and category, and a
//  description card.
//
//  The back button is gone: Compose had to supply its own `navigationIcon` calling `popBackStack()`, while a
//  `NavigationStack` push already has one. Keeping a second would give the screen two ways back.
//

import SwiftUI

struct ExpenseDetailScreen: View {

    let expense: ExpenseItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ExpenseImage(item: expense, cornerRadius: 0)
                    .frame(height: 250)

                VStack(alignment: .leading, spacing: 0) {
                    Text(expense.amount)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(Color(Theme.home))
                        .accessibilityIdentifier("swiftui.detail.amount")

                    Text(expense.name)
                        .font(.system(size: 24, weight: .semibold))
                        .padding(.top, 8)

                    HStack {
                        Text(expense.date)
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(expense.category)
                            .font(.system(size: 12))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(Theme.accentGreen).opacity(0.28),
                                       in: Capsule())
                    }
                    .padding(.top, 4)

                    Text("Description")
                        .font(.system(size: 18, weight: .semibold))
                        .padding(.top, 24)

                    Text(expense.description)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Color(.secondarySystemBackground),
                                   in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.top, 8)
                }
                .padding(16)
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle("Expense Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}
