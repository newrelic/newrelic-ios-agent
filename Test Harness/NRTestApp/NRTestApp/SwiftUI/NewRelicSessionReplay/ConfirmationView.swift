//
//  ConfirmationView.swift
//  xc
//
//  Created by Jose Fernandes on 9/2/24.
//

import SwiftUI



struct ConfirmationView: View {
    var selectedPerson: String = "John Doe"
    var selectedCompanies: [String]? = ["Company A", "Company B"]
    var selectedProviders: [String] = ["Provider 1", "Provider 2"]
    var expenses: [Expense] = []
    var attachments: [Attachment] = []
    var paymentMethod: PaymentMethod = .healthPlan


    @State private var agreedToTerms: Bool = false
    @State private var showConfirmationNumber: Bool = false
    
    var body: some View {
        Form {
            Section(header: Text("Summary")) {
                Text("Person: \(selectedPerson)")
                
                if let companies = selectedCompanies, !companies.isEmpty {
                    Text("Companies: \(companies.joined(separator: ", "))")
                }
                
                Text("Providers: \(selectedProviders.joined(separator: ", "))")
                
                if !expenses.isEmpty {
                    Text("Expenses:")
                    ForEach(expenses) { expense in
                        VStack(alignment: .leading) {
                            Text("\(expense.type.rawValue) - $\(expense.amount, specifier: "%.2f")")
                            Text(expense.date, style: .date)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if !attachments.isEmpty {
                    Text("Attachments:")
                    ForEach(attachments) { attachment in
                        Text(attachment.fileName)
                    }
                }
                
                Text("Payment Method: \(paymentMethod.rawValue)")
            }
            
            Section {
                Toggle(isOn: $agreedToTerms) {
                    Text("I agree to the terms and conditions")
                }
                
                Button("Confirm") {
                    showConfirmationNumber = true
                }
                .disabled(!agreedToTerms)
            }
        }
        .navigationTitle("Confirmation")
        .alert(isPresented: $showConfirmationNumber) {
            Alert(
                title: Text("Confirmation"),
                message: Text("Your confirmation number is: \(generateConfirmationNumber())"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func generateConfirmationNumber() -> String {
        return UUID().uuidString.prefix(8).uppercased()
    }
}


#Preview{
    ConfirmationView()
}
