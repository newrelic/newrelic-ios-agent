//
//  NRCollectorStub.swift
//  ExpensesTracker
//
//  A local stand-in for the New Relic collector, used in capture mode so harvest payloads can be read
//  straight from the console instead of waiting on a round trip to an account.
//
//  The Android app only ever reported to the staging collector, so checking that a button produced the
//  event you expected meant a trip to the UI and a NRQL query. Capture mode removes that loop, which
//  matters most for the MobileView events this port adds — those are the ones whose exact shape is
//  still being settled.
//
//  Port 8080, and it has to be exactly that: NRMAAgentConfiguration only turns TLS off when the
//  collector address is the literal string "localhost:8080" — see NRMAAgentConfiguration.m. Any other
//  host, 127.0.0.1:8080 included, makes the agent speak HTTPS and the connection fails against a plain
//  HTTP stub.
//
//  Consequence worth knowing: this shares 8080 with HomeSearch's collector stub and with NRTestApp's
//  NRCaptureServer, so no two of those apps can be in capture mode at once.
//

import Foundation

final class NRCollectorStub {

    static let shared = NRCollectorStub()

    /// Fixed by the agent's TLS opt-out, which matches on the address string exactly.
    static let port: UInt16 = 8080
    static let address = "localhost:8080"

    private let server = HttpServer()
    private var isRunning = false

    private init() {}

    func start() {
        guard !isRunning else { return }

        // Just well formed enough for the agent to accept the connect and start harvesting; these are
        // the fields it reads.
        let connectResponse: [String: Any] = [
            "server_timestamp": 1_656_525_980,
            "data_report_period": 15,
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
            appLog("[ExpensesTracker/collector] connect")
            return .ok(.json(connectResponse))
        }

        server.POST["/mobile/:version/data"] = { [weak self] request in
            self?.describeHarvest(Data(request.body))
            return .ok(.json([:] as [String: Any]))
        }

        // Everything else the agent may post: swallow it, so nothing retries in a loop.
        for path in ["/mobile/f", "/mobile/blobs", "/mobile/errors", "/mobile/logs"] {
            server.POST[path] = { _ in .ok(.json([:] as [String: Any])) }
        }
        server.POST["/:path"] = { _ in .ok(.json([:] as [String: Any])) }

        do {
            try server.start(Self.port, forceIPv4: true)
            isRunning = true
            appLog("[ExpensesTracker/collector] listening on \(Self.address)")
        } catch {
            appLog("[ExpensesTracker/collector] failed to start: \(error)")
        }
    }

    func stop() {
        server.stop()
        isRunning = false
    }

    // MARK: - Harvest decoding

    /// The data harvest body is a JSON array; index 9 is `analyticsEvents`, which is where MobileView,
    /// breadcrumb, handled-exception and custom events all arrive. Index 6 holds the code-level
    /// activity-trace node trees, whose volume the collector's `at_capture` cap limits — only its count
    /// is printed, for context.
    private func describeHarvest(_ body: Data) {
        guard let root = try? JSONSerialization.jsonObject(with: body) as? [Any] else {
            appLog("[ExpensesTracker/collector] harvest was not a JSON array (\(body.count) bytes)")
            return
        }

        let events = (root.indices.contains(9) ? root[9] as? [Any] : nil)?
            .compactMap { $0 as? [String: Any] } ?? []
        let traceCount = ((root.indices.contains(6) ? root[6] as? [Any] : nil) ?? []).count

        let byType = Dictionary(grouping: events.compactMap { $0["eventType"] as? String }, by: { $0 })
            .mapValues(\.count)
            .sorted { $0.key < $1.key }
            .map { "\($0.value) \($0.key)" }
            .joined(separator: ", ")

        appLog("""

        ┌─ harvest ─────────────────────────────────────────────────────────────────
        │ \(events.count) event(s)\(byType.isEmpty ? "" : ": " + byType) · \(traceCount) activity trace(s)
        """)

        // Ordered by timestamp so a screen's life reads as a timeline: the view appears, the requests
        // and breadcrumbs it caused follow, then it disappears with its timeVisible.
        let timeline = events.sorted {
            (($0["timestamp"] as? NSNumber)?.doubleValue ?? 0) <
            (($1["timestamp"] as? NSNumber)?.doubleValue ?? 0)
        }
        for event in timeline {
            appLog("│ " + Self.describe(event))
        }
        appLog("└───────────────────────────────────────────────────────────────────────────\n")
    }

    private static func describe(_ event: [String: Any]) -> String {
        let type = string(event, "eventType")

        switch type {
        case "MobileView":
            // `appeared` distinguishes the appear event from the disappear event.
            let appeared = (event["appeared"] as? NSNumber)?.boolValue
            let phase = appeared.map { $0 ? "appear   " : "disappear" } ?? "?        "
            var line = "\(phase) \(pad(string(event, "viewName"), 28))"
            line += " prev=\(pad(string(event, "previousView"), 22))"
            line += " platform=\(string(event, "uiPlatform"))"
            if event["loadTime"] != nil    { line += " load=\(string(event, "loadTime"))" }
            if event["timeVisible"] != nil { line += " visible=\(string(event, "timeVisible"))" }
            return line

        case "MobileBreadcrumb":
            return "crumb     \(pad(string(event, "name"), 28)) currentView=\(string(event, "currentView"))"

        case "MobileRequest", "MobileRequestError":
            return "\(pad(type, 18)) \(string(event, "requestUrl")) → \(string(event, "statusCode"))"

        case "MobileHandledException":
            return "handled   \(string(event, "name")): \(string(event, "exceptionMessage"))"

        default:
            let extras = event.keys.sorted()
                .filter { !["eventType", "timestamp"].contains($0) }
                .prefix(4)
                .map { "\($0)=\(string(event, $0))" }
                .joined(separator: " ")
            return "\(pad(type, 18)) \(extras)"
        }
    }

    private static func string(_ event: [String: Any], _ key: String) -> String {
        if let value = event[key] as? String { return value }
        if let value = event[key] as? NSNumber { return value.stringValue }
        return "—"
    }

    private static func pad(_ text: String, _ width: Int) -> String {
        text.count >= width ? text : text + String(repeating: " ", count: width - text.count)
    }
}
