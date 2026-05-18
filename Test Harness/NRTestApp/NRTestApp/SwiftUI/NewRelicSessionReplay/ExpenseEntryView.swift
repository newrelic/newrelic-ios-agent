//
//  expenseView.swift
//  xc
//
//  Created by Jose Fernandes on 9/2/24.
//

import SwiftUI

struct ExpenseEntryView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var expenses: [Expense]
    var expenseToEdit: Expense?
    var onSave: (Expense) -> Void
    
    @State private var selectedExpenseType: ExpenseType = .initialVisit
    @State private var selectedDate: Date = Date()
    @State private var amount: String = ""
    
    init(expenses: Binding<[Expense]>, expenseToEdit: Expense? = nil, onSave: @escaping (Expense) -> Void) {
        self._expenses = expenses
        self.expenseToEdit = expenseToEdit
        self.onSave = onSave
        
        if let expense = expenseToEdit {
            _selectedExpenseType = State(initialValue: expense.type)
            _selectedDate = State(initialValue: expense.date)
            _amount = State(initialValue: String(expense.amount))
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Expense Type")) {
                    Picker("Type", selection: $selectedExpenseType) {
                        ForEach(ExpenseType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                }
                
                Section(header: Text("Date")) {
                    DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
                }
                
                Section(header: Text("Amount")) {
                    TextField("Enter Amount", text: $amount)
                        .keyboardType(.decimalPad)
                }
                
                Section {
                    Button(expenseToEdit == nil ? "Add Expense" : "Save Changes") {
                        saveExpense()
                    }
                }
            }
            .navigationTitle(expenseToEdit == nil ? "Add Expense" : "Edit Expense")
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .navigationViewStyle(.stack)
    }
    
    private func saveExpense() {
        if let amountValue = Double(amount) {
            let newExpense = Expense(type: selectedExpenseType, date: selectedDate, amount: amountValue)
            onSave(newExpense)
            presentationMode.wrappedValue.dismiss()
        } else {
            // Handle invalid input if needed
        }
    }
}

