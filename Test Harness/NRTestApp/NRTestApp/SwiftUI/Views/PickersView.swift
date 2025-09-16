//
//  PickersView.swift
//  NRTestApp
//
//  Created by Mike Bruin on 3/12/25.
//

import SwiftUI
import NewRelic

@available(iOS 14.0, *)
struct PickersView: View {
    @State private var selectedOption = 0
    @State private var selectedDate = Date()
    @State private var customPickerSelection = "Option 1"
    
    let options = ["Option 1", "Option 2", "Option 3"]
    
    var body: some View {
        VStack {
            // Standard Picker
            Picker("Select an option", selection: $selectedOption) {
                ForEach(0..<options.count) { index in
                    Text(options[index]).tag(index)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            Text("Selected option: \(options[selectedOption])")
            
            // Date Picker
#if !os(tvOS)
            DatePicker("Select a date", selection: $selectedDate, displayedComponents: .date)
                .padding()
#endif
            
            Text("Selected date: \(selectedDate, formatter: dateFormatter)")
            
            // Custom Picker
            Picker("Custom Picker", selection: $customPickerSelection) {
                ForEach(options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
#if !os(tvOS)
            .pickerStyle(MenuPickerStyle())
#endif
            .padding()
            
            Text("Custom Picker selection: \(customPickerSelection)")
        }
        .navigationBarTitle("Pickers Example")
        .NRTrackView(name: "PickersView")
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
}

