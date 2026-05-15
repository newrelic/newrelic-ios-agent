import SwiftUI

struct SwiftUIContentView: View {
    var body: some View {
        NRConditionalMaskView(sessionReplayIdentifier: "my-secret-id") {

            NavigationView {
                List {
                    NRMobileNavigationLink(name: "MaskingView") {
                        MaskingView()
                    } label: {
                        NRConditionalMaskView(maskApplicationText: false) {
                            Text("Masking")
                        }
                    }
                    NRMobileNavigationLink(name: "ButtonsView") {
                        ButtonsView()
                    } label: {
                        Text("Buttons")
                    }
                    NRMobileNavigationLink(name: "TextFieldsView") {
                        TextFieldsView()
                    } label: {
                        Text("Text Fields")
                    }
                    NRMobileNavigationLink(name: "SimpleScrollView") {
                        SimpleScrollView()
                    } label: {
                        Text("Diff Scroll View")
                    }
                    NRMobileNavigationLink(name: "PickersView") {
                        PickersView()
                    } label: {
                        Text("Pickers")
                    }
                    NRMobileNavigationLink(name: "TogglesView") {
                        TogglesView()
                    } label: {
                        Text("Toggles")
                    }
                    NRMobileNavigationLink(name: "SlidersView") {
                        SlidersView()
                    } label: {
                        Text("Sliders")
                    }
                    NRMobileNavigationLink(name: "SteppersView") {
                        SteppersView()
                    } label: {
                        Text("Steppers")
                    }
                    NRMobileNavigationLink(name: "DatePickersView") {
                        DatePickersView()
                    } label: {
                        Text("Date Pickers")
                    }
                    NRMobileNavigationLink(name: "ProgressViewsView") {
                        ProgressViewsView()
                    } label: {
                        Text("Progress Views")
                    }
                    NRMobileNavigationLink(name: "SegmentedControlsView") {
                        SegmentedControlsView()
                    } label: {
                        Text("Segmented Controls")
                    }
                    NRMobileNavigationLink(name: "ListsView") {
                        ListsView()
                    } label: {
                        Text("Lists")
                    }
                    NRMobileNavigationLink(name: "ScrollViewsView") {
                        ScrollViewsView()
                    } label: {
                        Text("Scroll Views")
                    }
                    NRMobileNavigationLink(name: "StacksView") {
                        StacksView()
                    } label: {
                        Text("Stacks")
                    }
                    NRMobileNavigationLink(name: "GridsView") {
                        GridsView()
                    } label: {
                        Text("Grids")
                    }
                    NRMobileNavigationLink(name: "ShapesView") {
                        ShapesView()
                    } label: {
                        Text("Shapes")
                    }
                    NRMobileNavigationLink(name: "DrawingsView") {
                        DrawingsView()
                    } label: {
                        Text("Canvas Drawings")
                    }
                    NRMobileNavigationLink(name: "InfiniteImageCollectionView") {
                        InfiniteImageCollectionView()
                    } label: {
                        Text("Infinite Images")
                    }
                    NRMobileNavigationLink(name: "SocialMediaFeedView") {
                        SocialMediaFeedView()
                    } label: {
                        Text("Social Media Feed")
                    }
                    NRMobileNavigationLink(name: "AttributedTextView") {
                        AttributedTextView()
                    } label: {
                        Text("Attributed Text")
                    }
                    NRMobileNavigationLink(name: "TintedSymbolsView") {
                        TintedSymbolsView()
                    } label: {
                        Text("Tinted SF Symbols")
                    }
                    NavigationLink(destination: ModalsDemoView()) {
                        Text("Modals (Sheet / FullScreenCover / Popover)")
                    }
                    NavigationLink(destination: SwiftUITabBar()) {
                        Text("Tab Bar (NRMobileTabTracking)")
                    }
                    NavigationLink(destination: MobileViewAttributesDemoView()) {
                        Text("MobileView · Custom Attributes")
                    }
                    NavigationLink(destination: MobileViewIgnoredDemoView()) {
                        Text("MobileView · Ignored")
                    }
                    if #available(iOS 16.0, *) {
                        NRMobileNavigationLink(name: "NavigationStackView") {
                            NavigationStackView()
                        } label: {
                            Text("NavigationStack")
                        }
                    }
                }
                .navigationBarTitle("SwiftUI Elements")

            }
            .navigationViewStyle(.stack)
            .NRTrackView(name: "SwiftUIContentView")
            .NRMobileView(name: "SwiftUIContentView")
        }
    }
}

//#Preview {
//    SwiftUIContentView()
//}
