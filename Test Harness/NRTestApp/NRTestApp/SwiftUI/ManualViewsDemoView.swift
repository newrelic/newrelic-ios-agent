//
//  ManualViewsDemoView.swift
//  NRTestApp
//
//  Demonstrates the manual view API — `NewRelic.setCurrentView(_:attributes:)` — and the
//  referrer (previousView) it produces on breadcrumbs and MobileView events.
//
//  Unlike the other MobileView demos, this screen intentionally does NOT use `.NRMobileView(...)`.
//  Every "view" here is declared manually by calling setCurrentView, mirroring how a React Native
//  bridge (or a native screen that automatic instrumentation names incorrectly) drives view
//  tracking. Each call closes the previous manual view (emitting its timeVisible) and opens a new
//  one, with the prior screen recorded as the `previousView` referrer.
//
//  It also exercises MobileViewTiming against a manual view: markViewTiming measures from the
//  setCurrentView call that declared the view, so timings work identically whether the current view
//  came from UIKit swizzling, a SwiftUI modifier, or this API. Tapping a timing button before any
//  screen is selected returns false — no current view means no zero point.
//
//  Requires NRFeatureFlag_ManualViews (enabled in AppDelegate).
//

import SwiftUI
import NewRelic

struct ManualViewsDemoView: View {

    private let screens = ["Home", "Product Detail", "Cart", "Checkout"]

    @State private var currentView: String = "—"
    @State private var previousView: String = "—"
    @State private var log: [String] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Manual Views & Referrer")
                    .font(.title2).bold()

                Text("Tap a screen name to call NewRelic.setCurrentView(...). Each call closes the previous manual view (emitting timeVisible) and opens the new one — the previous screen becomes the `previousView` referrer. Record a breadcrumb to see it stamped with the current/previous view.")
                    .font(.callout)

                GroupBox(label: Text("Referrer state")) {
                    VStack(alignment: .leading, spacing: 6) {
                        row("currentView", currentView)
                        row("previousView", previousView)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text("Navigate (React Native-style)").font(.headline)
                ForEach(screens, id: \.self) { name in
                    Button {
                        NewRelic.setCurrentView(name, attributes: ["source": "manual-demo"])
                        previousView = currentView
                        currentView = name
                        append("setCurrentView(\"\(name)\")")
                    } label: {
                        Text(name).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button {
                    _ = NewRelic.recordBreadcrumb("cta_tapped", attributes: ["cta": "buy-now"])
                    append("recordBreadcrumb(\"cta_tapped\") — carries currentView/previousView")
                } label: {
                    Text("Record breadcrumb here").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                // Timings attach to whichever view is current — including a manually declared one.
                // A manual view's appear time is set by setCurrentView, so markViewTiming measures
                // from the tap that declared it. Tapping this *before* choosing a screen above
                // returns false: there is no current view, so there is no zero point to measure from.
                Text("Time this manual view").font(.headline)

                Button {
                    let took = NewRelic.markViewTiming("timeToFullDisplay")
                    append("markViewTiming(\"timeToFullDisplay\") -> \(took)"
                           + (took ? " — measured from setCurrentView" : " — no current view"))
                } label: {
                    Text("markViewTiming(\"timeToFullDisplay\")").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    // Zero point is the request, not the view, so the duration is supplied.
                    let took = NewRelic.recordViewTiming("timeToFirstByte", milliseconds: 214)
                    append("recordViewTiming(\"timeToFirstByte\", 214ms) -> \(took)")
                } label: {
                    Text("recordViewTiming(\"timeToFirstByte\", 214ms)").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    // Reserved: the agent owns this series.
                    let took = NewRelic.markViewTiming("timeToInitialDisplay")
                    append("markViewTiming(\"timeToInitialDisplay\") -> \(took) — reserved name")
                } label: {
                    Text("markViewTiming(\"timeToInitialDisplay\") — reserved").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                if !log.isEmpty {
                    GroupBox(label: Text("Call log (most recent first)")) {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(log.enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .font(.system(.footnote, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Manual Views")
    }

    private func row(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key).font(.system(.footnote, design: .monospaced)).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.system(.footnote, design: .monospaced)).bold()
        }
    }

    private func append(_ line: String) {
        log.insert(line, at: 0)
        if log.count > 12 { log.removeLast() }
    }
}
