//
//  NRCollectorStub.swift
//  HomeSearch
//
//  A local stand-in for the New Relic collector, so harvest payloads can be read directly instead
//  of waiting on a round trip to a real account.
//
//  Point the agent at this in capture mode (see NewRelicConfig) and every harvest lands here. The
//  interesting part is `handleDataHarvest(_:)`: the data harvest body is a JSON array whose element
//  at index 9 is `analyticsEvents`, so we decode that, pick out the MobileView events, and log them
//  as a table in navigation order.
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
            "at_capture": [1, []],
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

        // Index 9 of the data harvest array is analyticsEvents.
        let events = (root.indices.contains(9) ? root[9] as? [Any] : nil)?
            .compactMap { $0 as? [String: Any] } ?? []

        let views = events.filter { $0["eventType"] as? String == "MobileView" }
        let others = Dictionary(grouping: events.compactMap { $0["eventType"] as? String }, by: { $0 })
            .mapValues(\.count)
            .filter { $0.key != "MobileView" }

        appLog("""

        ┌─ harvest ─────────────────────────────────────────────────────────────────
        │ \(events.count) analytics event(s): \(views.count) MobileView\
        \(others.isEmpty ? "" : ", " + others.sorted(by: { $0.key < $1.key }).map { "\($0.value) \($0.key)" }.joined(separator: ", "))
        """)

        guard !views.isEmpty else {
            appLog("└───────────────────────────────────────────────────────────────────────────\n")
            return
        }

        lock.lock()
        mobileViewEvents.append(contentsOf: views)
        lock.unlock()

        // Oldest first, so the print order matches the order the user navigated.
        let ordered = views.sorted {
            (($0["timestamp"] as? NSNumber)?.doubleValue ?? 0) <
            (($1["timestamp"] as? NSNumber)?.doubleValue ?? 0)
        }

        for event in ordered {
            appLog("│ " + Self.describe(event))
        }
        appLog("└───────────────────────────────────────────────────────────────────────────\n")
    }

    private static func describe(_ event: [String: Any]) -> String {
        func str(_ key: String) -> String {
            if let value = event[key] as? String { return value }
            if let value = event[key] as? NSNumber { return value.stringValue }
            return "—"
        }

        // `appeared` distinguishes the appear event from the disappear event. If both show up for a
        // single visit, that is the double-count the DACI flags.
        let appeared = (event["appeared"] as? NSNumber)?.boolValue
        let phase = appeared.map { $0 ? "appear   " : "disappear" } ?? "?        "

        var line = "\(phase) \(str("viewName").padded(to: 34))"
        line += " prev=\(str("previousView").padded(to: 28))"
        line += " inst=\(String(str("viewInstanceId").prefix(8)))"
        if event["loadTime"] != nil    { line += " load=\(str("loadTime"))" }
        if event["timeVisible"] != nil { line += " visible=\(str("timeVisible"))" }
        if let restarted = (event["restarted"] as? NSNumber)?.boolValue, restarted {
            line += " restarted"
        }
        return line
    }

    // MARK: - Summary

    /// Prints the full navigation sequence and the referrer chain, for a quick end-of-session read.
    func printSummary() {
        lock.lock()
        let events = mobileViewEvents
        lock.unlock()

        guard !events.isEmpty else {
            appLog("[HomeSearch/collector] no MobileView events captured")
            return
        }

        let names = Set(events.compactMap { $0["viewName"] as? String }).sorted()
        appLog("""

        ═══ MobileView summary ═════════════════════════════════════════════════════
        \(events.count) event(s) across \(names.count) distinct view name(s):
        \(names.map { "  · \($0)" }.joined(separator: "\n"))
        ═══════════════════════════════════════════════════════════════════════════

        """)
    }
}

private extension String {
    func padded(to width: Int) -> String {
        count >= width ? self : self + String(repeating: " ", count: width - count)
    }
}
