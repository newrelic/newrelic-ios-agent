//
//  StacksView.swift
//  NRTestApp
//
//  Created by Mike Bruin on 3/12/25.
//

import SwiftUI
import NewRelic

struct StacksView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("VStack Example")
                    .font(.largeTitle)
                    .padding()
                
                VStack {
                    Text("Item 1")
                    Text("Item 2")
                    Text("Item 3")
                }
                .padding()
                .background(Color.blue.opacity(0.3))
                .cornerRadius(10)
                
                Spacer()
                
                Text("HStack Example")
                    .font(.largeTitle)
                    .padding()
                
                HStack {
                    Text("Item A")
                    Text("Item B")
                    Text("Item C")
                }
                .padding()
                .background(Color.green.opacity(0.3))
                .cornerRadius(10)
                
                Spacer()
                
                Text("ZStack Example")
                    .font(.largeTitle)
                    .padding()
                
                ZStack {
                    Rectangle()
                        .fill(Color.red.opacity(0.3))
                        .frame(width: 200, height: 200)
                    Text("Overlay Text")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .padding()
            }
#if !os(tvOS)
            .navigationBarTitle("Stacks Example", displayMode: .inline)
#endif
        }
        .NRTrackView(name: "StacksView")
    }
}
