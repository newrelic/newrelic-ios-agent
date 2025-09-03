//
//  TogglesView.swift
//  NRTestApp
//
//  Created by Mike Bruin on 3/12/25.
//

import SwiftUI
import NewRelic

@available(iOS 14.0, *)
struct TogglesView: View {
    @State private var isToggleOn: Bool = false
    @State private var isAnotherToggleOn: Bool = true

    var body: some View {
        VStack(spacing: 20) {
            Text("Toggle Example")
                .font(.largeTitle)

            Toggle("Toggle is \(isToggleOn ? "On" : "Off")", isOn: $isToggleOn)
                .padding()

            Toggle("Another Toggle is \(isAnotherToggleOn ? "On" : "Off")", isOn: $isAnotherToggleOn)
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                .padding()

            Text("Toggle State: \(isToggleOn ? "On" : "Off")")
            Text("Another Toggle State: \(isAnotherToggleOn ? "On" : "Off")")
        }
        .padding()
        .NRTrackView(name: "TogglesView")
    }
}
