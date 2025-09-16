//
//  GridsView.swift
//  NRTestApp
//
//  Created by Mike Bruin on 3/12/25.
//

import SwiftUI
import NewRelic

// available in tvOS 14 or later

@available(iOS 14.0, *)
@available(tvOS 14.0, *)
struct GridsView: View {
    let items = Array(1...30)

    var body: some View {
        VStack {
            Text("Grid Layout Example")
                .font(.largeTitle)
                .padding()

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 20) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 20) {
                    ForEach(items, id: \.self) { item in
                        Text("Item \(item)")
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
            }
            .padding()
        }
        .NRTrackView(name: "GridsView")
    }
}
