//
//  ViewsAndInteractionsDemoView.swift
//  NRTestApp
//
//  Exercises `.NRMobileView(startsInteraction: true)`.
//
//  A pure SwiftUI screen has no UIViewController, so the method profiler never starts an interaction
//  for it — there is nothing for its MobileView events to correlate to. Opting in makes the modifier
//  open an interaction named after the view, so the screen gets code-level tracing and both event
//  types share an `interactionId`.
//
//  The interaction represents the screen *load*: it completes on the trace machine's quiescence
//  timeout while this view is still current, not when the view disappears. Watch `interactionId`
//  appear on entry and clear about half a second after the traced work stops.
//
//  Requires NRFeatureFlag_AutomaticMobileViews (enabled in AppDelegate).
//

import SwiftUI
import NewRelic

struct ViewsAndInteractionsDemoView: View {

    @State private var interactionAttributes: [String: Any] = [:]
    @State private var viewAttributes: [String: Any] = [:]
    @State private var log: [String] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Views × Interactions (SwiftUI)")
                    .font(.title2).bold()

                Text("This view is annotated `.NRMobileView(name: \"Views & Interactions (SwiftUI)\", startsInteraction: true)`. Without that opt-in a SwiftUI screen produces MobileView events with no interaction to join to.")
                    .font(.callout)

                GroupBox(label: Text("On MobileView events (forward)")) {
                    readout(interactionAttributes)
                }

                GroupBox(label: Text("On the interaction event at completion (reverse)")) {
                    readout(viewAttributes)
                }

                Button {
                    doTracedWork()
                    append("traced work (JSON x25 + 1 request)")
                } label: {
                    Text("Do traced work").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    _ = NewRelic.recordBreadcrumb("swiftui_cta_tapped", attributes: ["cta": "buy-now"])
                    append("recordBreadcrumb — carries currentView/previousView")
                } label: {
                    Text("Record breadcrumb").frame(maxWidth: .infinity)
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
        .navigationTitle("Views × Interactions")
        .NRMobileView(name: "Views & Interactions (SwiftUI)", startsInteraction: true)
        .onAppear(perform: refresh)
        .task {
            // Poll while the screen is up so the id can be seen appearing and then clearing when the
            // interaction completes. Cancelled automatically when the view goes away.
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 250_000_000)
                refresh()
            }
        }
    }

    private func readout(_ attributes: [String: Any]) -> some View {
        Text(MobileViewCorrelationProbe.describe(attributes))
            .font(.system(.footnote, design: .monospaced))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func refresh() {
        interactionAttributes = MobileViewCorrelationProbe.interactionAttributes()
        viewAttributes = MobileViewCorrelationProbe.viewAttributes()
    }

    /// Work through instrumented classes plus a request, so the open interaction accumulates nodes
    /// and clears activity_trace_min_utilization.
    private func doTracedWork() {
        for index in 0..<25 {
            let payload: [String: Any] = ["index": index, "screen": "views-and-interactions-swiftui"]
            if let data = try? JSONSerialization.data(withJSONObject: payload) {
                _ = try? JSONSerialization.jsonObject(with: data)
            }
        }
        guard let url = URL(string: "https://www.newrelic.com") else { return }
        URLSession.shared.dataTask(with: url) { _, _, _ in }.resume()
    }

    private func append(_ line: String) {
        log.insert(line, at: 0)
        if log.count > 8 { log.removeLast() }
        refresh()
    }
}
