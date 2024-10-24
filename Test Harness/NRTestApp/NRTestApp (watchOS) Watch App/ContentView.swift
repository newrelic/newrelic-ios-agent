//
//  ContentView.swift
//  NRTestApp (watchOS) Watch App
//
//  Created by Mike Bruin on 4/29/24.
//

import SwiftUI
import NewRelic

struct ContentView: View {
    
    @State private var isTapped: UtilOption? = nil
    var viewModel = UtilViewModel()

    var body: some View {
        List(viewModel.options, id: \.title) { option in
            Text(option.title)
                .background( isTapped == option ? Color.gray.opacity(0.3) : Color.clear)
            .onTapGesture {
                option.handler()
            }
            .onLongPressGesture(minimumDuration: 0.1) { _ in
                withAnimation {
                    isTapped = option
                }
            } perform: {
                withAnimation {
                    isTapped = nil
                }
            }
        }
        .NRTrackView(name: "WatchOSContentView")
    }
}

#Preview {
    ContentView()
}
