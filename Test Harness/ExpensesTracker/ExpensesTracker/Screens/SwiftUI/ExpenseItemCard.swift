//
//  ExpenseItemCard.swift
//  ExpensesTracker
//
//  Port of compose/ExpenseItemCard.kt — a tappable row with a thumbnail, name, category and amount.
//

import SwiftUI

struct ExpenseItemCard: View {

    let expense: ExpenseItem

    var body: some View {
        HStack(spacing: 12) {
            ExpenseImage(item: expense)
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text(expense.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)
                Text(expense.category)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(expense.amount)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(Theme.home))
        }
        .padding(16)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
        .accessibilityIdentifier("swiftui.expense.\(expense.name)")
    }
}
