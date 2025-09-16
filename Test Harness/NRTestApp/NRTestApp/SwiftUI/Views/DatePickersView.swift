//
//  DatePickersView.swift
//  NRTestApp
//
//  Created by Mike Bruin on 3/12/25.
//

import SwiftUI
import NewRelic

@available(iOS 14.0, *)
struct DatePickersView: View {
    @State private var selectedDate = Date()
    
    var body: some View {
        VStack {
            Text("Select a Date")
                .font(.headline)
                .padding()
            
#if !os(tvOS)
            
            DatePicker("Choose a date:", selection: $selectedDate, displayedComponents: [.date])
                .datePickerStyle(GraphicalDatePickerStyle())
                .padding()
#endif
            
            Text("Selected Date: \(formattedDate(selectedDate))")
                .padding()
            
#if !os(tvOS)
            
            DatePicker("Choose a time:", selection: $selectedDate, displayedComponents: [.hourAndMinute])
                .datePickerStyle(WheelDatePickerStyle())
                .padding()
#endif
            Text("Selected Time: \(formattedTime(selectedDate))")
                .padding()
        }
#if !os(tvOS)
        
        .navigationTitle("Date Pickers")
#endif
        .NRTrackView(name: "DatePickersView")
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
