//
//  SteppersView.swift
//  NRTestApp
//
//  Created by Mike Bruin on 3/12/25.
//

import SwiftUI
import NewRelic

@available(iOS 14.0, *)
@available(tvOS 17.0, *)

struct SteppersView: View {
    @State private var stepperValue: Int = 0
    
    var body: some View {
        VStack {
            Text("Current Value: \(stepperValue)")
                .font(.largeTitle)
                .padding()
#if !os(tvOS)
            
            
            Stepper("Value: \(stepperValue)", value: $stepperValue, in: 0...100)
                .padding()
#endif
            HStack {
                Button("Reset") {
                    stepperValue = 0
                }
                .padding()
                .buttonStyle(BorderlessButtonStyle())
                
                Button("Increase by 10") {
                    stepperValue += 10
                }
                .padding()
                .buttonStyle(BorderlessButtonStyle())
            }
        }
        .navigationTitle("Steppers")
        .padding()
        .NRTrackView(name: "SteppersView")
    }
}
