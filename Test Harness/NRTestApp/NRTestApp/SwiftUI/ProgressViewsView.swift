//
//  ProgressViewsView.swift
//  NRTestApp
//
//  Created by Mike Bruin on 3/12/25.
//

import SwiftUI
import NewRelic

struct ProgressViewsView: View {
    @State private var progress = 0.5
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Progress Views")
                .font(.largeTitle)
                .padding()

            // Progress Bar
            ProgressView("Loading...", value: progress, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle())
                .padding()

            // Button to simulate loading
            Button(action: {
                isLoading.toggle()
                if isLoading {
                    withAnimation {
                        progress = 0.0
                    }
                    Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                        if progress >= 1.0 {
                            timer.invalidate()
                            isLoading = false
                        } else {
                            progress += 0.1
                        }
                    }
                }
            }) {
                Text(isLoading ? "Stop Loading" : "Start Loading")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }

            // Circular Progress Indicator
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(2)
            }
        }
        .padding()
        .NRTrackView(name: "ProgressViewsView")
    }
}

struct ProgressViewsView_Previews: PreviewProvider {
    static var previews: some View {
        ProgressViewsView()
    }
}
