//
//  ShapesView.swift
//  NRTestApp
//
//  Created by Mike Bruin on 3/12/25.
//

import SwiftUI
import NewRelic

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
            .navigationBarTitle("Shapes", displayMode: .inline)
        }
        .NRTrackView(name: "ShapesView")
        .onAppear {
            let _ = ViewBodyTracker.track(self)  // ← At top level view
        }
    }
}

struct ShapesView_Previews: PreviewProvider {
    static var previews: some View {
        ShapesView()
    }
}
