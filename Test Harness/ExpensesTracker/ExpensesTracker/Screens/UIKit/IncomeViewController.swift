//
//  IncomeViewController.swift
//  ExpensesTracker
//
//  Port of incomeFragment — which, once its duplication of expenseFragment is factored into
//  LedgerListViewController, is just the income ledger plus the full New Relic test menu.
//
//  That menu was the largest thing in the Android app and the reason it exists: thirteen ways to make the
//  agent report something. It lives in NewRelicTestMenu, presented from here exactly as `fab_crash_test`
//  presented it there.
//

import UIKit

final class IncomeViewController: LedgerListViewController {

    init(store: LedgerStore) {
        super.init(kind: .income, store: store)
    }

    override func presentTestMenu() {
        NewRelicTestMenu.present(from: self, source: viewName.rawValue)
    }
}
