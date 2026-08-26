//
//  ExpenseItem.swift
//  ExpensesTracker
//
//  Port of compose/ExpenseItem.kt, and of the sample data ComposeActivity held in a
//  `mutableStateListOf`.
//
//  This is deliberately NOT LedgerRecord. The Compose section on Android was a self-contained demo with
//  its own model — string amounts like "$125.50", a category, a remote image URL, a long description —
//  sharing nothing with the Firebase-backed screens next to it. Merging the two here would quietly change
//  what the section is, and the section's whole value as a test surface is that it exercises a *different*
//  UI toolkit over a *different* model, reached from the same app.
//
//  `amount` stays a String for the same reason: the Compose screens displayed it verbatim and the add
//  screen accepted whatever was typed. Turning it into a Decimal would be a better app and a worse port.
//

import Foundation

struct ExpenseItem: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    var amount: String
    var category: String
    var imageURL: String
    var description: String
    var date: String
}

extension ExpenseItem {

    /// The five entries ComposeActivity seeded its list with. The Unsplash URLs are replaced by
    /// `ExpenseImage`'s procedurally drawn thumbnails: this app has no network beyond localhost, and a
    /// demo screen that shows five broken images is worse than one that shows five drawn ones.
    static let samples: [ExpenseItem] = [
        ExpenseItem(id: "1",
                   name: "Groceries",
                   amount: "$125.50",
                   category: "Food",
                   imageURL: "",
                   description: "Weekly grocery shopping at the supermarket including fresh produce, dairy, and essentials.",
                   date: "Oct 10, 2025"),
        ExpenseItem(id: "2",
                   name: "Gas",
                   amount: "$45.00",
                   category: "Transportation",
                   imageURL: "",
                   description: "Fuel refill at the local gas station for weekly commute.",
                   date: "Oct 9, 2025"),
        ExpenseItem(id: "3",
                   name: "Streaming",
                   amount: "$15.99",
                   category: "Entertainment",
                   imageURL: "",
                   description: "Monthly subscription for a premium streaming service.",
                   date: "Oct 8, 2025"),
        ExpenseItem(id: "4",
                   name: "Dinner",
                   amount: "$67.80",
                   category: "Food",
                   imageURL: "",
                   description: "Family dinner at an Italian restaurant with appetizers and desserts.",
                   date: "Oct 7, 2025"),
        ExpenseItem(id: "5",
                   name: "Electric Bill",
                   amount: "$89.25",
                   category: "Utilities",
                   imageURL: "",
                   description: "Monthly electricity bill payment for home usage.",
                   date: "Oct 6, 2025")
    ]

    /// The dropdown options from AddExpenseScreen.kt, unchanged.
    static let categories = ["Food", "Transportation", "Entertainment", "Utilities",
                            "Shopping", "Healthcare", "Other"]
}
