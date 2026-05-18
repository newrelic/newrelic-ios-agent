//
//  model.swift
//  xc
//
//  Created by Jose Fernandes on 9/2/24.
//
import Foundation
import SwiftUI

struct Attachment: Identifiable {
    var id = UUID()
    var fileName: String
}

enum PaymentMethod: String {
    case healthPlan = "Health Plan"
    case spendingAccount = "Spending Account"
    case healthThenSpending = "Health then Spending Account"
}

enum ExpenseType: String, CaseIterable {
    case initialVisit = "Initial Visit"
    case subsequentVisit = "Subsequent Visit"
    case treatment = "Treatment"
    case other = "Other"
}

struct Expense: Identifiable {
    var id = UUID()
    var type: ExpenseType
    var date: Date
    var amount: Double
}


