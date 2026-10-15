//
//  LedgerRecord.swift
//  ExpensesTracker
//
//  Port of the Android app's Model/data.java — one income or expense entry.
//
//  The Android class had five fields: amount (int), purpose, note, id, and `data`, which despite the
//  name held a formatted date string. The port keeps the same five pieces of information and the same
//  int amount (so totals match to the rupee/dollar exactly as they did), but renames `data` to
//  `dateText` because a field called `data` that holds a date is a trap, and this app's whole job is
//  being read by someone else.
//
//  `dateText` stays a preformatted String rather than becoming a Date. That is deliberate: it is what
//  the Android app stored and displayed, and matching it keeps the two apps' payloads comparable when
//  the same NRQL query is pointed at both.
//

import Foundation

/// Which ledger an entry belongs to. Android kept these apart by Firebase path — "IncomeData/{uid}"
/// versus "ExpenseData/{uid}" — with two otherwise identical Fragments and two identical dialogs.
/// One enum collapses that duplication without changing the data.
enum RecordKind: String, Codable, CaseIterable {
    case income
    case expense

    /// Path component on the stub server, mirroring the Firebase child names.
    var path: String {
        switch self {
        case .income:  return "income"
        case .expense: return "expense"
        }
    }

    var displayName: String {
        switch self {
        case .income:  return "Income"
        case .expense: return "Expense"
        }
    }

    var viewName: ViewName {
        switch self {
        case .income:  return .income
        case .expense: return .expense
        }
    }

    /// Expenses were shown with a leading minus on Android; income was not.
    var amountPrefix: String {
        switch self {
        case .income:  return ""
        case .expense: return "-"
        }
    }
}

struct LedgerRecord: Codable, Identifiable, Hashable {

    /// Firebase's `push().getKey()` on Android. A UUID here — the only requirement either side ever
    /// placed on it is uniqueness.
    let id: String
    var amount: Int
    var purpose: String
    var note: String
    /// Preformatted, as on Android. See the note above.
    var dateText: String

    init(id: String = UUID().uuidString,
         amount: Int,
         purpose: String,
         note: String,
         dateText: String = LedgerRecord.timestamp()) {
        self.id = id
        self.amount = amount
        self.purpose = purpose
        self.note = note
        self.dateText = dateText
    }

    /// Android used DateFormat.getInstance() when inserting and DateFormat.getDateInstance() when
    /// updating, so a record's date string silently changed shape after an edit. The port picks the
    /// short date+time form for both, since an expense list where half the rows carry a time and half
    /// do not is a bug rather than a feature worth porting.
    static func timestamp(_ date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// "-1,250" for an expense, "1,250" for income.
    func displayAmount(for kind: RecordKind) -> String {
        kind.amountPrefix + NumberFormatting.format(amount)
    }
}
