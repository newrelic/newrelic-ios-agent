//
//  GridsView.swift
//  NRTestApp
//
//  Created by Mike Bruin on 3/12/25.
//

import SwiftUI
import NewRelic

struct GridsView: View {
    let items = Array(1...30)

    var body: some View {
        // Scrolls because ten rows of items are taller than an iPhone screen; without it the stack overflows
        // under the navigation bar and past the bottom edge.
        ScrollView {
            VStack {
                Text("Grid Layout Example")
                    .font(.largeTitle)
                    .padding()

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
                .padding()
            }
        }
        .NRTrackView(name: "GridsView")
    }
}

struct GridsView_Previews: PreviewProvider {
    static var previews: some View {
        GridsView()
    }
}
