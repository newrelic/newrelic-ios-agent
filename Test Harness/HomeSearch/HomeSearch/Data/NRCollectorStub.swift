//
//  NRCollectorStub.swift
//  HomeSearch
//
//  A local stand-in for the New Relic collector, so harvest payloads can be read directly instead
//  of waiting on a round trip to a real account.
//
//  Point the agent at this in capture mode (see NewRelicConfig) and every harvest lands here. The
//  interesting part is `handleDataHarvest(_:)`: the data harvest body is a JSON array whose element
//  at index 9 is `analyticsEvents`, so we decode that and log a single timeline of the three event
//  types that describe a screen's life — MobileView, interactions (eventType "Mobile" with
//  category "Interaction"), and breadcrumbs — in the order they happened.
//
//  Interactions are read from index 9 rather than index 6 on purpose. Index 6 carries the
//  code-level node trees, which the collector's `at_capture` cap limits; the interaction's
//  correlation attributes (viewName, viewInstanceId, interactionId) ride on an analytics event
//  emitted from -completeActivityTrace..., which the cap does not gate.
//
//  This is what settles the open schema questions in the MobileView DACI — whether an appearance
//  produces one event or two, and whether loadTime/timeVisible ship as seconds or milliseconds —
//  because it shows what actually goes on the wire rather than what the headers claim.
//
//  Port 8080, and it has to be exactly that. NRMAAgentConfiguration only turns TLS off when the
//  collector address is the literal string "localhost:8080" (or when a UITesting environment
//  variable is set) — see NRMAAgentConfiguration.m. Any other host, including 127.0.0.1:8080, makes
//  the agent speak HTTPS and the connect fails with a TLS error against a plain HTTP stub.
//
//  Consequence worth knowing: this shares 8080 with NRTestApp's NRCaptureServer, so the two apps
//  cannot both be in capture mode at once. The listing stub sits on 8082 to stay clear of both.
//

import Foundation

final class NRCollectorStub {

    static let shared = NRCollectorStub()

    /// Fixed by the agent's TLS opt-out, which matches on the address string exactly.
    static let port: UInt16 = 8080
    static let address = "localhost:8080"

    private let server = HttpServer()
    private var isRunning = false

    /// Every MobileView event seen so far, oldest first, across all harvests.
    private(set) var mobileViewEvents: [[String: Any]] = []
    /// Every interaction event seen so far (eventType "Mobile", category "Interaction").
    private(set) var interactionEvents: [[String: Any]] = []
    private let lock = NSLock()

    private init() {}

    func start() {
        guard !isRunning else { return }

        // The connect response has to be well formed enough for the agent to accept it and start
        // harvesting; these are the fields it reads.
        let connectResponse: [String: Any] = [
            "server_timestamp": 1_656_525_980,
            "data_report_period": 15,          // harvest often so events show up promptly
            "report_max_transaction_count": 1000,
            "report_max_transaction_age": 600,
            "collect_network_errors": true,
            "error_limit": 50,
            "response_body_limit": 2048,
            "stack_trace_limit": 100,
            "at_capture": [50, []],
            "data_token": [111_111_111, 222_222_222],
            "cross_process_id": "AAAAAAAAAAAAAAAAAAAAAA==",
            "encoding_key": "0000000000000000000000000000000000000000",
            "account_id": "1",
            "application_id": "1",
            "entity_guid": "AAAAAAAAAAAAAAAAAAAAAA==",
            "configuration": [:]
        ]

        server.POST["/mobile/:version/connect"] = { _ in
            appLog("[HomeSearch/collector] connect")
            return .ok(.json(connectResponse as AnyObject))
        }

        server.POST["/mobile/:version/data"] = { [weak self] request in
            self?.handleDataHarvest(Data(request.body))
            return .ok(.json([:] as AnyObject))
        }

        // Everything else the agent may post: swallow it so nothing retries in a loop.
        for path in ["/mobile/f", "/mobile/blobs", "/mobile/errors", "/mobile/logs"] {
            server.POST[path] = { _ in .ok(.json([:] as AnyObject)) }
        }
        server.POST["/:path"] = { _ in .ok(.json([:] as AnyObject)) }

        do {
            try server.start(Self.port, forceIPv4: true)
            isRunning = true
            appLog("[HomeSearch/collector] listening on \(Self.address)")
        } catch {
            appLog("[HomeSearch/collector] failed to start: \(error)")
        }
    }

    func stop() {
        server.stop()
        isRunning = false
    }

    // MARK: - Harvest decoding

    private func handleDataHarvest(_ body: Data) {
        guard let root = try? JSONSerialization.jsonObject(with: body) as? [Any] else {
            appLog("[HomeSearch/collector] data harvest was not a JSON array (\(body.count) bytes)")
            return
        }

        // Index 9 of the data harvest array is analyticsEvents; index 6 is activityTraces.
        //
        // Interactions arrive here rather than at index 6: completeActivityTrace: emits an analytics
        // event (eventType "Mobile", category "Interaction") carrying the viewName / viewInstanceId /
        // interactionId correlation, and that call is not gated by the at_capture cap. Index 6 holds
        // the code-level node trees, which the cap does apply to — so the count is printed for
        // context but the correlation story is told entirely by index 9.
        let events = (root.indices.contains(9) ? root[9] as? [Any] : nil)?
            .compactMap { $0 as? [String: Any] } ?? []
        let traceCount = ((root.indices.contains(6) ? root[6] as? [Any] : nil) ?? []).count

        func isInteraction(_ event: [String: Any]) -> Bool {
            event["eventType"] as? String == "Mobile" && event["category"] as? String == "Interaction"
        }

        let views        = events.filter { $0["eventType"] as? String == "MobileView" }
        let interactions = events.filter(isInteraction)
        let crumbs       = events.filter { $0["eventType"] as? String == "MobileBreadcrumb" }

        let others = Dictionary(grouping: events.filter {
            $0["eventType"] as? String != "MobileView"
                && $0["eventType"] as? String != "MobileBreadcrumb"
                && !isInteraction($0)
        }.compactMap { $0["eventType"] as? String }, by: { $0 }).mapValues(\.count)

        var summary = "\(events.count) event(s): \(views.count) MobileView, \(interactions.count) Interaction, \(crumbs.count) breadcrumb"
        if !others.isEmpty {
            summary += ", " + others.sorted(by: { $0.key < $1.key }).map { "\($0.value) \($0.key)" }.joined(separator: ", ")
        }
        summary += " · \(traceCount) activity trace(s) at index 6"

        appLog("""

        ┌─ harvest ─────────────────────────────────────────────────────────────────
        │ \(summary)
        """)

        // The three types are printed as one timeline: a load-more interaction is only legible next
        // to the breadcrumbs that bracket it and the view event it correlates to.
        let timeline = (views + interactions + crumbs).sorted {
            (($0["timestamp"] as? NSNumber)?.doubleValue ?? 0) <
            (($1["timestamp"] as? NSNumber)?.doubleValue ?? 0)
        }

        guard !timeline.isEmpty else {
            appLog("└───────────────────────────────────────────────────────────────────────────\n")
            return
        }

        lock.lock()
        mobileViewEvents.append(contentsOf: views)
        interactionEvents.append(contentsOf: interactions)
        lock.unlock()

        for event in timeline {
            appLog("│ " + Self.describe(event))
        }
        appLog("└───────────────────────────────────────────────────────────────────────────\n")
    }

    private static func describe(_ event: [String: Any]) -> String {
        switch event["eventType"] as? String {
        case "MobileView":       return describeView(event)
        case "MobileBreadcrumb": return describeBreadcrumb(event)
        default:                 return describeInteraction(event)
        }
    }

    private static func value(_ event: [String: Any], _ key: String) -> String {
        if let value = event[key] as? String { return value }
        if let value = event[key] as? NSNumber { return value.stringValue }
        return "—"
    }

    private static func describeView(_ event: [String: Any]) -> String {
        // `appeared` distinguishes the appear event from the disappear event. If both show up for a
        // single visit, that is the double-count the DACI flags.
        let appeared = (event["appeared"] as? NSNumber)?.boolValue
        let phase = appeared.map { $0 ? "appear   " : "disappear" } ?? "?        "

        var line = "\(phase) \(value(event, "viewName").padded(to: 28))"
        line += " prev=\(value(event, "previousView").padded(to: 22))"
        line += " inst=\(String(value(event, "viewInstanceId").prefix(8)))"
        if event["loadTime"] != nil    { line += " load=\(value(event, "loadTime"))" }
        if event["timeVisible"] != nil { line += " visible=\(value(event, "timeVisible"))" }
        // Present only when an interaction was still running as this view disappeared — i.e. the
        // user navigated away mid-load.
        if event["interactionId"] != nil {
            line += " int=\(String(value(event, "interactionId").prefix(8)))"
        }
        if let restarted = (event["restarted"] as? NSNumber)?.boolValue, restarted {
            line += " restarted"
        }
        return line
    }

    private static func describeInteraction(_ event: [String: Any]) -> String {
        // viewName / viewInstanceId / previousView come from NRMAViewContext.viewCorrelationAttributes
        // and are what join this interaction back to the MobileView event for the same visit.
        var line = "interact  \(value(event, "name").padded(to: 28))"
        line += " dur=\(value(event, "interactionDuration").padded(to: 10))"
        line += " view=\(value(event, "viewName").padded(to: 16))"
        line += " inst=\(String(value(event, "viewInstanceId").prefix(8)))"
        line += " int=\(String(value(event, "interactionId").prefix(8)))"
        return line
    }

    private static func describeBreadcrumb(_ event: [String: Any]) -> String {
        var line = "crumb     \(value(event, "name").padded(to: 28))"
        if event["page"] != nil { line += " page=\(value(event, "page"))" }
        if event["rows"] != nil { line += " rows=\(value(event, "rows"))" }
        // currentView is stamped by +[NewRelic recordBreadcrumb:attributes:] from NRMAViewContext.
        line += " view=\(value(event, "currentView").padded(to: 16))"
        if event["interactionId"] != nil {
            line += " int=\(String(value(event, "interactionId").prefix(8)))"
        }
        return line
    }

    // MARK: - Summary

    /// Prints the full navigation sequence and the referrer chain, for a quick end-of-session read.
    func printSummary() {
        lock.lock()
        let events = mobileViewEvents
        let interactions = interactionEvents
        lock.unlock()

        guard !events.isEmpty else {
            appLog("[HomeSearch/collector] no MobileView events captured")
            return
        }

        let names = Set(events.compactMap { $0["viewName"] as? String }).sorted()

        // Group interactions under the view visit they correlate to. viewInstanceId is the join key:
        // it is stable for one appearance of one screen, so every incremental load that happened
        // during that visit lands in the same bucket. An interaction that lists no viewInstanceId
        // never had a view to correlate to.
        let byVisit = Dictionary(grouping: interactions) { interaction in
            (interaction["viewInstanceId"] as? String) ?? "—"
        }

        var joins: [String] = []
        for (instanceId, group) in byVisit.sorted(by: { $0.key < $1.key }) {
            let viewName = group.first?["viewName"] as? String ?? "—"
            joins.append("  · \(viewName) [\(String(instanceId.prefix(8)))] — \(group.count) interaction(s)")
            for interaction in group.sorted(by: {
                (($0["timestamp"] as? NSNumber)?.doubleValue ?? 0) <
                (($1["timestamp"] as? NSNumber)?.doubleValue ?? 0)
            }) {
                let name = interaction["name"] as? String ?? "—"
                let duration = (interaction["interactionDuration"] as? NSNumber)?.stringValue ?? "—"
                joins.append("      \(name)  dur=\(duration)")
            }
        }

        appLog("""

        ═══ MobileView summary ═════════════════════════════════════════════════════
        \(events.count) view event(s) across \(names.count) distinct view name(s):
        \(names.map { "  · \($0)" }.joined(separator: "\n"))

        \(interactions.count) interaction(s), grouped by the view visit they correlate to:
        \(joins.isEmpty ? "  (none)" : joins.joined(separator: "\n"))
        ═══════════════════════════════════════════════════════════════════════════

        """)
    }
}

private extension String {
    func padded(to width: Int) -> String {
        count >= width ? self : self + String(repeating: " ", count: width - count)
    }
}
