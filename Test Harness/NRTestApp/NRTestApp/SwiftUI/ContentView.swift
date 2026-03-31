import SwiftUI

struct SwiftUIContentView: View {
    var body: some View {
        NRConditionalMaskView(sessionReplayIdentifier: "my-secret-id") {
            
            NavigationView {
                List {
//                    NavigationLink(destination: NewRelicTestAppContentView()) {
//                        Text(verbatim:"NewRelicTestApp")
//                    }
                    NavigationLink(destination: MaskingView()) {
                        NRConditionalMaskView(maskApplicationText: false) {
                            Text("Masking")
                        }
                    }
                    NavigationLink(destination: ButtonsView()) {
                        Text("Buttons")
                    }
                    NavigationLink(destination: TextFieldsView()) {
                        Text("Text Fields")

                    }
                    NavigationLink(destination: SimpleScrollView()) {
                        Text("Diff Scroll View")

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
                    NavigationLink(destination: DrawingsView()) {
                        Text("Canvas Drawings")

                    }
                    NavigationLink(destination: InfiniteImageCollectionView()) {
                        Text("Infinite Images")
                    }
                    NavigationLink(destination: SocialMediaFeedView()) {
                        Text("Social Media Feed")
                    }
                    NavigationLink(destination: AttributedTextView()) {
                        Text("Attributed Text")
                    }
                    NavigationLink(destination: TintedSymbolsView()) {
                        Text("Tinted SF Symbols")
                    }
                }
                .navigationBarTitle("SwiftUI Elements")

            }
            .navigationViewStyle(.stack)
            .NRTrackView(name: "SwiftUIContentView")
        }
    }
}

//#Preview {
//    SwiftUIContentView()
//}
