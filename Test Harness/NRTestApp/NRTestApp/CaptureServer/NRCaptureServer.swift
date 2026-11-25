import Foundation

// MARK: - ResponseOverride

struct ResponseOverride: Equatable, Hashable {
    let statusCode: Int
    let headers: [String: String]

    static let presets: [ResponseOverride] = [
        .init(statusCode: 429, headers: [:]),
        .init(statusCode: 429, headers: ["Retry-After": "30"]),
        .init(statusCode: 500, headers: [:]),
        .init(statusCode: 502, headers: [:]),
        .init(statusCode: 503, headers: [:]),
        .init(statusCode: 504, headers: [:]),
    ]

    var label: String {
        switch statusCode {
        case 409: return "409 Config Update"
        case 429: return headers["Retry-After"].map { "429 – Retry-After: \($0)s" } ?? "429 Too Many Requests"
        case 500: return "500 Internal Server Error"
        case 502: return "502 Bad Gateway"
        case 503: return "503 Service Unavailable"
        case 504: return "504 Gateway Timeout"
        default:  return "\(statusCode) \(HTTPURLResponse.localizedString(forStatusCode: statusCode).capitalized)"
        }
    }

    func httpResponse() -> HttpResponse {
        let phrase: String
        switch statusCode {
        case 409: phrase = "Conflict"
        case 429: phrase = "Too Many Requests"
        case 500: phrase = "Internal Server Error"
        case 502: phrase = "Bad Gateway"
        case 503: phrase = "Service Unavailable"
        case 504: phrase = "Gateway Timeout"
        default:  phrase = HTTPURLResponse.localizedString(forStatusCode: statusCode)
        }
        return .raw(statusCode, phrase, headers.isEmpty ? nil : headers, nil)
    }
}

// MARK: - StatusInjection

struct StatusInjection {
    enum Endpoint: String, CaseIterable, Identifiable {
        case all     = "All"
        case connect = "/connect"
        case data    = "/data"
        case f       = "/mobile/f"
        case blobs   = "/mobile/blobs"
        case logs    = "/mobile/logs"
        case errors  = "/mobile/errors"

        var id: String { rawValue }

        func matches(_ requestEndpoint: String) -> Bool {
            switch self {
            case .all:     return true
            case .connect: return requestEndpoint.hasSuffix("/connect")
            case .data:    return requestEndpoint.hasSuffix("/data")
            default:       return requestEndpoint == rawValue
            }
        }
    }

    var override: ResponseOverride
    var endpoint: Endpoint
    var remaining: Int   // ignored when unlimited == true
    var unlimited: Bool

    var statusCode: Int { override.statusCode }

    func matches(_ requestEndpoint: String) -> Bool {
        endpoint.matches(requestEndpoint)
    }

    var label: String {
        let count = unlimited ? "∞" : "×\(remaining)"
        return "\(override.label)  \(count)  \(endpoint.rawValue)"
    }
}

// MARK: -

final class NRCaptureServer: ObservableObject {
    static let shared = NRCaptureServer()
    static let port: UInt16 = 8080

    /// Newest-first. Persisted to disk so uploads from previous app launches stay visible (and
    /// comparable, e.g. for duplicate recovered events) after a relaunch. Only the current and the
    /// one previous launch are kept. "Clear" empties the file too.
    @Published var captures: [CapturedRequest] = [] {
        didSet { schedulePersist() }
    }
    /// 1-based count of app launches that have run the capture server; stamps each capture.
    let currentLaunch: Int
    @Published var injection: StatusInjection? = nil
    /// True when the connect response config differs from the default.
    @Published var connectConfigMutated: Bool = false

    /// Applies `config` as the connect response and queues a 409 on /data so the agent
    /// reconnects and picks up the new settings on its next harvest cycle.
    func setConnectConfig(_ config: ConnectConfig) {
        connectConfig = config
        connectConfigMutated = true
        armConfigUpdate409()
    }

    /// Resets the connect response config to defaults and queues a 409 on /data so the
    /// agent reconnects and picks up the default settings.
    func resetConnectConfig() {
        connectConfig = .default
        connectConfigMutated = false
        armConfigUpdate409()
    }

    private func armConfigUpdate409() {
        injection = StatusInjection(
            override: .init(statusCode: 409, headers: [:]),
            endpoint: .data,
            remaining: 1,
            unlimited: false
        )
    }

    /// Atomically consumes one shot of the active injection if it matches `endpoint`.
    /// Returns the HttpResponse to send, or nil if no injection applies.
    /// Safe to call from any background thread.
    func consumeInjection(for endpoint: String) -> HttpResponse? {
        var response: HttpResponse? = nil
        DispatchQueue.main.sync {
            guard var inj = injection, inj.matches(endpoint) else { return }
            response = inj.override.httpResponse()
            guard !inj.unlimited else { return }
            inj.remaining -= 1
            injection = inj.remaining > 0 ? inj : nil
        }
        return response
    }

    private let server = HttpServer()
    @Published private(set) var connectConfig: ConnectConfig = .default

    private init() {
        let key = "NRCaptureServer.launchCount"
        let launch = UserDefaults.standard.integer(forKey: key) + 1
        UserDefaults.standard.set(launch, forKey: key)
        currentLaunch = launch
        // Keep only the previous launch's uploads; anything older is dropped.
        captures = NRCaptureServer.loadPersisted().filter { $0.launch >= launch - 1 }
    }

    // MARK: Persistence

    private static let maxPersistedCaptures = 500
    private let persistQueue = DispatchQueue(label: "NRCaptureServer.persist", qos: .utility)
    private var persistPending = false

    private static var persistURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("NRCaptureServer-captures.json")
    }

    private static func loadPersisted() -> [CapturedRequest] {
        guard let data = try? Data(contentsOf: persistURL),
              let stored = try? JSONDecoder().decode([PersistedCapture].self, from: data) else { return [] }
        return stored.map(\.capture)
    }

    /// Coalesces bursts of changes into one write of the latest `captures`.
    private func schedulePersist() {
        guard !persistPending else { return }
        persistPending = true
        persistQueue.asyncAfter(deadline: .now() + 1) { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }
                self.persistPending = false
                let stored = self.captures.filter { $0.launch >= self.currentLaunch - 1 }.prefix(NRCaptureServer.maxPersistedCaptures).map(PersistedCapture.init)
                self.persistQueue.async {
                    if let data = try? JSONEncoder().encode(stored) {
                        try? data.write(to: NRCaptureServer.persistURL, options: .atomic)
                    }
                }
            }
        }
    }

    func start() {
        // connectConfig is a typed ConnectConfig stored property.
        // The connect handler snapshots it, optionally replaces it, then serves.

        server.POST["/mobile/:version/connect"] = { [weak self] request in
            let ep = "/mobile/\(request.params[":version"] ?? "v?")/connect"
            // Snapshot the live config before checking for an injection so the config
            // set via setConnectConfig() is always what a successful connect returns.
            var configSnapshot: ConnectConfig = .default
            DispatchQueue.main.sync { configSnapshot = self?.connectConfig ?? .default }
            let injected = self?.consumeInjection(for: ep)
            // Store the served config only for successful (non-injected) connects.
            self?.capture(request, endpoint: ep,
                          serverResponse: injected == nil ? configSnapshot : nil)
            return injected ?? .ok(.json(configSnapshot.toServerDict() as AnyObject))
        }

        server.POST["/mobile/:version/data"] = { [weak self] request in
            let ep = "/mobile/\(request.params[":version"] ?? "v?")/data"
            self?.capture(request, endpoint: ep)
            if let injected = self?.consumeInjection(for: ep) { return injected }
            return .ok(.json([:] as AnyObject))
        }

        // Swifter's trie router picks only one parameter child when multiple exist at the
        // same level (non-deterministic dict ordering). Registering these as literal paths
        // avoids the conflict with the :version parameter used by the connect/data routes.
        for path in ["/mobile/f", "/mobile/blobs", "/mobile/errors", "/mobile/logs"] {
            let ep = path
            server.POST[path] = { [weak self] request in
                self?.capture(request, endpoint: ep)
                if let injected = self?.consumeInjection(for: ep) { return injected }
                return .ok(.json([:] as AnyObject))
            }
        }

        // Single-segment catch-all: crash reports (/mobile_crash), anything else
        server.POST["/:path"] = { [weak self] request in
            let ep = "/\(request.params[":path"] ?? "unknown")"
            self?.capture(request, endpoint: ep)
            if let injected = self?.consumeInjection(for: ep) { return injected }
            return .ok(.json([:] as AnyObject))
        }

        do {
            try server.start(NRCaptureServer.port, forceIPv4: true)
            print("[NRCapture] Listening on port \(NRCaptureServer.port)")
        } catch {
            print("[NRCapture] Failed to start server: \(error)")
        }
    }

    func stop() {
        server.stop()
    }

    struct VerifySummary {
        let total: Int
        let passed: Int
        let failed: Int
        let duplicates: Int
        let unverified: Int
    }

    func verifyAll(completion: ((VerifySummary) -> Void)? = nil) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let snapshot = self.captures  // newest-first

            // Duplicate detection: walk chronologically (oldest first).
            // Use Set<Data> for O(1) membership tests — important for large binary payloads
            // like hex FlatBuffers where linear Data comparison would be O(n × payload_size).
            // Also record the first-seen timestamp so the duplicate check can show which
            // earlier upload it matches.
            var seenBodies: [String: Set<Data>] = [:]
            var firstSeenAt: [String: [Data: Date]] = [:]   // endpoint → body → first timestamp
            var isDuplicate: [UUID: Bool] = [:]
            var duplicateOf: [UUID: Date] = [:]             // timestamp of the original upload

            for capture in snapshot.reversed() {
                // Connect payloads are structurally identical across sessions — skip duplicate detection.
                guard !capture.endpoint.hasSuffix("/connect") else {
                    isDuplicate[capture.id] = false
                    continue
                }
                let key = capture.endpoint
                if seenBodies[key, default: []].contains(capture.decodedBody) {
                    isDuplicate[capture.id] = true
                    duplicateOf[capture.id] = firstSeenAt[key]?[capture.decodedBody]
                } else {
                    isDuplicate[capture.id] = false
                    seenBodies[key, default: []].insert(capture.decodedBody)
                    firstSeenAt[key, default: [:]][capture.decodedBody] = capture.timestamp
                }
            }

            // Event ledger: events tagged by the app's persistence scenario (nrTestRun + nrTestSeq)
            // are identifiable across uploads, which the payload alone isn't (eventUUID is never
            // sent). Flag any tagged event that shows up in more than one place.
            var ledgerSeen: Set<String> = []
            var ledgerDuplicates: [UUID: [String]] = [:]
            var ledgerTagged: Set<UUID> = []
            for capture in snapshot.reversed() where capture.endpoint.hasSuffix("/data") {
                let keys = NRCaptureServer.taggedEventKeys(in: capture.decodedBody)
                guard !keys.isEmpty else { continue }
                ledgerTagged.insert(capture.id)
                let repeats = keys.filter { !ledgerSeen.insert($0).inserted }
                if !repeats.isEmpty { ledgerDuplicates[capture.id] = repeats }
            }

            // Events recovered from a previous session, and whether any was already delivered earlier.
            let recoveredChecks = NRCaptureServer.recoveredEventChecks(for: snapshot)

            // Compute the effective ConnectConfig at each capture's moment (chronological walk).
            // Used to verify the agent respects configuration settings (e.g. session_replay.enabled).
            var configAtCapture: [UUID: ConnectConfig] = [:]
            var runningConfig: ConnectConfig? = nil
            for capture in snapshot.reversed() {
                if let resp = capture.serverConnectResponse {
                    runningConfig = resp
                }
                configAtCapture[capture.id] = runningConfig
            }

            let updated = snapshot.map { capture -> CapturedRequest in
                var c = capture
                let payloadChecks = verify(data: capture.decodedBody, endpoint: capture.endpoint, queryParams: capture.queryParams, headers: capture.headers)?.checks ?? []
                let configChecks  = self.configBehaviorChecks(capture: capture, config: configAtCapture[capture.id])
                let detail: String?
                if isDuplicate[capture.id] == true {
                    if let original = duplicateOf[capture.id] {
                        let fmt = DateFormatter()
                        fmt.timeStyle = .medium
                        detail = "Duplicate of upload at \(fmt.string(from: original)) (\(capture.decodedBody.count) bytes)"
                    } else {
                        detail = "Identical body already sent to this endpoint (\(capture.decodedBody.count) bytes)"
                    }
                } else {
                    detail = nil
                }
                let dupCheck = VerificationCheck(
                    name: "No duplicate payload",
                    passed: isDuplicate[capture.id] == false,
                    detail: detail
                )
                var ledgerChecks: [VerificationCheck] = []
                if ledgerTagged.contains(capture.id) {
                    let repeats = ledgerDuplicates[capture.id]
                    ledgerChecks.append(VerificationCheck(
                        name: "Event ledger: no tagged event delivered twice",
                        passed: repeats == nil,
                        detail: repeats.map { "Already delivered earlier: \($0.joined(separator: ", "))" }
                    ))
                }
                let recoveredCheck = recoveredChecks[capture.id].map { [$0] } ?? []
                c.verification = VerificationResult(checks: payloadChecks + configChecks + ledgerChecks + recoveredCheck + [dupCheck])
                return c
            }

            let duplicateCount = isDuplicate.values.filter { $0 }.count
            let passedCount  = updated.filter { $0.verification?.passed == true }.count
            let failedCount  = updated.filter { $0.verification?.passed == false }.count
            let unverified   = updated.filter { $0.verification == nil }.count
            let summary = VerifySummary(total: updated.count,
                                        passed: passedCount,
                                        failed: failedCount,
                                        duplicates: duplicateCount,
                                        unverified: unverified)

            DispatchQueue.main.async {
                self.captures = updated
                completion?(summary)
            }
        }
    }

    static let recoveredEventsCheckName = "Recovered events: from a previous session, none delivered before"

    /// For each /data upload carrying events whose `sessionId` differs from the upload's own session
    /// (`[8].sessionId`) -- i.e. events recovered from an earlier launch -- reports where they came
    /// from and fails if any was already delivered in an earlier upload (live, or recovered before).
    /// Live events don't carry session attributes inline, so a match is: same eventType and timestamp,
    /// and one event's attributes are a subset of the other's. `captures` is newest-first.
    static func recoveredEventChecks(for captures: [CapturedRequest]) -> [UUID: VerificationCheck] {
        var delivered: [String: [[String: Any]]] = [:]   // "eventType|timestamp" → events from earlier uploads
        var results: [UUID: VerificationCheck] = [:]

        func bucketKey(_ event: [String: Any]) -> String {
            "\(event["eventType"] ?? "")|\(event["timestamp"] ?? "")"
        }
        func isSubset(_ small: [String: Any], of big: [String: Any]) -> Bool {
            small.allSatisfy { key, value in
                guard let other = big[key] else { return false }
                return (value as AnyObject).isEqual(other)
            }
        }

        for capture in captures.reversed() where capture.endpoint.hasSuffix("/data") {
            guard let root = try? JSONSerialization.jsonObject(with: capture.decodedBody) as? [Any],
                  root.indices.contains(9),
                  let events = root[9] as? [[String: Any]] else { continue }
            let uploadSession = (root.indices.contains(8) ? (root[8] as? [String: Any])?["sessionId"] as? String : nil)

            var recovered: [[String: Any]] = []
            var alreadyDelivered: [String] = []
            for event in events {
                if let uploadSession, let eventSession = event["sessionId"] as? String, eventSession != uploadSession {
                    recovered.append(event)
                    let seenBefore = delivered[bucketKey(event), default: []].contains {
                        isSubset($0, of: event) || isSubset(event, of: $0)
                    }
                    if seenBefore {
                        alreadyDelivered.append("\(event["eventType"] ?? "?") @\(event["timestamp"] ?? "?") (session \(eventSession))")
                    }
                }
            }
            // Record after checking, so events within one upload don't flag each other.
            for event in events { delivered[bucketKey(event), default: []].append(event) }

            guard !recovered.isEmpty else { continue }
            let sessions = Set(recovered.compactMap { $0["sessionId"] as? String }).sorted()
            let types = Dictionary(grouping: recovered, by: { $0["eventType"] as? String ?? "?" })
                .map { "\($0.key)×\($0.value.count)" }.sorted().joined(separator: ", ")
            let comparedAgainst = delivered.values.reduce(0) { $0 + $1.count } - events.count
            let origin = "\(recovered.count) recovered from session\(sessions.count == 1 ? "" : "s") \(sessions.joined(separator: ", ")): \(types)"
            results[capture.id] = VerificationCheck(
                name: recoveredEventsCheckName,
                passed: alreadyDelivered.isEmpty,
                detail: alreadyDelivered.isEmpty
                    ? origin + (comparedAgainst > 0 ? "" : " (no earlier uploads captured to compare against)")
                    : "\(origin). Already delivered in an earlier upload: \(alreadyDelivered.joined(separator: "; "))")
        }
        return results
    }

    /// "<nrTestRun>/<nrTestSeq>" for every tagged analytics event in a /data body ([9] of the root array).
    static func taggedEventKeys(in body: Data) -> [String] {
        guard let root = try? JSONSerialization.jsonObject(with: body) as? [Any],
              root.indices.contains(9),
              let events = root[9] as? [[String: Any]] else { return [] }
        return events.compactMap { event in
            guard let run = event["nrTestRun"] as? String, let seq = event["nrTestSeq"] as? String else { return nil }
            return "\(run)/\(seq)"
        }
    }

    // MARK: - Private

    /// Checks that the agent respected the active ConnectConfig when it made this upload.
    /// Returns a failing check if a feature was disabled in the config but the agent uploaded anyway.
    private func configBehaviorChecks(capture: CapturedRequest, config: ConnectConfig?) -> [VerificationCheck] {
        guard let config else { return [] }
        let sr   = config.configuration.sessionReplay
        let logs = config.configuration.logs
        var checks: [VerificationCheck] = []

        if capture.endpoint == "/mobile/blobs" && !sr.enabled {
            checks.append(VerificationCheck(
                name: "config: session_replay.enabled=false — unexpected SR upload",
                passed: false,
                detail: "Agent uploaded session replay after connect config disabled it"
            ))
        }
        if capture.endpoint == "/mobile/logs" && !logs.enabled {
            checks.append(VerificationCheck(
                name: "config: logs.enabled=false — unexpected log upload",
                passed: false,
                detail: "Agent uploaded logs after connect config disabled them"
            ))
        }
        return checks
    }

    private func capture(_ request: HttpRequest, endpoint: String, serverResponse: ConnectConfig? = nil) {
        let bodyData = Data(request.body)
        let isGzip = request.headers["content-encoding"] == "gzip"
        let decoded = isGzip ? bodyData.gunzipped() ?? bodyData : bodyData

        let prettyJSON: String
        if let json = try? JSONSerialization.jsonObject(with: decoded),
           let pretty = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted]),
           let str = String(data: pretty, encoding: .utf8) {
            prettyJSON = str
        } else {
            prettyJSON = String(data: decoded, encoding: .utf8) ?? "(binary data, \(decoded.count) bytes)"
        }

        var captured = CapturedRequest(
            timestamp: Date(),
            endpoint: endpoint,
            headers: request.headers,
            queryParams: request.queryParams,
            decodedBody: decoded,
            prettyJSON: prettyJSON
        )
        captured.serverConnectResponse = serverResponse
        captured.launch = currentLaunch

        DispatchQueue.main.async { [weak self] in
            self?.captures.insert(captured, at: 0)
        }
    }
}

// MARK: - Gzip decompression via zlib (available through bridging header)

extension Data {
    func gunzipped() -> Data? {
        guard count > 18 else { return nil }

        var result = Data(capacity: count * 4)
        var stream = z_stream()
        stream.next_in = UnsafeMutablePointer<Bytef>(
            mutating: (self as NSData).bytes.assumingMemoryBound(to: Bytef.self)
        )
        stream.avail_in = uInt(count)

        // MAX_WBITS + 16 tells zlib to decode gzip format
        guard inflateInit2_(&stream, MAX_WBITS + 16, ZLIB_VERSION,
                            Int32(MemoryLayout<z_stream>.size)) == Z_OK else { return nil }
        defer { inflateEnd(&stream) }

        var buf = [Bytef](repeating: 0, count: 65536)
        var status: Int32
        repeat {
            status = buf.withUnsafeMutableBufferPointer { ptr in
                stream.next_out = ptr.baseAddress
                stream.avail_out = uInt(ptr.count)
                return inflate(&stream, Z_SYNC_FLUSH)
            }
            guard status == Z_OK || status == Z_STREAM_END else { return nil }
            result.append(contentsOf: buf.prefix(buf.count - Int(stream.avail_out)))
        } while status != Z_STREAM_END

        return result
    }
}
