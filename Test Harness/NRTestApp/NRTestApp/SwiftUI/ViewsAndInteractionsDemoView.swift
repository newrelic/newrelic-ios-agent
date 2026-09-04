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
//  Each section of the screen also reports as its own MobileView (component: true,
//  componentOf: "Views & Interactions (SwiftUI)") on the default `startsInteraction: false`, so the
//  one interaction this screen opens carries a MobileView row per section in its breakdown rather
//  than a single row naming the screen.
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
                intro.NRMobileView(name: Component.intro.rawValue,
                                   attributes: Component.attributes)

                forwardReadout.NRMobileView(name: Component.forwardReadout.rawValue,
                                            attributes: Component.attributes)

                reverseReadout.NRMobileView(name: Component.reverseReadout.rawValue,
                                            attributes: Component.attributes)

                actions.NRMobileView(name: Component.actions.rawValue,
                                     attributes: Component.attributes)

                if !log.isEmpty {
                    // Appears only once something has been logged, so its component MobileView is
                    // emitted mid-visit — after the screen's interaction has usually completed. Its
                    // load segment therefore lands on whatever interaction is open at that moment,
                    // or nowhere. The event still carries componentOf, so a component's absence from
                    // the screen's breakdown does not mean it was never shown.
                    callLog.NRMobileView(name: Component.callLog.rawValue,
                                         attributes: Component.attributes)
                }
            }
            .padding()
        }
        .navigationTitle("Views × Interactions")
        .NRMobileView(name: Self.screenName)
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

    // MARK: - Component-level views

    private static let screenName = "Views & Interactions (SwiftUI)"

    /// The sections of this screen, each tracked as a view in its own right.
    ///
    /// These take the default `startsInteraction: false`, so they open no trace of their own — each
    /// records a load segment against whatever interaction is already open, which on this screen is
    /// the one the screen itself opens with `startsInteraction: true`. That is what puts several
    /// `Method/MobileView/<component>` rows into a *single* interaction's breakdown table, instead
    /// of the one row naming the screen.
    ///
    /// Names are dot-separated rather than slash-separated on purpose: `/` is one of the characters
    /// `+[NewRelicInternalUtils cleanseStringForCollector:]` rewrites to `_`, and it is also the
    /// separator in the `Method/<class>/<method>` metric grammar these names land in.
    private enum Component: String {
        case intro          = "ViewsAndInteractions.Intro"
        case forwardReadout = "ViewsAndInteractions.ForwardReadout"
        case reverseReadout = "ViewsAndInteractions.ReverseReadout"
        case actions        = "ViewsAndInteractions.Actions"
        case callLog        = "ViewsAndInteractions.CallLog"

        /// Marks the emitted MobileView events as components rather than screens. `viewName` alone
        /// cannot tell them apart — to the agent a component is just another view — so dashboards
        /// need an attribute to facet on.
        static let attributes: [String: Any] = [
            "component": true,
            "componentOf": ViewsAndInteractionsDemoView.screenName,
        ]
    }

    // MARK: - Sections

    private var intro: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Views × Interactions (SwiftUI)")
                .font(.title2).bold()

            Text("This view is annotated `.NRMobileView(name: \"Views & Interactions (SwiftUI)\", startsInteraction: true)`. Without that opt-in a SwiftUI screen produces MobileView events with no interaction to join to.")
                .font(.callout)
        }
    }

    private var forwardReadout: some View {
        GroupBox(label: Text("On MobileView events (forward)")) {
            readout(interactionAttributes)
        }
    }

    private var reverseReadout: some View {
        GroupBox(label: Text("On the interaction event at completion (reverse)")) {
            readout(viewAttributes)
        }
    }

    private var actions: some View {
        VStack(spacing: 16) {
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
        }
    }

    private var callLog: some View {
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
