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
            List {
                NavigationLink(destination: UtilityView(viewModel: UtilityView.ViewModel())) { Text("Utilities")
                }
                NavigationLink(destination: ButtonsView()) {
                    Text("Buttons")
                }
                NavigationLink(destination: TextFieldsView()) {
                    Text("Text Fields")
                }
                NavigationLink(destination: PickersView()) {
                    Text("Pickers")
                }
                NavigationLink(destination: TogglesView()) {
                    Text("Toggles")
                }
                NavigationLink(destination: SlidersView()) {
                    Text("Sliders")
                }
                NavigationLink(destination: SteppersView()) {
                    Text("Steppers")
                }
                NavigationLink(destination: DatePickersView()) {
                    Text("Date Pickers")
                }
                NavigationLink(destination: ProgressViewsView()) {
                    Text("Progress Views")
                }
                NavigationLink(destination: SegmentedControlsView()) {
                    Text("Segmented Controls")
                }
                NavigationLink(destination: ListsView()) {
                    Text("Lists")
                }
                NavigationLink(destination: ScrollViewsView()) {
                    Text("Scroll Views")
                }
                NavigationLink(destination: StacksView()) {
                    Text("Stacks")
                }
                NavigationLink(destination: GridsView()) {
                    Text("Grids")
                }
                NavigationLink(destination: ShapesView()) {
                    Text("Shapes")
                }
            }
        }
        .navigationBarTitle("SwiftUI Elements")
        .NRTrackView(name: "ContentView")
    }
}

#Preview {
    ContentView()
}
