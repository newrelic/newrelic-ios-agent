import SwiftUI

@available(iOS 14.0, *)
struct ContentView: View {
    var body: some View {
        NavigationView {
            List {
                NavigationLink(destination: ButtonsView()) {
                    Text("Buttons").sessionReplayType(.applicationText)
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
                if #available(iOS 15.0, *) {
                    NavigationLink(destination: SwiftUIViewRepresentableTestView()) {
                        Text("SwiftUI View Representable")
                    }
                }
            }
            .navigationBarTitle("SwiftUI Elements")
        }
    }
}

#Preview {
    if #available(iOS 14.0, *) {
        ContentView()
    }
}
