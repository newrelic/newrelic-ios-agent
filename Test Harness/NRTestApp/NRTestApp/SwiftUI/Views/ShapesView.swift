//
//  ShapesView.swift
//  NRTestApp
//
//  Created by Mike Bruin on 3/12/25.
//

import SwiftUI
import NewRelic

@available(tvOS 14.0, *)
struct ShapesView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Shapes in SwiftUI")
                    .font(.largeTitle)
                    .padding()

                // Rectangle
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: 100, height: 100)
                    .padding()

                // Circle
                Circle()
                    .fill(Color.red)
                    .frame(width: 100, height: 100)
                    .padding()

                // Rounded Rectangle
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color.green)
                    .frame(width: 100, height: 100)
                    .padding()

                // Ellipse
                Ellipse()
                    .fill(Color.orange)
                    .frame(width: 100, height: 50)
                    .padding()

                // Capsule
                Capsule()
                    .fill(Color.purple)
                    .frame(width: 100, height: 50)
                    .padding()

                Spacer()
            }
            #if !os(tvOS)
                .navigationBarTitle("Shapes", displayMode: .inline)
            #endif
        }
        .NRTrackView(name: "ShapesView")
    }
}
