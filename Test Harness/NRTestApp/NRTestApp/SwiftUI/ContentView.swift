import SwiftUI

struct SwiftUIContentView: View {
    var body: some View {
        NRConditionalMaskView(sessionReplayIdentifier: "my-secret-id") {
            
            NavigationView {
                List {
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
                    NavigationLink(destination: GeometryReaderDemoView()) {
                        Text("GeometryReader")
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
                    if #available(iOS 16.0, *) {

                        NavigationLink(destination: NavigationStackView()) {
                            Text("NavigationStack")
                        }
                        NavigationLink(destination: NavigationDestinationDemoView()) {
                            Text("NavigationDestination (MSR)")
                        }
                    }
                    NavigationLink(destination: ObservationTableView()) {
                        Text("Observation (@ObservedObject)")
                    }
                    NavigationLink(destination: EnvironmentObjectDemoView()) {
                        Text("@EnvironmentObject")
                    }
                    NavigationLink(destination: AppStorageDemoView()) {
                        Text("@AppStorage / @SceneStorage")
                    }
                    NavigationLink(destination: FocusStateDemoView()) {
                        Text("@FocusState")
                    }
                    NavigationLink(destination: GestureStateDemoView()) {
                        Text("@GestureState")
                    }
                    NavigationLink(destination: CombinePublisherDemoView()) {
                        Text("Combine Publishers")
                    }
                    NavigationLink(destination: BindingChainParentView()) {
                        Text("@Binding Deep Chain")
                    }
                    NavigationLink(destination: CustomBindingDemoView()) {
                        Text("Custom Binding(get:set:)")
                    }
                    NavigationLink(destination: ManualPublishDemoView()) {
                        Text("objectWillChange.send()")
                    }
                    NavigationLink(destination: AsyncTaskStateDemoView()) {
                        Text("task(id:) Async State")
                    }
                    NavigationLink(destination: StateObjectVsObservedDemoView()) {
                        Text("@StateObject vs @ObservedObject Lifetime")
                    }
                    if #available(iOS 16.0, *) {
                        
                        NavigationLink(destination: WindowGroupDemoView()) {
                            Text("WindowGroup Elements")
                        }
                    }
                    if #available(iOS 17.0, *) {
                        NavigationLink(destination: BindableDemoView()) {
                            Text("@Bindable (iOS 17+)")
                        }
                        NavigationLink(destination: EnvironmentObservableDemoView()) {
                            Text("@Environment(Model.self) (iOS 17+)")
                        }
                        NavigationLink(destination: NestedObservableDemoView()) {
                            Text("Nested @Observable (iOS 17+)")
                        }
                    }
                    if #available(iOS 16.0, *) {
                        
                        NavigationLink(destination: AnimationTransitionDemoView()) {
                            Text("Animations & Transitions")
                        }
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
