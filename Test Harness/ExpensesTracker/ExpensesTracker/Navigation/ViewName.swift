//
//  ViewName.swift
//  ExpensesTracker
//
//  The single source of truth for every view name this app reports to New Relic.
//
//  Nothing in the app passes a view-name string literal: every `.NRMobileView(name:)`,
//  `.NRMobileDestination(name:)`, `.NRMobileSheet(name:)` and `NewRelic.setCurrentView(_:)` call site
//  reads its name from here. That means the complete expected inventory is `ViewName.allCases`, NRQL
//  expectations can be written straight off this list, and a typo cannot silently invent a phantom
//  view name. HomeSearch established this pattern for the same reason.
//
//  Names are deliberately stable and low-cardinality. A tapped income or expense row reports
//  "Update Record" and carries its purpose as a custom *attribute* rather than baking it into the
//  name — view name is a facet, and unbounded names make a facet useless.
//
//  The `uiPlatform` split is worth keeping in mind when reading these: the first eight names come
//  from UIKit view controllers, the last four from the SwiftUI section, mirroring the Android app's
//  split between its Activities/Fragments and its ComposeActivity.
//

import Foundation

enum ViewName: String, CaseIterable {

    // MARK: UIKit — the Activity/Fragment half

    /// SpalashScreen on Android. Spelling corrected in the port; the Android typo is not worth
    /// preserving in data we intend to query.
    case splash          = "Splash"
    /// MainActivity on Android, which was the login screen despite the name.
    case login           = "Login"
    case registration    = "Registration"
    case forgotPassword  = "Forgot Password"
    /// HomeActivity's chrome: toolbar, tab bar, side menu.
    case home            = "Home"

    /// The three tabs. On Android these were Fragments inside HomeActivity, so automatic
    /// instrumentation attributed all three to the one Activity; here they are reported explicitly
    /// with setCurrentView so each tab is its own view.
    case dashboard       = "Dashboard"
    case income          = "Income"
    case expense         = "Expense"

    /// The Android `custom_layout_for_adding_data` dialog, presented for income or expense.
    case addRecord       = "Add Record"
    /// The Android `update_item` dialog, reached by tapping a row.
    case updateRecord    = "Update Record"
    /// The side menu, a drawer on Android.
    case sideMenu        = "Side Menu"
    /// The New Relic test menu. Instrumented like any other screen — the events it generates are
    /// the point of the app, so the menu that generates them should be visible in the timeline too.
    case testMenu        = "New Relic Test Menu"

    // MARK: SwiftUI — the ComposeActivity half

    /// ComposeActivity's start destination, titled "Jetpack Compose Screen" on Android; retitled
    /// here since there is no Compose on iOS.
    case swiftUIExpenseList   = "SwiftUI Expense List"
    case swiftUIExpenseDetail = "SwiftUI Expense Detail"
    case swiftUIAddExpense    = "SwiftUI Add Expense"
}
