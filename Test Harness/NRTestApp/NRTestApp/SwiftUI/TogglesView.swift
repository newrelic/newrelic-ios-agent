//
//  TogglesView.swift
//  NRTestApp
//
//  Created by Mike Bruin on 3/12/25.
//

import SwiftUI
import NewRelic

struct TogglesView: View {
    @State private var isToggleOn: Bool = false
    @State private var isAnotherToggleOn: Bool = true
    @State private var customToggle1: Bool = true
    @State private var customToggle2: Bool = false
    @State private var customToggle3: Bool = true
    @State private var customToggle4: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Toggle Examples")
                    .font(.largeTitle)
                    .padding(.top)

                Divider()

                // Standard Toggles
                VStack(alignment: .leading, spacing: 15) {
                    Text("Standard Toggles")
                        .font(.headline)
                        .padding(.horizontal)

                    Toggle("Toggle is \(isToggleOn ? "On" : "Off")", isOn: $isToggleOn)
                        .padding(.horizontal)

                    Toggle("Another Toggle is \(isAnotherToggleOn ? "On" : "Off")", isOn: $isAnotherToggleOn)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                        .padding(.horizontal)
                }

                Divider()

                // Custom Toggles
                VStack(alignment: .leading, spacing: 15) {
                    Text("Custom SwiftUI Toggles")
                        .font(.headline)
                        .padding(.horizontal)

                    Toggle("Custom Style", isOn: $customToggle1)
                        .toggleStyle(CustomToggleStyle())
                        .padding(.horizontal)

                    Toggle("Pill-Shaped Thumb", isOn: $customToggle2)
                        .toggleStyle(PillToggleStyle(
                            onColor: Color(red: 144/255, green: 202/255, blue: 119/255),
                            offColor: .gray,
                            thumbColor: .white
                        ))
                        .padding(.horizontal)

                    Toggle("Square Toggle", isOn: $customToggle3)
                        .toggleStyle(SquareToggleStyle(
                            onColor: .blue,
                            offColor: Color(.systemGray3),
                            thumbColor: .white
                        ))
                        .padding(.horizontal)

                    Toggle("Colorful Gradient", isOn: $customToggle4)
                        .toggleStyle(ColorfulToggleStyle())
                        .padding(.horizontal)
                }

                Divider()

                // State Display
                VStack(alignment: .leading, spacing: 10) {
                    Text("States")
                        .font(.headline)
                        .padding(.horizontal)

                    Text("Standard: \(isToggleOn ? "On ✓" : "Off")")
                        .padding(.horizontal)
                    Text("Blue: \(isAnotherToggleOn ? "On ✓" : "Off")")
                        .padding(.horizontal)
                    Text("Custom: \(customToggle1 ? "On ✓" : "Off") [Generic View]")
                        .padding(.horizontal)
                    Text("Pill: \(customToggle2 ? "On ✓" : "Off") [Generic View]")
                        .padding(.horizontal)
                    Text("Square: \(customToggle3 ? "On ✓" : "Off") [Generic View]")
                        .padding(.horizontal)
                    Text("Gradient: \(customToggle4 ? "On ✓" : "Off") [Generic View]")
                        .padding(.horizontal)
                }
                .padding(.bottom)
            }
        }
        .NRTrackView(name: "TogglesView")
        .NRMobileView(name: "TogglesView")
    }
}

struct TogglesView_Previews: PreviewProvider {
    static var previews: some View {
        TogglesView()
    }
}
