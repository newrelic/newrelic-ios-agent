//
//  SlidersView.swift
//  NRTestApp
//
//  Created by Mike Bruin on 3/12/25.
//

import SwiftUI
import NewRelic

struct SlidersView: View {
    @State private var continuousValue: Double = 50
    @State private var discreteValue: Double = 1
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Continuous Slider")
                .font(.headline)
#if !os(tvOS)
            
            Slider(value: $continuousValue, in: 0...100, step: 1)
#endif
            Text("Value: \(continuousValue, specifier: "%.0f")")
            
            Divider()
            
            Text("Discrete Slider")
                .font(.headline)
#if !os(tvOS)
            Slider(value: $discreteValue, in: 1...5, step: 1)
#endif
            Text("Value: \(Int(discreteValue))")
            
            Spacer()
        }
        .padding()
#if !os(tvOS)
        .navigationBarTitle("Sliders", displayMode: .inline)
#endif
        .NRTrackView(name: "SlidersView")
    }
}
