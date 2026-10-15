//
//  MortgageCalculatorScreen.swift
//  HomeSearch
//
//  Monthly payment estimator, presented by `.NRMobilePopover` from ListingDetailScreen.
//
//  Popovers are the awkward presentation to instrument: on iPhone SwiftUI renders a popover as a
//  sheet, on iPad as an actual popover, and the two take different paths through UIKit. Having a
//  real one in the app means we find out whether it reports consistently on both.
//

import SwiftUI

struct MortgageCalculatorScreen: View {

    let listing: Listing

    @State private var downPaymentPercent: Double = 20
    @State private var interestRate: Double = 6.5
    @State private var termYears: Int = 30

    private var downPayment: Double {
        Double(listing.price) * downPaymentPercent / 100
    }

    private var principal: Double {
        Double(listing.price) - downPayment
    }

    /// Standard amortising payment. Guards the zero-rate case so the formula cannot divide by zero.
    private var monthlyPayment: Double {
        let monthlyRate = interestRate / 100 / 12
        let payments = Double(termYears * 12)
        guard monthlyRate > 0 else { return principal / payments }
        let growth = pow(1 + monthlyRate, payments)
        return principal * monthlyRate * growth / (growth - 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Estimated payment").font(.headline)
                Text(listing.shortAddress).font(.caption).foregroundStyle(.secondary)
            }

            Text(monthlyPayment.formatted(.currency(code: "USD").precision(.fractionLength(0))) + " / mo")
                .font(.system(.largeTitle, design: .rounded).bold())
                .monospacedDigit()
                .contentTransition(.numericText())

            VStack(alignment: .leading, spacing: 14) {
                slider("Down payment",
                       detail: "\(Int(downPaymentPercent))% · " +
                               downPayment.formatted(.currency(code: "USD").precision(.fractionLength(0))),
                       value: $downPaymentPercent,
                       range: 3...50)

                slider("Interest rate",
                       detail: String(format: "%.2f%%", interestRate),
                       value: $interestRate,
                       range: 2...9)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Term").font(.subheadline.weight(.medium))
                    Picker("Term", selection: $termYears) {
                        Text("15 yr").tag(15)
                        Text("20 yr").tag(20)
                        Text("30 yr").tag(30)
                    }
                    .pickerStyle(.segmented)
                }
            }

            Text("Principal and interest only. Taxes, insurance and any HOA dues are not included.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(22)
        .frame(minWidth: 320)
        .presentationCompactAdaptation(.popover)
    }

    private func slider(_ label: String,
                        detail: String,
                        value: Binding<Double>,
                        range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.subheadline.weight(.medium))
                Spacer()
                Text(detail).font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            Slider(value: value, in: range)
        }
    }
}
