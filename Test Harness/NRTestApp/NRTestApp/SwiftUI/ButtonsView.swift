//
//  ButtonsView.swift
//  NRTestApp
//
//  Created by Mike Bruin on 3/12/25.
//

import SwiftUI
import NewRelic

struct ButtonsView: View {
    @State private var toggleState = false
    @State private var buttonPressCount = 0

    var body: some View {

        VStack(spacing: 20) {
            Text("Buttons Demo")
                .font(.largeTitle)

            // Standard Button
            Button(action: {
                buttonPressCount += 1
            }) {
                Text("Press Me")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }

            Text("Button pressed \(buttonPressCount) times")

            // Toggle Button
            Button(action: {
                toggleState.toggle()
            }) {
                Text(toggleState ? "Toggle is ON" : "Toggle is OFF")
                    .padding()
                    .background(toggleState ? Color.green : Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }

            // Custom Styled Button
            Button(action: {
                print("Custom Styled Button Pressed")
            }) {
                Text("Custom Styled Button")
                    .fontWeight(.bold)
                    .padding()
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(radius: 5)
            }

            // Button with Image
            Button(action: {
                print("Button with Image Pressed")
            }) {
                HStack {
                    Image(systemName: "star.fill")
                    Text("Star Button")
                }
                .padding()
                .background(Color.yellow)
                .foregroundColor(.black)
                .cornerRadius(8)
            }
        }
        .padding()
        .NRTrackView(name: "ButtonsView")
        .onAppear {
            let _ = ViewBodyTracker.track(self)  // ← At top level view
        }
    }
}

struct ButtonsView_Previews: PreviewProvider {
    static var previews: some View {
        ButtonsView()
    }
}
