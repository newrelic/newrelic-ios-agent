import Foundation

final class NRCaptureServer: ObservableObject {
    static let shared = NRCaptureServer()
    static let port: UInt16 = 8080

    @Published var captures: [CapturedRequest] = []

    private let server = HttpServer()

    private init() {}

    func start() {
        let connectResponse: [String: Any] = [
            "server_timestamp": 1656525980,
            "data_report_period": 60,
            "report_max_transaction_count": 1000,
            "report_max_transaction_age": 600,
            "collect_network_errors": true,
            "error_limit": 50,
            "response_body_limit": 2048,
            "stack_trace_limit": 100,
            "at_capture": [1, []],
            "data_token": [111111111, 222222222],
            "cross_process_id": "AAAAAAAAAAAAAAAAAAAAAA==",
            "encoding_key": "0000000000000000000000000000000000000000",
            "account_id": "1",
            "application_id": "1",
            // Required by SessionReplayReporter.uploadURL() to build a non-empty entityGuid attribute.
            "entity_guid": "AAAAAAAAAAAAAAAAAAAAAA==",
            "configuration": [
                // Enable session replay at 100% sample rate so it records unconditionally in capture mode.
                "session_replay": [
                    "enabled": true,
                    "sampling_rate": 100.0,
                    "error_sampling_rate": 100.0,
                    // "default" masks text and images; "custom" uses the explicit flags below.
                    "mode": "custom",
                    "mask_application_text": false,
                    "mask_user_input_text": false,
                    "mask_all_images": false,
                    "mask_all_user_touches": false,
                    // Each rule: identifier ("tag" | "class"), type ("mask" | "unmask"),
                    // name is an NSArray — pass as a JSON array even for a single value.
                    "custom_masking_rules": [
                        ["identifier": "tag",   "type": "mask",   "name": ["sensitiveField"]],
                        ["identifier": "class", "type": "mask",   "name": ["UITextField"]],
                        ["identifier": "class", "type": "unmask", "name": ["NRUnmaskedLabel"]]
                    ]
                ],
                // Enable log reporting so /mobile/logs uploads are captured.
                "logs": [
                    "enabled": true,
                    "level": "DEBUG",
                    "sampling_rate": 100.0
                ]
            ]
        ]

        server.POST["/mobile/:version/connect"] = { [weak self] request in
            let ep = "/mobile/\(request.params[":version"] ?? "v?")/connect"
            self?.capture(request, endpoint: ep)
            return .ok(.json(connectResponse as AnyObject))
        }

        server.POST["/mobile/:version/data"] = { [weak self] request in
            let ep = "/mobile/\(request.params[":version"] ?? "v?")/data"
            self?.capture(request, endpoint: ep)
            return .ok(.json([:] as AnyObject))
        }

        // Swifter's trie router picks only one parameter child when multiple exist at the
        // same level (non-deterministic dict ordering). Registering these as literal paths
        // avoids the conflict with the :version parameter used by the connect/data routes.
        for path in ["/mobile/f", "/mobile/blobs", "/mobile/errors", "/mobile/logs"] {
            let ep = path
            server.POST[path] = { [weak self] request in
                self?.capture(request, endpoint: ep)
                return .ok(.json([:] as AnyObject))
            }
        }

        // Single-segment catch-all: crash reports (/mobile_crash), anything else
        server.POST["/:path"] = { [weak self] request in
            let ep = "/\(request.params[":path"] ?? "unknown")"
            self?.capture(request, endpoint: ep)
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

            let updated = snapshot.map { capture -> CapturedRequest in
                var c = capture
                let payloadChecks = verify(data: capture.decodedBody, endpoint: capture.endpoint, queryParams: capture.queryParams, headers: capture.headers)?.checks ?? []
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
                c.verification = VerificationResult(checks: payloadChecks + [dupCheck])
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

    // MARK: - Private

    private func capture(_ request: HttpRequest, endpoint: String) {
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

        let captured = CapturedRequest(
            timestamp: Date(),
            endpoint: endpoint,
            headers: request.headers,
            queryParams: request.queryParams,
            decodedBody: decoded,
            prettyJSON: prettyJSON
        )

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
