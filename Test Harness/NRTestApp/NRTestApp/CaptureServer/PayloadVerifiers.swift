import Foundation

// MARK: - Dispatcher

func verify(data: Data,
            endpoint: String,
            queryParams: [(String, String)] = [],
            headers: [String: String] = [:]) -> VerificationResult? {
    switch true {
    case endpoint.hasSuffix("/connect"):  return ConnectVerifier.verify(data, headers: headers)
    case endpoint.hasSuffix("/data"):     return DataVerifier.verify(data, headers: headers)
    case endpoint == "/mobile/errors":    return JSErrorsVerifier.verify(data, queryParams: queryParams, headers: headers)
    case endpoint == "/mobile/f":         return HexVerifier.verify(data, headers: headers)
    case endpoint == "/mobile/logs":      return LogsVerifier.verify(data, headers: headers)
    case endpoint == "/mobile/blobs":     return SessionReplayVerifier.verify(data, queryParams: queryParams, headers: headers)
    default:                              return nil
    }
}

// MARK: - Helpers

private func h(_ headers: [String: String], _ name: String) -> String? {
    // Swifter lowercases header names
    headers[name.lowercased()]
}

/// Returns a detail string for the first event in `items` that fails `test`, or nil when all pass.
/// Reports the event's `eventType` and the raw value of `key` so a failing check points at
/// the specific item rather than just collapsing to false.
private func firstFailing(_ items: [[String: Any]], key: String, test: (Any?) -> Bool) -> String? {
    guard let bad = items.first(where: { !test($0[key]) }) else { return nil }
    let evt = (bad["eventType"] as? String) ?? "unknown"
    if let val = bad[key] { return "\(key)=\(val) in \(evt)" }
    return "\(key) missing in \(evt)"
}

// Session attributes required by both data.md and jserror_data.md.
// Returns checks against a flat [String: Any] dict (data harvest) or
// [String: String] dict (session replay URL attributes, JS error events).
private func sessionAttributeChecks(from attrs: [String: Any]) -> [VerificationCheck] {
    func str(_ key: String) -> String? { attrs[key] as? String }
    // memUsageMb arrives as NSNumber in JSON dicts and as a numeric string in URL attribute dicts.
    // The field may be absent (e.g. memory info unavailable) — only fail if present but non-numeric.
    func numericIfPresent(_ key: String) -> Bool {
        guard let val = attrs[key] else { return true }
        if val is NSNumber { return true }
        return (val as? String).flatMap(Double.init) != nil
    }
    return [
        check("sessionAttrs: sessionId non-empty",          str("sessionId")?.isEmpty         == false, detail: str("sessionId")),
        check("sessionAttrs: osName non-empty",             str("osName")?.isEmpty             == false, detail: str("osName")),
        check("sessionAttrs: osVersion non-empty",          str("osVersion")?.isEmpty          == false, detail: str("osVersion")),
        check("sessionAttrs: osMajorVersion non-empty",     str("osMajorVersion")?.isEmpty     == false, detail: str("osMajorVersion")),
        check("sessionAttrs: deviceManufacturer non-empty", str("deviceManufacturer")?.isEmpty == false, detail: str("deviceManufacturer")),
        check("sessionAttrs: deviceModel non-empty",        str("deviceModel")?.isEmpty        == false, detail: str("deviceModel")),
        check("sessionAttrs: newRelicVersion non-empty",    str("newRelicVersion")?.isEmpty    == false, detail: str("newRelicVersion")),
        check("sessionAttrs: memUsageMb is numeric",        numericIfPresent("memUsageMb"),     detail: str("memUsageMb")),
        check("sessionAttrs: carrier non-empty",            str("carrier")?.isEmpty            == false, detail: str("carrier")),
    ]
}

// Per-event and per-eventType checks for analytics events in the data harvest.
// Covers: timestamp presence, HTTP-transaction cross-check, and required typed
// fields per eventType.
private func analyticsEventChecks(events: [[String: Any]], httpCount: Int) -> [VerificationCheck] {
    let timestampsValid = events.allSatisfy { $0["timestamp"] is NSNumber }

    let mobileRequestEvts  = events.filter { $0["eventType"] as? String == "MobileRequest" }
    let mobileErrEvts     = events.filter { $0["eventType"] as? String == "MobileRequestError" }
    let mobileActionEvts  = events.filter { $0["eventType"] as? String == "MobileAction" }
    let mobileSessionEvts = events.filter { ["Mobile", "MobileSession"].contains($0["eventType"] as? String) }
    let mobileViewEvts    = events.filter { $0["eventType"] as? String == "MobileView" }

    var result: [VerificationCheck] = [
        check("analyticsEvents: all have timestamp (NSNumber)", timestampsValid,
              detail: firstFailing(events, key: "timestamp") { $0 is NSNumber }),
    ]

    // If the agent recorded HTTP transactions, there must be corresponding MobileRequest events.
    if httpCount > 0 {
        result.append(check(
            "analyticsEvents: MobileRequest events present (http transactions found)",
            !mobileRequestEvts.isEmpty,
            detail: "http=\(httpCount) transactions, MobileRequest events=\(mobileRequestEvts.count)"
        ))
    }

    if !mobileRequestEvts.isEmpty {
        result += [
            check("MobileRequest: requestUrl is String",
                  mobileRequestEvts.allSatisfy { $0["requestUrl"] is String },
                  detail: firstFailing(mobileRequestEvts, key: "requestUrl") { $0 is String }),
            check("MobileRequest: statusCode is NSNumber",
                  mobileRequestEvts.allSatisfy { $0["statusCode"] is NSNumber },
                  detail: firstFailing(mobileRequestEvts, key: "statusCode") { $0 is NSNumber }),
            check("MobileRequest: responseTime is NSNumber",
                  mobileRequestEvts.allSatisfy { $0["responseTime"] is NSNumber },
                  detail: firstFailing(mobileRequestEvts, key: "responseTime") { $0 is NSNumber }),
            check("MobileRequest: bytesReceived is NSNumber when present",
                  mobileRequestEvts.allSatisfy { $0["bytesReceived"] == nil || $0["bytesReceived"] is NSNumber },
                  detail: firstFailing(mobileRequestEvts, key: "bytesReceived") { $0 == nil || $0 is NSNumber }),
            check("MobileRequest: bytesSent is NSNumber when present",
                  mobileRequestEvts.allSatisfy { $0["bytesSent"] == nil || $0["bytesSent"] is NSNumber },
                  detail: firstFailing(mobileRequestEvts, key: "bytesSent") { $0 == nil || $0 is NSNumber }),
        ]
    }

    if !mobileErrEvts.isEmpty {
        result += [
            check("MobileRequestError: requestUrl is String",
                  mobileErrEvts.allSatisfy { $0["requestUrl"] is String },
                  detail: firstFailing(mobileErrEvts, key: "requestUrl") { $0 is String }),
            check("MobileRequestError: statusCode or networkError",
                  mobileErrEvts.allSatisfy { $0["statusCode"] is NSNumber || $0["networkError"] is String },
                  detail: firstFailing(mobileErrEvts, key: "statusCode") { $0 is NSNumber || ($0 as? String) != nil }),
        ]
    }

    if !mobileActionEvts.isEmpty {
        result += [
            check("MobileAction: actionType is String",
                  mobileActionEvts.allSatisfy { $0["actionType"] is String },
                  detail: firstFailing(mobileActionEvts, key: "actionType") { $0 is String }),
            check("MobileAction: name is String",
                  mobileActionEvts.allSatisfy { $0["name"] is String },
                  detail: firstFailing(mobileActionEvts, key: "name") { $0 is String }),
        ]
    }

    if !mobileSessionEvts.isEmpty {
        result += [
            check("Mobile/MobileSession: timeSinceLoad is NSNumber",
                  mobileSessionEvts.allSatisfy { $0["timeSinceLoad"] is NSNumber },
                  detail: firstFailing(mobileSessionEvts, key: "timeSinceLoad") { $0 is NSNumber }),
        ]
    }

    if !mobileViewEvts.isEmpty {
        result += mobileViewChecks(events: mobileViewEvts)
    }

    return result
}

// MobileView events (NRFeatureFlag_AutomaticMobileViews / NRFeatureFlag_ManualMobileViews).
//
// Three producers write this event type and they do not emit an identical set of keys, so the checks
// below assert only what all of them are required to carry, plus the type of everything optional:
//
//   UIKit    NRMAMobileViewTracker — appear carries loadTime (unless the load was never observed)
//            but NOT `restarted`; disappear carries restarted, loadTime and timeVisible.
//   SwiftUI  NRMobileViewModifier — appear carries restarted and loadTime; disappear carries
//            restarted and timeVisible.
//   SwiftUI  NRMobileTabTrackingModifier — a tab switch is not a view lifecycle event, so it emits
//            `appeared = false` with neither timeVisible nor loadTime, marked navigationKind = tab.
//
// Requiring one uniform schema across all three would fail on correct data, so leniency here is
// deliberate rather than sloppy.
private func mobileViewChecks(events: [[String: Any]]) -> [VerificationCheck] {
    // Tab-switch events are excluded from the lifecycle-pairing checks below: they report a
    // selection change, not a screen that appeared and later went away.
    let tabEvts       = events.filter { $0["navigationKind"] as? String == "tab" }
    let lifecycleEvts = events.filter { $0["navigationKind"] as? String != "tab" }
    let disappearEvts = lifecycleEvts.filter { ($0["appeared"] as? NSNumber)?.boolValue == false }

    func optional(_ key: String, in evts: [[String: Any]], is test: (Any) -> Bool) -> Bool {
        evts.allSatisfy { $0[key] == nil || test($0[key]!) }
    }
    let isNumber: (Any) -> Bool = { $0 is NSNumber }
    let isString: (Any) -> Bool = { $0 is String }
    let isNonNegativeNumber: (Any) -> Bool = { ($0 as? NSNumber).map { $0.doubleValue >= 0 } ?? false }

    var checks: [VerificationCheck] = [
        // Identity — every producer emits all three on every event.
        check("MobileView: viewName is non-empty String",
              events.allSatisfy { ($0["viewName"] as? String)?.isEmpty == false },
              detail: "count=\(events.count), tabSwitches=\(tabEvts.count)"),
        check("MobileView: viewClass is non-empty String",
              events.allSatisfy { ($0["viewClass"] as? String)?.isEmpty == false }),
        check("MobileView: viewInstanceId is non-empty String",
              events.allSatisfy { ($0["viewInstanceId"] as? String)?.isEmpty == false }),

        // Provenance.
        check("MobileView: appeared is NSNumber",  events.allSatisfy { $0["appeared"] is NSNumber }),
        check("MobileView: uiPlatform is UIKit or SwiftUI",
              events.allSatisfy { ["UIKit", "SwiftUI"].contains($0["uiPlatform"] as? String) },
              detail: Set(events.compactMap { $0["uiPlatform"] as? String }).sorted().joined(separator: ",")),
        check("MobileView: agentName == iOS",      events.allSatisfy { $0["agentName"] as? String == "iOS" }),

        // Timings are milliseconds and non-negative. Both are optional per producer, so type-check
        // them only where present — an absent loadTime means the load was never observed (a view
        // reappearing without reloading), which is distinct from a load of zero.
        check("MobileView: loadTime is non-negative NSNumber when present",
              optional("loadTime", in: events, is: isNonNegativeNumber)),
        check("MobileView: timeVisible is non-negative NSNumber when present",
              optional("timeVisible", in: events, is: isNonNegativeNumber)),

        // `restarted` is NOT required: the UIKit producer omits it on the appear event.
        check("MobileView: restarted is NSNumber when present", optional("restarted", in: events, is: isNumber)),

        // Referrer / correlation attributes, all optional (absent on the first view of a session and
        // when no interaction is running).
        check("MobileView: previousView is String when present",   optional("previousView", in: events, is: isString)),
        check("MobileView: interactionId is String when present",  optional("interactionId", in: events, is: isString)),
    ]

    // A lifecycle disappear event is the one that closes out a view's visible span, so it is the one
    // place timeVisible is genuinely required.
    if !disappearEvts.isEmpty {
        checks.append(check(
            "MobileView: lifecycle disappear events carry timeVisible",
            disappearEvts.allSatisfy { $0["timeVisible"] is NSNumber },
            detail: "disappearEvents=\(disappearEvts.count)"
        ))
    }

    return checks
}

// MARK: - Connect  /mobile/v5/connect
//
// Spec: endpoints/connect.md + endpoints/protocol-version-1/connect.md
//
// Body: [[appName, appVersion, bundleId],
//        [osName, osVersion, deviceModel, agentName, agentVersion, deviceId,
//         null, null, manufacturer, {platform, platformVersion}]]

private enum ConnectVerifier {
    static func verify(_ data: Data, headers: [String: String]) -> VerificationResult {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [[Any]] else {
            return VerificationResult(checks: [check("Valid JSON array", false)])
        }
        let app = root.indices.contains(0) ? root[0] : nil
        let dev = root.indices.contains(1) ? root[1] : nil
        let misc = dev?.indices.contains(9) == true ? dev![9] as? [String: Any] : nil

        return .make {
            // Headers (connect.md request spec)
            check("X-App-License-Key present",  h(headers, "X-App-License-Key") != nil)
            check("Content-Type: application/json", h(headers, "Content-Type") == "application/json")

            // Root shape
            check("Valid JSON array",           true)
            check("Root has 2 elements",        root.count == 2,           detail: "count=\(root.count)")

            // [0] Application info (connect.md §Body [0])
            check("appInfo: 3-element array",   app?.count == 3,           detail: app.map { "count=\($0.count)" })
            check("appName non-empty",          (app?[0] as? String)?.isEmpty == false)
            check("appVersion non-empty",       (app?[1] as? String)?.isEmpty == false)
            check("bundleId non-empty",         (app?[2] as? String)?.isEmpty == false)

            // [1] Device info (connect.md §Body [1])
            check("deviceInfo: 10-element array", dev?.count == 10,        detail: dev.map { "count=\($0.count)" })
            check("osName == iOS",              dev?[0] as? String == "iOS")
            check("osVersion non-empty",        (dev?[1] as? String)?.isEmpty == false)
            check("deviceModel non-empty",      (dev?[2] as? String)?.isEmpty == false)
            check("agentName == iOSAgent",      dev?[3] as? String == "iOSAgent")
            check("agentVersion non-empty",     (dev?[4] as? String)?.isEmpty == false)
            check("deviceId non-empty",         (dev?[5] as? String)?.isEmpty == false)
            check("[1][6] deprecated (null/empty)", dev.map { $0[6] is NSNull || ($0[6] as? String)?.isEmpty != false } == true)
            check("[1][7] deprecated (null/empty)", dev.map { $0[7] is NSNull || ($0[7] as? String)?.isEmpty != false } == true)
            check("manufacturer non-empty",     (dev?[8] as? String)?.isEmpty == false)

            // [1][9] Miscellaneous params — platform and platformVersion are required (connect.md §Miscellaneous)
            check("misc params present",        misc != nil)
            check("misc.platform non-empty",    (misc?["platform"] as? String)?.isEmpty == false,  detail: misc?["platform"] as? String)
            check("misc.platformVersion non-empty", (misc?["platformVersion"] as? String)?.isEmpty == false, detail: misc?["platformVersion"] as? String)
        }
    }
}

// MARK: - Harvest data  /mobile/v3/data
//
// Spec: endpoints/data.md
//
// Body (10 elements as sent by NRMAHarvestData, spec says 9 — agent adds an extra agent-health [] at [7]):
//  [0] DATA_TOKEN          [clusterAgentId, realAgentId]
//  [1] DEVICE_INFORMATION  [osName, osVersion, deviceModel, agentName, agentVer, deviceId, "", "", mfr, {platform}]
//  [2] TIME_SINCE_LAST_HARVEST  Long (seconds)
//  [3] HTTP_TRANSACTIONS   [[URL, carrier, responseTime, statusCode, errorCode, bytesSent, bytesReceived, xprocData, ...], ...]
//  [4] METRICS             [[{name, scope}, {count, total, min, max, sum_of_squares}], ...]
//  [5] HTTP_ERROR_TRACES   [] (DEPRECATED — always empty)
//  [6] ACTIVITY_TRACES     []
//  [7] AGENT_HEALTH        [] (agent-specific, not in spec)
//  [8] SESSION_ATTRIBUTES  {}
//  [9] ANALYTICS_EVENTS    [{eventType, ...}, ...]

private enum DataVerifier {
    static func verify(_ data: Data, headers: [String: String]) -> VerificationResult {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [Any] else {
            return VerificationResult(checks: [check("Valid JSON array", false)])
        }

        func arr(_ i: Int) -> [Any]?           { root.indices.contains(i) ? root[i] as? [Any] : nil }
        func obj(_ i: Int) -> [String: Any]?   { root.indices.contains(i) ? root[i] as? [String: Any] : nil }

        let tokens  = arr(0)
        let dev     = arr(1)
        let http    = arr(3)
        let metrics = arr(4)
        let events  = arr(9)

        // HTTP transaction spot-check: each row should be ≥8 elements, [0] a URL string
        let httpValid = http.map { txns in
            txns.allSatisfy { row in
                guard let row = row as? [Any], row.count >= 8 else { return true } // empty rows are fine
                return row[0] is String
            }
        } ?? true

        // Metrics spot-check: each entry is a 2-element array where [0] has "name" key
        let metricsValid = metrics.map { ms in
            ms.allSatisfy { m in
                guard let m = m as? [Any], m.count == 2 else { return true }
                return (m[0] as? [String: Any])?["name"] is String
            }
        } ?? true

        // Analytics events
        let typedEvents = events?.compactMap { $0 as? [String: Any] } ?? []
        let eventsValid = typedEvents.isEmpty || typedEvents.allSatisfy { $0["eventType"] != nil }

        return .make {
            // Headers (data.md request spec)
            check("X-App-License-Key present",      h(headers, "X-App-License-Key") != nil)
            check("Content-Type: application/json", h(headers, "Content-Type") == "application/json")

            // Root shape — agent sends 10 (spec says 9; extra [7] is agent-health node)
            check("Valid JSON array",               true)
            check("Root has 10 elements",           root.count == 10,         detail: "count=\(root.count)")

            // [0] Data token
            check("dataToken: 2 integers",          tokens?.count == 2 && tokens?.allSatisfy { $0 is NSNumber } == true,
                  detail: tokens.map { "count=\($0.count)" })

            // [1] Device info
            check("deviceInfo: 10-element array",   dev?.count == 10,         detail: dev.map { "count=\($0.count)" })
            check("deviceInfo[0] == iOS",           dev?[0] as? String == "iOS")
            check("deviceInfo[3] == iOSAgent",      dev?[3] as? String == "iOSAgent")

            // [2] Time since last harvest (Long, ≥0)
            check("harvestDelta is non-negative",   (root.indices.contains(2) ? root[2] as? NSNumber : nil).map { $0.doubleValue >= 0 } == true)

            // [3] HTTP transactions
            check("httpTransactions is array",      http != nil,              detail: http.map { "count=\($0.count)" })
            check("httpTransactions rows valid",    httpValid,                detail: httpValid ? nil : "Row missing URL at index 0 or <8 elements")

            // [4] Metrics
            check("metrics is array",               metrics != nil,           detail: metrics.map { "count=\($0.count)" })
            check("metrics rows valid [{name,scope},{stats}]", metricsValid)

            // [5] HTTP error traces (deprecated — must be array per spec, always empty)
            check("httpErrorTraces is array",       arr(5) != nil)

            // [6] Activity traces
            check("activityTraces is array",        arr(6) != nil)

            // [8] Session attributes — only required when there are analytics events to decorate
            check("sessionAttributes is object",    obj(8) != nil)
            if (events?.isEmpty == false) {
                sessionAttributeChecks(from: obj(8) ?? [:])
            }

            // [9] Analytics events
            check("analyticsEvents is array",       events != nil,            detail: events.map { "count=\($0.count)" })
            check("analyticsEvents have eventType", eventsValid)
            if !typedEvents.isEmpty {
                analyticsEventChecks(events: typedEvents, httpCount: http?.count ?? 0)
            }
        }
    }
}

// MARK: - JS errors  /mobile/errors
//
// Spec: endpoints/jserror_data.md
//
// Required body fields: dataToken (array), analyticsEvents (array)
// Required query params: protocol_version=1, platform=reactnative
// Required event fields: eventType="MobileJSError", errorId, errorName, errorMessage

private enum JSErrorsVerifier {
    static func verify(_ data: Data, queryParams: [(String, String)], headers: [String: String]) -> VerificationResult {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return VerificationResult(checks: [check("Valid JSON object", false)])
        }
        func q(_ name: String) -> String? { queryParams.first(where: { $0.0 == name })?.1 }

        let events = root["analyticsEvents"] as? [[String: Any]]
        let token  = root["dataToken"] as? [Any]

        return .make {
            // Headers
            check("X-App-License-Key present",          h(headers, "X-App-License-Key") != nil)
            check("Content-Type: application/json",     h(headers, "Content-Type") == "application/json")

            // Query params (jserror_data.md §Request)
            check("protocol_version == 1",              q("protocol_version") == "1",  detail: q("protocol_version").map { "was \"\($0)\"" })
            check("platform == reactnative",            q("platform") == "reactnative", detail: q("platform").map { "was \"\($0)\"" })

            // Required body fields
            check("Valid JSON object",                  true)
            check("dataToken present (2 integers)",     token?.count == 2 && token?.allSatisfy { $0 is NSNumber } == true,
                  detail: token.map { "count=\($0.count)" })
            check("analyticsEvents present (required)", events != nil,   detail: events.map { "count=\($0.count)" })
            check("analyticsEvents non-empty",          (events?.count ?? 0) > 0)

            // Per-event required fields (jserror_data.md §MobileJSError)
            check("all events: eventType == MobileJSError",
                  events?.allSatisfy { $0["eventType"] as? String == "MobileJSError" } == true,
                  detail: events.flatMap { firstFailing($0, key: "eventType") { $0 as? String == "MobileJSError" } })
            check("all events: errorId present",
                  events?.allSatisfy { $0["errorId"] is String } == true,
                  detail: events.flatMap { firstFailing($0, key: "errorId") { $0 is String } })
            check("all events: errorName present",
                  events?.allSatisfy { $0["errorName"] is String } == true,
                  detail: events.flatMap { firstFailing($0, key: "errorName") { $0 is String } })
            check("all events: errorMessage present",
                  events?.allSatisfy { $0["errorMessage"] is String } == true,
                  detail: events.flatMap { firstFailing($0, key: "errorMessage") { $0 is String } })

            // Per jserror_data.md, session attributes are flattened into every event.
            // Verify each event carries the required system attributes.
            check("all events: sessionId non-empty",
                  events?.allSatisfy { ($0["sessionId"] as? String)?.isEmpty == false } == true,
                  detail: events.flatMap { firstFailing($0, key: "sessionId") { ($0 as? String)?.isEmpty == false } })
            check("all events: osName non-empty",
                  events?.allSatisfy { ($0["osName"] as? String)?.isEmpty == false } == true,
                  detail: events.flatMap { firstFailing($0, key: "osName") { ($0 as? String)?.isEmpty == false } })
            check("all events: osVersion non-empty",
                  events?.allSatisfy { ($0["osVersion"] as? String)?.isEmpty == false } == true,
                  detail: events.flatMap { firstFailing($0, key: "osVersion") { ($0 as? String)?.isEmpty == false } })
            check("all events: newRelicVersion non-empty",
                  events?.allSatisfy { ($0["newRelicVersion"] as? String)?.isEmpty == false } == true,
                  detail: events.flatMap { firstFailing($0, key: "newRelicVersion") { ($0 as? String)?.isEmpty == false } })
            check("all events: deviceModel non-empty",
                  events?.allSatisfy { ($0["deviceModel"] as? String)?.isEmpty == false } == true,
                  detail: events.flatMap { firstFailing($0, key: "deviceModel") { ($0 as? String)?.isEmpty == false } })
            check("all events: memUsageMb is number",
                  events?.allSatisfy { $0["memUsageMb"] is NSNumber } == true,
                  detail: events.flatMap { firstFailing($0, key: "memUsageMb") { $0 is NSNumber } })
        }
    }
}

// MARK: - Logs  /mobile/logs
//
// Spec: NRLogger.m — enqueueLogUpload builds the payload
//
// Compression: NRMAHarvesterConnection.gzipData uses deflateInit() (no windowBits override)
// which produces ZLIB format, and kNRMAGZipHeader = @"deflate" — so the header is
// Content-Encoding: deflate, NOT gzip. Swifter auto-decompresses deflate in HTTPParser,
// so decodedBody is already plain JSON by the time the verifier sees it.
//
// Body structure:
//   [{ "common": { "attributes": { entity.guid, sessionId, instrumentation.*, appId, … } },
//      "logs":   [ { "level", "message", "timestamp", "file", "lineNumber", "method" }, … ] }]
//
// Valid levels: ERROR, WARN, INFO, VERBOSE, AUDIT, DEBUG (NRLogger.levelToString)

private enum LogsVerifier {
    private static let validLevels: Set<String> = ["ERROR", "WARN", "INFO", "VERBOSE", "AUDIT", "DEBUG"]

    static func verify(_ data: Data, headers: [String: String]) -> VerificationResult {
        // kNRMAGZipHeader = @"deflate" — the agent uses zlib/deflate format, not gzip.
        // Swifter decompresses deflate bodies automatically before capture() sees them.
        let isDeflate = h(headers, "Content-Encoding") == "deflate"

        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else {
            return VerificationResult(checks: [
                check("Content-Type: application/json",    h(headers, "Content-Type") == "application/json"),
                check("X-App-License-Key present",         h(headers, "X-App-License-Key") != nil),
                check("Content-Encoding: deflate",         isDeflate),
                check("Valid JSON array",                  false,
                      detail: "body is not a JSON array — Swifter decompression may have failed"),
            ])
        }

        let batch       = root.first
        let common      = batch?["common"] as? [String: Any]
        let commonAttrs = common?["attributes"] as? [String: Any]
        let logs        = batch?["logs"] as? [[String: Any]]

        let badLevelEntry = logs?.first {
            ($0["level"] as? String).map { !validLevels.contains($0) } ?? true
        }
        let levelsValid = badLevelEntry == nil
        let timestampsValid = logs?.allSatisfy { $0["timestamp"] is NSNumber } ?? true

        return .make {
            // Headers
            check("Content-Type: application/json",     h(headers, "Content-Type") == "application/json")
            check("X-App-License-Key present",          h(headers, "X-App-License-Key") != nil)
            check("Content-Encoding: deflate",          isDeflate)

            // Root structure
            check("Valid JSON array",                   true)
            check("Root has 1 batch element",           root.count == 1,      detail: "count=\(root.count)")
            check("Batch has common block",             common != nil)
            check("Batch has logs array",               logs != nil,          detail: logs.map { "count=\($0.count)" })
            check("Logs array non-empty",               (logs?.isEmpty == false),
                  detail: logs.map { "count=\($0.count)" })

            // Common attributes
            check("common.attributes present",          commonAttrs != nil)
            check("common: entity.guid non-empty",      (commonAttrs?["entity.guid"] as? String)?.isEmpty == false,
                  detail: commonAttrs?["entity.guid"] as? String)
            check("common: sessionId non-empty",        (commonAttrs?["sessionId"] as? String)?.isEmpty == false,
                  detail: commonAttrs?["sessionId"] as? String)
            check("common: instrumentation.provider == mobile",
                  commonAttrs?["instrumentation.provider"] as? String == "mobile")
            check("common: instrumentation.name non-empty",
                  (commonAttrs?["instrumentation.name"] as? String)?.isEmpty == false,
                  detail: commonAttrs?["instrumentation.name"] as? String)
            check("common: collector.name non-empty",
                  (commonAttrs?["collector.name"] as? String)?.isEmpty == false,
                  detail: commonAttrs?["collector.name"] as? String)
            check("common: appId non-empty",
                  (commonAttrs?["appId"] as? String)?.isEmpty == false,
                  detail: commonAttrs?["appId"] as? String)

            // Per-entry checks
            check("all entries have level",             logs?.allSatisfy { $0["level"] is String } == true)
            check("all entries have valid level",       levelsValid,
                  detail: badLevelEntry.map { entry in
                      let level = entry["level"] as? String ?? "(missing)"
                      let msg   = (entry["message"] as? String ?? "").prefix(80)
                      return "level=\"\(level)\" message=\"\(msg)\" — valid: \(validLevels.sorted().joined(separator: ", "))"
                  })
            check("all entries have message",           logs?.allSatisfy { $0["message"] is String } == true)
            check("all entries have timestamp",         timestampsValid)
        }
    }
}

// MARK: - Handled exceptions (hex)  /mobile/f
//
// Spec: endpoints/handled_exception_data.md
//
// Body: FlatBuffers-encoded HexAgentDataBundle.
// No file_identifier is defined in the schema (VerifyHexAgentDataBundleBuffer passes nullptr),
// so structural validation is limited to the root-offset header.
//
// FlatBuffer binary layout (no file identifier):
//   [0..3]  root_table_offset  — little-endian uint32, offset from byte-0 to the root table
//   [4..]   table data
//
// A valid root_table_offset must be ≥ 4 (can't precede itself) and < buffer size.

private enum HexVerifier {
    static func verify(_ data: Data, headers: [String: String]) -> VerificationResult {
        // FlatBuffer root-offset check
        let rootOffset: UInt32? = data.count >= 4
            ? data.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt32.self) }.littleEndian
            : nil
        let rootOffsetValid = rootOffset.map { Int($0) >= 4 && Int($0) < data.count } ?? false

        return .make {
            // Headers (handled_exception_data.md §Request)
            check("Content-Type: application/octet-stream",
                  h(headers, "Content-Type") == "application/octet-stream",
                  detail: h(headers, "Content-Type"))
            check("X-App-License-Key present",      h(headers, "X-App-License-Key") != nil)
            check("X-NewRelic-OS-Name present",      h(headers, "X-NewRelic-OS-Name") != nil,
                  detail: h(headers, "X-NewRelic-OS-Name"))
            check("X-NewRelic-App-Version present",  h(headers, "X-NewRelic-App-Version") != nil,
                  detail: h(headers, "X-NewRelic-App-Version"))

            // FlatBuffer structural checks
            check("Non-empty payload",               !data.isEmpty,        detail: "\(data.count) bytes")
            check("Min FlatBuffer size (≥8 B)",      data.count >= 8,      detail: "\(data.count) bytes")
            check("Root-offset points within buffer",
                  rootOffsetValid,
                  detail: rootOffset.map { "root_offset=\($0), buffer=\(data.count) bytes" })
        }
    }
}

// MARK: - Session replay  /mobile/blobs
//
// Spec: SessionReplayReporter.swift — uploadURL() builds the URL
//
// Top-level query params:
//   type, app_id, protocol_version, timestamp, attributes
//
// "attributes" is a raw key=value&key=value string:
//   entityGuid, isFirstChunk, rrweb.version, payload.type, hasMeta, hasReplay,
//   decompressedBytes, replay.firstTimestamp, replay.lastTimestamp,
//   appVersion, instrumentation.provider, instrumentation.name,
//   instrumentation.version, collector.name  (+ flattened session attributes)

private enum SessionReplayVerifier {
    static func verify(_ data: Data, queryParams: [(String, String)], headers: [String: String]) -> VerificationResult {
        // `data` is already decompressed by NRCaptureServer.capture() when the agent sets
        // Content-Encoding: gzip, so magic-byte checks on `data` are always wrong.
        // Use the header as the authoritative indicator.
        let isGzip = h(headers, "Content-Encoding") == "gzip"

        func q(_ name: String) -> String? { queryParams.first(where: { $0.0 == name })?.1 }

        // Swifter's HTTPParser re-encodes the request URI with .urlQueryAllowed, which
        // excludes '%'. This double-encodes any %3D/%26 in the attributes value to %253D/%2526.
        // URLComponents.queryItems decodes one level, leaving =and & still as %3D/%26.
        // A second removingPercentEncoding pass restores them so the split works correctly.
        let attrs: [String: String] = {
            guard let raw = q("attributes") else { return [:] }
            let decoded = raw.removingPercentEncoding ?? raw
            var d: [String: String] = [:]
            for pair in decoded.components(separatedBy: "&") {
                let parts = pair.components(separatedBy: "=")
                if parts.count >= 2 { d[parts[0]] = parts[1...].joined(separator: "=") }
            }
            return d
        }()

        let firstTS = attrs["replay.firstTimestamp"].flatMap(Double.init)
        let lastTS  = attrs["replay.lastTimestamp"].flatMap(Double.init)

        return .make {
            // Body — data is the decompressed payload; check header for compression, size for success
            check("Non-empty payload",          !data.isEmpty,   detail: "\(data.count) bytes")
            check("Gzip-compressed",            isGzip,          detail: isGzip ? nil : "Content-Encoding header missing or not gzip")
            check("Decompresses cleanly",       isGzip && !data.isEmpty, detail: isGzip ? "\(data.count) bytes" : "no Content-Encoding: gzip")

            // Top-level query params
            check("type == SessionReplay",      q("type") == "SessionReplay",   detail: q("type").map { "was \"\($0)\"" })
            check("app_id present",             q("app_id").map { !$0.isEmpty } == true, detail: q("app_id"))
            check("protocol_version == 0",      q("protocol_version") == "0",   detail: q("protocol_version").map { "was \"\($0)\"" })
            check("timestamp present",          q("timestamp").flatMap(Double.init) != nil, detail: q("timestamp"))

            // Attributes
            check("attributes present",         !attrs.isEmpty)
            check("entityGuid non-empty",       attrs["entityGuid"].map { !$0.isEmpty } == true,      detail: attrs["entityGuid"])
            check("isFirstChunk is bool",       ["true", "false"].contains(attrs["isFirstChunk"]),    detail: attrs["isFirstChunk"])
            check("payload.type == standard",   attrs["payload.type"] == "standard",                  detail: attrs["payload.type"])
            check("hasMeta present",            attrs["hasMeta"] != nil)
            check("hasReplay present",          attrs["hasReplay"] != nil)
            check("decompressedBytes > 0",      attrs["decompressedBytes"].flatMap(Int.init).map { $0 > 0 } == true, detail: attrs["decompressedBytes"])
            check("replay.firstTimestamp valid", firstTS != nil,  detail: attrs["replay.firstTimestamp"])
            check("replay.lastTimestamp valid",  lastTS  != nil,  detail: attrs["replay.lastTimestamp"])
            check("lastTimestamp >= firstTimestamp",
                  firstTS.flatMap { f in lastTS.map { $0 >= f } } == true,
                  detail: firstTS.flatMap { f in lastTS.map { l in "first=\(f) last=\(l)" } })
            check("instrumentation.provider == mobile", attrs["instrumentation.provider"] == "mobile", detail: attrs["instrumentation.provider"])
            check("collector.name present",     attrs["collector.name"] != nil, detail: attrs["collector.name"])

            // Session attributes are flattened into the URL attributes string.
            // Verify the required system keys are present and non-empty.
            // All values are strings here since they come from URL query params.
            sessionAttributeChecks(from: attrs)

            // hasReplay body cross-check: parse the decompressed rrweb event array and
            // verify it is consistent with the URL attribute claims.
            rrwebConsistencyChecks(data: data, attrs: attrs, firstTS: firstTS, lastTS: lastTS)
        }
    }
}

// MARK: - rrweb body consistency
//
// The agent encodes [AnyRRWebEvent] as a JSON array: [{type, timestamp, data}, ...].
// RRWebEventType raw values: 2=fullSnapshot, 3=incrementalSnapshot, 4=meta.
// Incremental source values: 0=mutation, 2=mouseInteraction (touchStart/End), 6=touchMove.
//
// SessionReplayManager sets:
//   firstTimestamp = container.first.timestamp
//   lastTimestamp  = container.last.timestamp
// so the URL attribute timestamps must exactly match the body event range.
// Touch events (source 2 or 6) are excluded from the firstTimestamp comparison
// because they can appear before the first frame event.

private func isTouchEvent(_ event: [String: Any]) -> Bool {
    guard event["type"] as? Int == 3,
          let source = (event["data"] as? [String: Any])?["source"] as? Int
    else { return false }
    return source == 2 || source == 6
}

private func rrwebConsistencyChecks(data: Data,
                                    attrs: [String: String],
                                    firstTS: Double?,
                                    lastTS: Double?) -> [VerificationCheck] {
    guard attrs["hasReplay"] == "true" else { return [] }

    guard let events = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else {
        return [check("hasReplay: body parses as rrweb event array", false,
                      detail: "body is not a JSON array — decompression may have failed")]
    }

    let timestamps        = events.compactMap { ($0["timestamp"] as? NSNumber)?.doubleValue }
    let nonTouchTimestamps = events.filter { !isTouchEvent($0) }
                                   .compactMap { ($0["timestamp"] as? NSNumber)?.doubleValue }
    let types      = events.compactMap { $0["type"] as? Int }
    let bodyFirst  = nonTouchTimestamps.min()
    let bodyLast   = timestamps.max()
    let typeSet    = Array(Set(types)).sorted().map(String.init).joined(separator: ",")

    var result: [VerificationCheck] = [
        check("hasReplay: body parses as rrweb event array",     true),
        check("hasReplay: event count > 0",                      !events.isEmpty,             detail: "\(events.count) events"),
        check("hasReplay: contains snapshot events (type 2/3)",  types.contains(2) || types.contains(3),
              detail: "types present: [\(typeSet)]"),
    ]

    // The URL attrs are built from the sorted container's first/last timestamps, so
    // they should match within floating-point rounding (< 1 ms tolerance is fine;
    // using 1 000 ms to handle any clock skew between capture and attribute building).
    if let first = firstTS {
        result.append(check(
            "hasReplay: firstTimestamp matches body",
            bodyFirst.map { abs($0 - first) < 1_000 } == true,
            detail: "url=\(Int(first))  body=\(bodyFirst.map { Int($0) }.map(String.init) ?? "none")"
        ))
    }
    if let last = lastTS {
        result.append(check(
            "hasReplay: lastTimestamp matches body",
            bodyLast.map { abs($0 - last) < 1_000 } == true,
            detail: "url=\(Int(last))  body=\(bodyLast.map { Int($0) }.map(String.init) ?? "none")"
        ))
    }

    if attrs["hasMeta"] == "true" {
        result.append(check(
            "hasMeta: contains meta events (type 4)",
            types.contains(4),
            detail: "types present: [\(typeSet)]"
        ))
    }

    return result
}
