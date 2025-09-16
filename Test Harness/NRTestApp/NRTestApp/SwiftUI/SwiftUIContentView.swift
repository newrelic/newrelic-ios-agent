//
//  ContentView.swift
//  SPMExample
//
//  Created by Chris Dillard on 9/19/23.
//

import SwiftUI
import NewRelic

@available(iOS 14.0, *)
@available(tvOS 14.0, *)

struct SwiftUIContentView: View {
    var body: some View {
        NavigationView {
            List {
                NavigationLink(destination: ButtonsView()) {
                    Text("Buttons")
#if !os(tvOS)
                        .pathLeaf()
                    .trackable()
                    .decompile()
                #endif
                }
#if !os(tvOS)

                    .trackable()
                    .decompile()
                #endif
                NavigationLink(destination: TextFieldsView()) {
                    Text("Text Fields")
#if !os(tvOS)
                        .pathLeaf()
                    .trackable()
                    .decompile()
                #endif

                }
#if !os(tvOS)

                    .trackable()
                    .decompile()
                #endif
//                NavigationLink(destination: PickersView()) {
//                    Text("Pickers")
//                }
//                NavigationLink(destination: TogglesView()) {
//                    Text("Toggles")
//                }
//                NavigationLink(destination: SlidersView()) {
//                    Text("Sliders")
//                }
//                NavigationLink(destination: SteppersView()) {
//                    Text("Steppers")
//                }
//                NavigationLink(destination: DatePickersView()) {
//                    Text("Date Pickers")
//                }
//                NavigationLink(destination: ProgressViewsView()) {
//                    Text("Progress Views")
//                }
//                NavigationLink(destination: SegmentedControlsView()) {
//                    Text("Segmented Controls")
//                }
//                NavigationLink(destination: ListsView()) {
//                    Text("Lists")
//                }
                NavigationLink(destination: ScrollViewsView()) {
                    Text("Scroll Views")
                        .pathLeaf()
                        .trackable()
                        .decompile()
                }
//                NavigationLink(destination: StacksView()) {
//                    Text("Stacks")
//                }
//                NavigationLink(destination: GridsView()) {
//                    Text("Grids")
//                }
//                NavigationLink(destination: ShapesView()) {
//                    Text("Shapes")
//                }
            }
            
#if !os(tvOS)
            .pathLeaf()
                    .trackable()
                    .decompile()
                #endif
        }
        .navigationBarTitle("SwiftUI Elements")
        .NRTrackView(name: "ContentView")
#if !os(tvOS)

                    .trackable()
                    .decompile()
                #endif

    }
}
