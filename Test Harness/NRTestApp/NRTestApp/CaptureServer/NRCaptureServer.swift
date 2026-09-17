import Foundation

// MARK: - ResponseOverride

struct ResponseOverride: Equatable, Hashable, Codable {
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

struct StatusInjection: Codable {
    enum Endpoint: String, CaseIterable, Identifiable, Codable {
        case all     = "All"
        case connect = "/connect"
        case data    = "/data"
        case f       = "/mobile/f"
        case blobs   = "/mobile/blobs"
        case logs    = "/mobile/logs"
        case errors  = "/mobile/errors"
        // Crash reports upload once, at the very start of the *next* app launch — arming this
        // takes effect on that next cold launch rather than the current run. Persisted separately
        // so it survives the relaunch; see NRCaptureServer's crash-injection persistence.
        case crash   = "/mobile_crash"

        var id: String { rawValue }

        var displayName: String {
            self == .crash ? "Crash (next launch)" : rawValue
        }

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
    var remaining: Int   // ignored when unlimited == true or randomChance != nil
    var unlimited: Bool
    // Only used when endpoint == .all: how many shots each concrete endpoint category
    // (e.g. "/connect", "/data", "/mobile/blobs") has already been served, so "All" injects
    // into every endpoint independently instead of being exhausted by whichever arrives first.
    var consumedPerCategory: [String: Int] = [:]
    // When set (0...1), each matching request independently rolls this chance of getting the
    // error instead of a normal response — a flaky-network simulation that stays armed until
    // manually disarmed, rather than a fixed number of shots.
    var randomChance: Double? = nil

    var statusCode: Int { override.statusCode }

    func matches(_ requestEndpoint: String) -> Bool {
        endpoint.matches(requestEndpoint)
    }

    var label: String {
        if let chance = randomChance {
            return "\(override.label)  ~\(Int(chance * 100))%  \(endpoint.displayName)"
        }
        let count = unlimited ? "∞" : "×\(remaining)"
        return "\(override.label)  \(count)  \(endpoint.displayName)"
    }
}

// MARK: -

final class NRCaptureServer: ObservableObject {
    static let shared = NRCaptureServer()
    static let port: UInt16 = 8080

    @Published var captures: [CapturedRequest] = []
    // Crash injections are persisted (see didSet) so they survive the relaunch that's needed
    // to actually exercise the one-shot crash upload; other endpoints are in-memory only.
    @Published var injection: StatusInjection? = nil {
        didSet { persistCrashInjectionIfNeeded(oldValue: oldValue) }
    }
    /// True when the connect response config differs from the default.
    @Published var connectConfigMutated: Bool = false

    private static let crashInjectionDefaultsKey = "NRCaptureServer.crashInjection"

    private func persistCrashInjectionIfNeeded(oldValue: StatusInjection?) {
        let defaults = UserDefaults.standard
        if let inj = injection, inj.endpoint == .crash {
            if let data = try? JSONEncoder().encode(inj) {
                defaults.set(data, forKey: Self.crashInjectionDefaultsKey)
            }
        } else if oldValue?.endpoint == .crash {
            defaults.removeObject(forKey: Self.crashInjectionDefaultsKey)
        }
    }

    /// Restores a crash injection armed on a previous launch, before `start()` registers routes
    /// and before the agent's crash uploader (which fires very early) can post to /mobile_crash.
    private func loadPersistedCrashInjection() {
        guard let data = UserDefaults.standard.data(forKey: Self.crashInjectionDefaultsKey),
              let inj = try? JSONDecoder().decode(StatusInjection.self, from: data) else { return }
        injection = inj
    }

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
    /// Returns the override to serve, or nil if no injection applies.
    /// When armed for "All", each concrete endpoint category is tracked and given its own
    /// shots rather than the whole injection being exhausted by whichever endpoint arrives first.
    /// When armed with a random chance, every matching request independently rolls that chance
    /// instead of consuming a fixed number of shots.
    /// Safe to call from any background thread.
    func consumeInjection(for endpoint: String) -> ResponseOverride? {
        var response: ResponseOverride? = nil
        DispatchQueue.main.sync {
            guard var inj = injection, inj.matches(endpoint) else { return }

            // The crash endpoint only fires once, at the very start of the *next* app launch
            // (before this UI can arm anything for the current run) — "All" (deterministic or
            // random) can never actually affect it, so leave it out rather than pretend it's
            // covered. Use the dedicated "Crash (next launch)" endpoint option to test it.
            if inj.endpoint == .all && endpoint == StatusInjection.Endpoint.crash.rawValue { return }

            if let chance = inj.randomChance {
                guard Double.random(in: 0..<1) < chance else { return }
                response = inj.override
                return
            }

            guard inj.endpoint == .all else {
                response = inj.override
                guard !inj.unlimited else { return }
                inj.remaining -= 1
                injection = inj.remaining > 0 ? inj : nil
                return
            }

            let key = Self.injectionCategory(for: endpoint)
            let used = inj.consumedPerCategory[key] ?? 0
            guard inj.unlimited || used < inj.remaining else { return }
            response = inj.override
            if !inj.unlimited {
                inj.consumedPerCategory[key] = used + 1
            }
            injection = inj
        }
        return response
    }

    /// Buckets a concrete request path (which may carry a version, e.g. "/mobile/v5/connect")
    /// into the same category regardless of version, matching StatusInjection.Endpoint's own matching.
    private static func injectionCategory(for requestEndpoint: String) -> String {
        if requestEndpoint.hasSuffix("/connect") { return "/connect" }
        if requestEndpoint.hasSuffix("/data") { return "/data" }
        return requestEndpoint
    }

    private let server = HttpServer()
    @Published private(set) var connectConfig: ConnectConfig = .default

    private init() {
        loadPersistedCrashInjection()
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
            if let override = self?.consumeInjection(for: ep) {
                self?.capture(request, endpoint: ep,
                              responseStatus: override.statusCode, responseHeaders: override.headers, responseBody: "")
                return override.httpResponse()
            }
            let dict = configSnapshot.toServerDict()
            // Store the served config only for successful (non-injected) connects.
            self?.capture(request, endpoint: ep, serverResponse: configSnapshot,
                          responseStatus: 200, responseBody: NRCaptureServer.prettyJSONString(dict))
            return .ok(.json(dict as AnyObject))
        }

        server.POST["/mobile/:version/data"] = { [weak self] request in
            let ep = "/mobile/\(request.params[":version"] ?? "v?")/data"
            if let override = self?.consumeInjection(for: ep) {
                self?.capture(request, endpoint: ep,
                              responseStatus: override.statusCode, responseHeaders: override.headers, responseBody: "")
                return override.httpResponse()
            }
            self?.capture(request, endpoint: ep, responseStatus: 200, responseBody: "{}")
            return .ok(.json([:] as AnyObject))
        }

        // Swifter's trie router picks only one parameter child when multiple exist at the
        // same level (non-deterministic dict ordering). Registering these as literal paths
        // avoids the conflict with the :version parameter used by the connect/data routes.
        for path in ["/mobile/f", "/mobile/blobs", "/mobile/errors", "/mobile/logs"] {
            let ep = path
            server.POST[path] = { [weak self] request in
                if let override = self?.consumeInjection(for: ep) {
                    self?.capture(request, endpoint: ep,
                                  responseStatus: override.statusCode, responseHeaders: override.headers, responseBody: "")
                    return override.httpResponse()
                }
                self?.capture(request, endpoint: ep, responseStatus: 200, responseBody: "{}")
                return .ok(.json([:] as AnyObject))
            }
        }

        // Single-segment catch-all: crash reports (/mobile_crash), anything else
        server.POST["/:path"] = { [weak self] request in
            let ep = "/\(request.params[":path"] ?? "unknown")"
            if let override = self?.consumeInjection(for: ep) {
                self?.capture(request, endpoint: ep,
                              responseStatus: override.statusCode, responseHeaders: override.headers, responseBody: "")
                return override.httpResponse()
            }
            self?.capture(request, endpoint: ep, responseStatus: 200, responseBody: "{}")
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
        let failedResponses: Int
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
                // A failed-response upload is expected to be retried with the same body, so don't
                // let it seed the "seen" set — otherwise the legitimate retry reads as a duplicate.
                guard !capture.endpoint.hasSuffix("/connect"), !capture.hasFailedResponse else {
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
                // The server rejected this upload — there's nothing meaningful to verify
                // about a payload the agent will resend, so leave it unverified.
                guard !capture.hasFailedResponse else {
                    c.verification = nil
                    return c
                }
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
                c.verification = VerificationResult(checks: payloadChecks + configChecks + [dupCheck])
                return c
            }

            let duplicateCount     = isDuplicate.values.filter { $0 }.count
            let failedResponseCount = updated.filter { $0.hasFailedResponse }.count
            let passedCount  = updated.filter { $0.verification?.passed == true }.count
            let failedCount  = updated.filter { $0.verification?.passed == false }.count
            let unverified   = updated.filter { $0.verification == nil && !$0.hasFailedResponse }.count
            let summary = VerifySummary(total: updated.count,
                                        passed: passedCount,
                                        failed: failedCount,
                                        duplicates: duplicateCount,
                                        unverified: unverified,
                                        failedResponses: failedResponseCount)

            DispatchQueue.main.async {
                self.captures = updated
                completion?(summary)
            }
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

    private func capture(_ request: HttpRequest, endpoint: String, serverResponse: ConnectConfig? = nil,
                          responseStatus: Int, responseHeaders: [String: String] = [:], responseBody: String) {
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
            prettyJSON: prettyJSON,
            responseStatusCode: responseStatus,
            responseHeaders: responseHeaders,
            responseBody: responseBody
        )
        captured.serverConnectResponse = serverResponse

        DispatchQueue.main.async { [weak self] in
            self?.captures.insert(captured, at: 0)
        }
    }

    private static func prettyJSONString(_ obj: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted]),
              let str = String(data: data, encoding: .utf8) else { return "{}" }
        return str
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
