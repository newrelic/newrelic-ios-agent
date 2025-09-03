//
//  ScrollViewsView.swift
//  NRTestApp
//
//  Created by Mike Bruin on 3/12/25.
//

import SwiftUI
import NewRelic

@available(iOS 14.0, *)
struct ScrollViewsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ForEach(0..<50) { index in
                    Text("Item \(index)")
                        .font(.title)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.3))
                        .cornerRadius(10)
                }
            }
            .padding()
        }
        .navigationTitle("Scroll Views")
        .NRTrackView(name: "ScrollViewsView")
    }
}
