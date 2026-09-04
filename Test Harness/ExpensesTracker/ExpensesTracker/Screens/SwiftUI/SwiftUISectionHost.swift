//
//  SwiftUISectionHost.swift
//  ExpensesTracker
//
//  Port of ComposeActivity — the entry point into the app's second UI toolkit, and its navigation graph.
//
//  Android reached this through a toolbar menu item that started a separate Activity, whose whole content
//  was a Compose `NavHost` with three destinations. Here it is a UIHostingController presented modally
//  from HomeViewController, wrapping a `NavigationStack`. Same idea: a self-contained UI stack, in a
//  different toolkit, reached from the UIKit half of the app.
//
//  The navigation is where this port earns its keep for the agent. The Compose graph passed the selected
//  expense between destinations by JSON-encoding it into the route string — `expense_detail/$expenseJson` —
//  which is a Compose-navigation constraint, not a design choice. `NavigationStack(path:)` carries the value
//  itself, and `.NRMobileDestination(for:)` reports the destination it pushes. Which means all three
//  destinations here are reported by the MobileViews SwiftUI API rather than by hand:
//
//      .NRMobileView          → the list, the section's root
//      .NRMobileDestination   → the detail screen, pushed with a value
//      .NRMobileSheet         → the add screen, which Compose pushed as a third route
//
//  The add screen becomes a sheet rather than a push because that is what iOS does with a modal form, and
//  because it exercises a different modifier — worth having when the point is coverage of the API surface.
//

import SwiftUI
import UIKit
import NewRelic

enum SwiftUISectionHost {

    static func makeViewController() -> UIViewController {
        // `dismiss` in the environment does not reach a UIHostingController that UIKit presented, so the
        // close action is handed in explicitly and the controller is captured weakly once it exists.
        var controller: UIHostingController<SwiftUISectionView>?
        let root = SwiftUISectionView(onClose: { controller?.dismiss(animated: true) })

        let hosting = UIHostingController(rootView: root)
        hosting.overrideUserInterfaceStyle = .light
        controller = hosting
        return hosting
    }
}

struct SwiftUISectionView: View {

    let onClose: () -> Void

    /// ComposeActivity's `remember { mutableStateListOf(...) }` — state owned by the section, seeded with
    /// the same five entries, discarded when it closes.
    @State private var expenses = ExpenseItem.samples
    @State private var path: [ExpenseItem] = []
    @State private var isAddingExpense = false

    var body: some View {
        NavigationStack(path: $path) {
            ExpenseListScreen(
                expenses: expenses,
                onClose: onClose,
                onAdd: { isAddingExpense = true }
            )
            // Reported here rather than on the NavigationStack: the stack is a container, the list is the
            // screen, and naming the container would attribute the detail screen's push to it.
            .NRMobileView(name: ViewName.swiftUIExpenseList.rawValue,
                         attributes: ["section": "swiftui", "expense_count": expenses.count])
            .NRMobileDestination(for: ExpenseItem.self,
                                name: { _ in ViewName.swiftUIExpenseDetail.rawValue }) { expense in
                ExpenseDetailScreen(expense: expense)
            }
            .NRMobileSheet(isPresented: $isAddingExpense,
                          name: ViewName.swiftUIAddExpense.rawValue) {
                AddExpenseScreen { newExpense in
                    // Compose inserted at index 0 so the newest entry appeared first.
                    expenses.insert(newExpense, at: 0)
                    isAddingExpense = false
                }
            }
        }
        .tint(Color(Theme.home))
        .onAppear {
            NewRelic.logInfo("SwiftUI section opened with \(expenses.count) expense(s)")
        }
    }
}
