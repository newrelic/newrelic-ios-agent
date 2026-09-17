//
//  ContentView.swift
//  NRTestApp (watchOS) Watch App
//
//  Created by Mike Bruin on 4/29/24.
//

import SwiftUI
import NewRelic

struct ContentView: View {
    var viewModel = UtilViewModel()
    
    var body: some View {
        List(viewModel.options, id: \.title) { option in
            Text(option.title)
            .onTapGesture {
                option.handler()
            }
        }
        .NRTrackView(name: "WatchOSContentView")
    }
}

#Preview {
    ContentView()
}
