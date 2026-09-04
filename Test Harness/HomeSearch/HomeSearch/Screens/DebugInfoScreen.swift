//
//  DebugInfoScreen.swift
//  HomeSearch
//
//  The one screen in this app that opts out of view tracking, via `.NRMobileView(ignored: true)`.
//
//  It exists so the opt-out can be tested by absence: navigate here, then confirm no MobileView
//  event named "Debug Info" was ever emitted. A screen that reports nothing is only convincing as a
//  test if it is genuinely reachable, which is why it has a real row in Profile.
//
//  A second thing to watch: because this view never becomes current, the view *before* it should
//  still be current while it is on screen. The next event recorded from here should therefore name
//  Profile, not Debug Info.
//

import SwiftUI
import NewRelic

struct DebugInfoScreen: View {

    @Environment(ListingStore.self) private var store
    @Environment(SavedHomesStore.self) private var savedHomes

    @State private var lastBreadcrumb: String?

    var body: some View {
        List {
            Section {
                Text("This screen reports `ignored: true`, so it should never appear in MobileView data. Anything recorded from here should still be attributed to the previous view.")
                    .font(.footnote)
            }

            Section("Agent") {
                LabeledContent("Mode", value: NewRelicConfig.mode.rawValue)
                LabeledContent("Collector", value: collectorDescription)
                LabeledContent("Automatic views", value: "enabled")
                LabeledContent("Manual views", value: "enabled")
            }

            Section("Local servers") {
                LabeledContent("Listings", value: ListingStubServer.baseURL)
                if NewRelicConfig.mode == .capture {
                    LabeledContent("Collector stub", value: NRCollectorStub.address)
                    LabeledContent("MobileView events seen",
                                   value: "\(NRCollectorStub.shared.mobileViewEvents.count)")
                }
            }

            Section("App state") {
                LabeledContent("Listings loaded", value: "\(store.listings.count)")
                LabeledContent("Saved", value: "\(savedHomes.savedIDs.count)")
                LabeledContent("Recently viewed", value: "\(savedHomes.recentlyViewedIDs.count)")
            }

            Section("Expected view inventory") {
                ForEach(ViewName.allExpectedNames(
                    threadCorrespondents: store.threads.map(\.correspondent)
                ), id: \.self) { name in
                    Text(name)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(name == ViewName.debugInfo.rawValue ? .secondary : .primary)
                }
            }

            Section {
                Button("Record a breadcrumb from this screen") {
                    NewRelic.recordBreadcrumb("debug_probe", attributes: ["source": "debug-info"])
                    lastBreadcrumb = Date().formatted(date: .omitted, time: .standard)
                }
                if let lastBreadcrumb {
                    Text("Recorded at \(lastBreadcrumb) — check which view it names.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if NewRelicConfig.mode == .capture {
                    Button("Print MobileView summary to console") {
                        NRCollectorStub.shared.printSummary()
                    }
                }
            } footer: {
                Text("The breadcrumb above should carry Profile as its current view, since Debug Info never becomes current.")
            }
        }
        .navigationTitle("Debug info")
        .navigationBarTitleDisplayMode(.inline)
        // The opt-out. Nothing here should reach the data.
        .NRMobileView(name: ViewName.debugInfo.rawValue, ignored: true)
    }

    private var collectorDescription: String {
        NewRelicConfig.mode == .capture ? NRCollectorStub.address : "collector.newrelic.com"
    }
}
