//
//  NumberFormatting.swift
//  ExpensesTracker
//
//  Port of the Android app's Numberutills — grouped decimal formatting, US locale, so the ported
//  screens show "1,250" where the original showed "1,250".
//
//  The Android class had two overloads (int and double) that both delegated to
//  NumberFormat.getNumberInstance(Locale.US). Swift's Int/Double both satisfy BinaryInteger or
//  BinaryFloatingPoint, so one function of each shape covers it.
//

import Foundation

enum NumberFormatting {

    /// Grouped, no forced decimals: 1250 → "1,250". Mirrors NumberFormat.getNumberInstance(US).
    private static let grouping: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 3
        return formatter
    }()

    /// Always two decimals: used for the dashboard balance, which the Android app formatted with
    /// DecimalFormat("#,##0.00").
    private static let balance: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    static func format(_ number: Int) -> String {
        grouping.string(from: NSNumber(value: number)) ?? String(number)
    }

    static func format(_ number: Double) -> String {
        grouping.string(from: NSNumber(value: number)) ?? String(number)
    }

    static func formatBalance(_ number: Double) -> String {
        balance.string(from: NSNumber(value: number)) ?? String(number)
    }
}
