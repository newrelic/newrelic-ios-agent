//
//  ExpenseViewController.swift
//  ExpensesTracker
//
//  Port of expenseFragment. Everything it shared with incomeFragment now lives in
//  LedgerListViewController; what is left is the ledger kind and its one-tap reporting button.
//
//  Android's `fab_test_exception` did two things in a single tap, with no menu: it caught a deliberate
//  null dereference and reported it as a handled exception with two attributes, then recorded an
//  ErrorEvent custom event. Both are kept, including the pair of attribute sets, because a button that
//  reports two different things at once is a genuinely useful thing to have in a test harness — it
//  produces a handled exception and a custom event with one correlated timestamp.
//

import UIKit
import NewRelic

final class ExpenseViewController: LedgerListViewController {

    /// The error the Android version produced by calling `.length()` on a null String. Swift will not let
    /// that be written, so the equivalent failure is spelled out.
    private enum SimulatedFailure: LocalizedError {
        case missingValue

        var errorDescription: String? {
            "Attempted to read a value that was not present"
        }
    }

    init(store: LedgerStore) {
        super.init(kind: .expense, store: store)
    }

    override func presentTestMenu() {
        do {
            throw SimulatedFailure.missingValue
        } catch {
            showToast("Handled exception sent to New Relic")

            NewRelic.recordError(error, attributes: [
                "error_source": "expense_view",
                "user_action": "test_button_click"
            ])
        }

        NewRelic.recordCustomEvent("ErrorEvent", attributes: [
            "error_type": "custom_error",
            "feature": "expense_tracking",
            "severity": "warning"
        ])
    }
}
