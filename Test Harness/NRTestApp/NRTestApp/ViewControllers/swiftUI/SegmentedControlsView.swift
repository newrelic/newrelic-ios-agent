//
//  SegmentedControlsView.swift
//  NRTestApp
//
//  Created by Mike Bruin on 3/12/25.
//

import SwiftUI
import NewRelic

@available(iOS 14.0, *)
struct SegmentedControlsView: View {
    @State private var selectedSegment = 0
    let segments = ["Option 1", "Option 2", "Option 3"]

    var body: some View {
        VStack {
            Text("Selected Segment: \(segments[selectedSegment])")
                .font(.headline)
                .padding()

            Picker("Select an option", selection: $selectedSegment) {
                ForEach(0..<segments.count) { index in
                    Text(segments[index]).tag(index)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()

            Spacer()
        }
        .navigationTitle("Segmented Controls")
        .NRTrackView(name: "SegmentedControlsView")
    }
}

@available(iOS 14.0, *)
struct SegmentedControlsView_Previews: PreviewProvider {
    static var previews: some View {
        SegmentedControlsView()
    }
}
