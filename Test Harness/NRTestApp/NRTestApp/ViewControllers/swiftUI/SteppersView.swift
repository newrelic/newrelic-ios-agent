//
//  SteppersView.swift
//  NRTestApp
//
//  Created by Mike Bruin on 3/12/25.
//

import SwiftUI
import NewRelic

@available(iOS 14.0, *)
struct SteppersView: View {
    @State private var stepperValue: Int = 0

    var body: some View {
        VStack {
            Text("Current Value: \(stepperValue)")
                .font(.largeTitle)
                .padding()

            Stepper("Value: \(stepperValue)", value: $stepperValue, in: 0...100)
                .padding()

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

@available(iOS 14.0, *)
struct SteppersView_Previews: PreviewProvider {
    static var previews: some View {
        SteppersView()
    }
}
