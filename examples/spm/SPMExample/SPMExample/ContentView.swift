//
//  ContentView.swift
//  SPMExample
//
//  Created by Chris Dillard on 9/19/23.
//

import SwiftUI
import NewRelic

struct ContentView: View {
    var body: some View {
        NavigationView {
            VStack {
                Image(systemName: "globe")
                    .imageScale(.large)
                Text("Hello, world!")
            }
            .navigationBarTitle("SPMExample")
            .toolbar {
                HStack {
                    NavigationLink(destination: UtilityView(viewModel: UtilityView.ViewModel())) { Text("Utilities") }
                }
            }
        }
        .NRTrackView(name: "ContentView")
    }
}

#Preview {
    ContentView()
}
