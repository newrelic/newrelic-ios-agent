//
//  AddExpenseScreen.swift
//  ExpensesTracker
//
//  Port of compose/AddExpenseScreen.kt — name, amount, category, date, image URL and description, with a
//  Save button that stays disabled until name, amount and date are filled in.
//
//  Changes from the Compose original, all consequences of it being a sheet on a platform with a Form:
//
//    * `ExposedDropdownMenuBox` becomes a `Picker`, which is what iOS offers for a fixed set of options.
//
//    * The date field was a free-text `OutlinedTextField` the user had to type "Oct 13, 2025" into, and the
//      Save button was gated on it being non-empty — so the most likely outcome was a nonsense date. It is a
//      `DatePicker`, formatted the same way for display.
//
//    * The image URL field is dropped. Every URL fed to it went to Coil, and this app has no Coil, no
//      network beyond localhost, and draws its thumbnails from the category (see ExpenseImage). A field
//      whose value can have no effect is worse than no field.
//

import SwiftUI
import NewRelic

struct AddExpenseScreen: View {

    let onSave: (ExpenseItem) -> Void

    @State private var name = ""
    @State private var amount = ""
    @State private var category = ExpenseItem.categories[0]
    @State private var date = Date()
    @State private var description = ""

    @Environment(\.dismiss) private var dismiss

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !amount.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Enter Expense Details") {
                    TextField("Expense Name", text: $name, prompt: Text("e.g., Groceries"))
                        .accessibilityIdentifier("swiftui.add.name")

                    TextField("Amount", text: $amount, prompt: Text("e.g., $125.50"))
                        .keyboardType(.decimalPad)
                        .accessibilityIdentifier("swiftui.add.amount")

                    Picker("Category", selection: $category) {
                        ForEach(ExpenseItem.categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    .accessibilityIdentifier("swiftui.add.category")

                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                Section("Description") {
                    TextField("Description",
                             text: $description,
                             prompt: Text("Enter expense description..."),
                             axis: .vertical)
                        .lineLimit(3...6)
                        .accessibilityIdentifier("swiftui.add.description")
                }
            }
            .navigationTitle("Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                        .accessibilityIdentifier("swiftui.add.save")
                }
            }
        }
    }

    private func save() {
        let expense = ExpenseItem(id: UUID().uuidString,
                                 name: name.trimmingCharacters(in: .whitespaces),
                                 amount: amount.trimmingCharacters(in: .whitespaces),
                                 category: category,
                                 imageURL: "",
                                 description: description,
                                 date: Self.dateFormatter.string(from: date))

        NewRelic.recordBreadcrumb("swiftui_expense_added", attributes: [
            "category": expense.category,
            "screen": ViewName.swiftUIAddExpense.rawValue
        ])

        onSave(expense)
    }

    /// "Oct 13, 2025" — the format the Compose placeholder asked the user to type by hand.
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()
}
