//
//  AutoInstrumentedDemoView.swift
//  NRTestApp
//
//  Exercises AUTOMATIC SwiftUI MobileView collection: every screen below is deliberately free
//  of any New Relic API. No .NRMobileView(...), no NRMobileNavigationLink, no NRMobileSheet,
//  no .NRTrackView. If MobileView / MobileViewTiming events appear for these screens, they came
//  from SwiftUIScreenResolver resolving the host's content type at viewDidAppear: time.
//
//  Enable with:
//      NewRelic.enableFeatures([.NRFeatureFlag_AutomaticSwiftUIViews])
//  (AutomaticMobileViews must also be on; it is on by default.)
//
//  Each screen covers one of the presentation idioms a runtime probe found erases its content
//  type in the hosting controller's class name, so each is a different test of the resolver:
//
//    AutoPushedDetailScreen      NavigationView push       UIHostingController<RootView>
//    AutoStackDestinationScreen  navigationDestination     NavigationStackHostingController<AnyView>
//    AutoSheetScreen             .sheet                    PresentationHostingController<AnyView>
//    AutoFirstTabScreen/Second   TabView tab               TabHostingController (no generic param)
//
//  Expected viewName for each is the struct's own name, e.g. "AutoSheetScreen".
//
//  Copyright © 2026 New Relic. All rights reserved.
//

import SwiftUI

struct AutoInstrumentedDemoView: View {

    @State private var showSheet = false

    var body: some View {
        List {
            Section(header: Text("No New Relic API on any screen here")) {
                Text("Navigate below. Each destination should produce MobileView "
                     + "appear/disappear events named after its own type.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            // Plain NavigationLink: the host is UIHostingController<RootView>, so the name can
            // only come from reflecting the content.
            Section(header: Text("NavigationView push")) {
                NavigationLink(destination: AutoPushedDetailScreen()) {
                    Text("Push AutoPushedDetailScreen")
                }
            }

            // Modal: arrives as a presented controller rather than a child, which is the case
            // isNavigationParticipating checks via presentingViewController.
            Section(header: Text("Sheet")) {
                Button("Present AutoSheetScreen") { showSheet = true }
            }

            // A screen whose content is only SwiftUI primitives. Per the "emit nothing" rule this
            // one should produce NO MobileView event -- it is the negative control, and seeing an
            // event for it means the resolver is naming something it should have rejected.
            Section(header: Text("Negative control")) {
                NavigationLink(destination: Text("no app type here, expect no MobileView")) {
                    Text("Push a bare Text (expect NO event)")
                }
            }

            if #available(iOS 16.0, *) {
                Section(header: Text("NavigationStack + navigationDestination")) {
                    NavigationLink(destination: AutoStackContainerScreen()) {
                        Text("Push AutoStackContainerScreen")
                    }
                }
            }

            Section(header: Text("TabView")) {
                NavigationLink(destination: AutoTabsScreen()) {
                    Text("Push AutoTabsScreen")
                }
            }
        }
        .navigationBarTitle("Auto SwiftUI Views")
        .sheet(isPresented: $showSheet) {
            AutoSheetScreen()
        }
    }
}

// MARK: - Destinations

struct AutoPushedDetailScreen: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("AutoPushedDetailScreen")
                .font(.headline)
            Text("Expect viewName = AutoPushedDetailScreen, uiFramework = SwiftUI.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding()
        .navigationBarTitle("Pushed")
    }
}

struct AutoSheetScreen: View {
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        VStack(spacing: 16) {
            Text("AutoSheetScreen")
                .font(.headline)
            Text("Presented modally, so the host is a PresentationHostingController<AnyView>.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Button("Dismiss") { presentationMode.wrappedValue.dismiss() }
        }
        .padding()
    }
}

// MARK: - NavigationStack (iOS 16+)

@available(iOS 16.0, *)
struct AutoStackContainerScreen: View {
    var body: some View {
        NavigationStack {
            List {
                // Value-based push: the destination resolves through navigationDestination, and
                // the resulting host erases its content to AnyView.
                NavigationLink(value: "alpha") { Text("Push AutoStackDestinationScreen") }
            }
            .navigationDestination(for: String.self) { value in
                AutoStackDestinationScreen(token: value)
            }
            .navigationTitle("Auto Stack")
        }
    }
}

@available(iOS 16.0, *)
struct AutoStackDestinationScreen: View {
    let token: String

    var body: some View {
        VStack(spacing: 12) {
            Text("AutoStackDestinationScreen")
                .font(.headline)
            Text("token: \(token)")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

// MARK: - TabView
//
// The probe found all tab hosts are constructed eagerly -- selecting a tab creates no new
// hosting controller, it only flips visibility -- so these two tabs also check that a tab
// switch still produces appear/disappear pairs, and that loadTime is withheld rather than
// reported as the minutes-long interval since the tab was built.

struct AutoTabsScreen: View {
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            AutoFirstTabScreen()
                .tabItem { Label("First", systemImage: "1.circle") }
                .tag(0)
            AutoSecondTabScreen()
                .tabItem { Label("Second", systemImage: "2.circle") }
                .tag(1)
        }
    }
}

struct AutoFirstTabScreen: View {
    var body: some View {
        Text("AutoFirstTabScreen").font(.headline)
    }
}

struct AutoSecondTabScreen: View {
    var body: some View {
        Text("AutoSecondTabScreen").font(.headline)
    }
}
