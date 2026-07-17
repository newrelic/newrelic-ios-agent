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
