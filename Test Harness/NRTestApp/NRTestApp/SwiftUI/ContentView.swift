import SwiftUI

struct SwiftUIContentView: View {
    var body: some View {

        NavigationView {
            List {
                NavigationLink(destination: MaskingView()) {
                    Text("Masking")
                        .nrMasked()
                    //.accessibilityIdentifier("nr-mask")
                        .id(UUID())
                    
                }
                NavigationLink(destination: ButtonsView()) {
                    Text("Buttons")
                    //.accessibilityIdentifier("nr-mask")
                        .id(UUID())
                }
                NavigationLink(destination: TextFieldsView()) {
                    Text("Text Fields")
                    //.accessibilityIdentifier("nr-mask")
                        .id(UUID())
                    
                }
                NavigationLink(destination: PickersView()) {
                    Text("Pickers")
                    //.accessibilityIdentifier("nr-mask")
                        .id(UUID())
                    
                }
                NavigationLink(destination: TogglesView()) {
                    Text("Toggles")
                    //.accessibilityIdentifier("nr-mask")
                        .id(UUID())
                    
                }
                NavigationLink(destination: SlidersView()) {
                    Text("Sliders")
                    //.accessibilityIdentifier("nr-mask")
                        .id(UUID())
                    
                }
                NavigationLink(destination: SteppersView()) {
                    Text("Steppers")
                    //.accessibilityIdentifier("nr-mask")
                        .id(UUID())
                    
                }
                NavigationLink(destination: DatePickersView()) {
                    Text("Date Pickers")
                    //.accessibilityIdentifier("nr-mask")
                        .id(UUID())
                    
                }
                NavigationLink(destination: ProgressViewsView()) {
                    Text("Progress Views")
                    //.accessibilityIdentifier("nr-mask")
                        .id(UUID())
                    
                }
                NavigationLink(destination: SegmentedControlsView()) {
                    Text("Segmented Controls")
                    //.accessibilityIdentifier("nr-mask")
                        .id(UUID())
                    
                }
                NavigationLink(destination: ListsView()) {
                    Text("Lists")
                    //.accessibilityIdentifier("nr-mask")
                        .id(UUID())
                    
                }
                NavigationLink(destination: ScrollViewsView()) {
                    Text("Scroll Views")
                    //.accessibilityIdentifier("nr-mask")
                        .id(UUID())
                    
                }
                NavigationLink(destination: StacksView()) {
                    Text("Stacks")
                    //.accessibilityIdentifier("nr-mask")
                        .id(UUID())
                    
                }
                NavigationLink(destination: GridsView()) {
                    Text("Grids")
                    //.accessibilityIdentifier("nr-mask")
                        .id(UUID())
                    
                }
                NavigationLink(destination: ShapesView()) {
                    Text("Shapes")
                    //.accessibilityIdentifier("nr-mask")
                        .id(UUID())
                    
                }
            }
            .navigationBarTitle("SwiftUI Elements")
            
        }
        .NRTrackView(name: "SwiftUIContentView")

        .onAppear {
            let _ = ViewBodyTracker.track(self)  // ← At top level view
        }
    }
}

//#Preview {
//    SwiftUIContentView()
//}
