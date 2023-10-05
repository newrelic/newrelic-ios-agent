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
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
            Text("Hello, world!")

            Button {
                crash()
            } label: {
                Text("Test crash")
            }
        }
        .padding()
    }

    func crash() {
        // This will cause a crash to test the crash uploader, crash files will not get recorded if the debugger is running.
        NewRelic.crashNow("New Relic intentionally crashed to test Utils")
    }
}

#Preview {
    ContentView()
}
