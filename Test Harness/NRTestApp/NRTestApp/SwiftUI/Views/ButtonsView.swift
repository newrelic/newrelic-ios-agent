//
//  ButtonsView.swift
//  NRTestApp
//
//  Created by Mike Bruin on 3/12/25.
//

import SwiftUI
import NewRelic

@available(iOS 14.0, *)
@available(tvOS 14.0, *)
struct ButtonsView: View {
    @State private var toggleState = false
    @State private var buttonPressCount = 0

    var body: some View {
        VStack(spacing: 20) {
            Text("Buttons Demo")
                .pathLeaf()
                .font(.largeTitle)
#if !os(tvOS)

                    .trackable()
                    .decompile()
                #endif
            // Standard Button
            Button(action: {
                buttonPressCount += 1
            }) {
                Text("Press Me")
                    .pathLeaf()
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
#if !os(tvOS)

                    .trackable()
                    .decompile()
                #endif
            }
            
#if !os(tvOS)
            .pathLeaf()
                    .trackable()
                    .decompile()
                #endif

            Text("Button pressed \(buttonPressCount) times")
#if !os(tvOS)
                .pathLeaf()

                    .trackable()
                    .decompile()
                #endif

            // Toggle Button
            Button(action: {
                toggleState.toggle()
            }) {
                Text(toggleState ? "Toggle is ON" : "Toggle is OFF")
                    .pathLeaf()
                    .padding()
                    .background(toggleState ? Color.green : Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
#if !os(tvOS)

                    .trackable()
                    .decompile()
                #endif
            }
#if !os(tvOS)
            .pathLeaf()
                    .trackable()
                    .decompile()
                #endif

            // Custom Styled Button
            Button(action: {
                print("Custom Styled Button Pressed")
            }) {
                Text("Custom Styled Button")
                    .pathLeaf()
                    //.fontWeight(.bold)
                    .padding()
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(radius: 5)
#if !os(tvOS)
                    .trackable()
                    .decompile()
                #endif
            }
#if !os(tvOS)
            .pathLeaf()

                    .trackable()
                    .decompile()
                #endif

            // Button with Image
            Button(action: {
                print("Button with Image Pressed")
            }) {
                HStack {
                    Image(systemName: "star.fill")
                    Text("Star Button")
                        .pathLeaf()

                }
                .padding()
                .background(Color.yellow)
                .foregroundColor(.black)
                .cornerRadius(8)
#if !os(tvOS)

                    .trackable()
                    .decompile()
                #endif
            }
#if !os(tvOS)
            .pathLeaf()

                    .trackable()
                    .decompile()
                #endif
        }
        .padding()
        .NRTrackView(name: "ButtonsView")
#if !os(tvOS)

                    .trackable()
                    .decompile()
                #endif
    }
}
