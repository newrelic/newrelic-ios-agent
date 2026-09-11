//
//  LedgerStubServer.swift
//  ExpensesTracker
//
//  The local HTTP server that replaces Firebase Realtime Database, plus the failure routes the New
//  Relic test menu needs.
//
//  Serving locally rather than reading the JSON file directly is the whole point: the agent
//  instruments URLSession, so every ledger read and write becomes a real MobileRequest event that can
//  be attributed to the screen that issued it. It also stays deterministic and offline — no external
//  host to go down mid-test, unlike the Android app's reliance on postman-echo.com.
//
//  Routes:
//
//      GET    /income            /expense            → the whole ledger
//      POST   /income            /expense            → insert; body is a LedgerRecord
//      PUT    /income/:id        /expense/:id        → replace
//      DELETE /income/:id        /expense/:id        → remove
//
//      GET    /simulate/slow/:ms                     → responds after :ms, for the slow-network case
//      GET    /simulate/status/:code                 → responds with that status, for HTTP-error cases
//      GET    /simulate/status/:code/:nonce          → same, with a cache-busting nonce so each call
//                                                      is a distinct URL (the "unique" menu items)
//
//  Every mutating route replies with the full ledger, so a caller never has to guess whether its
//  local copy is still right — the same guarantee Firebase's snapshot listeners gave for free.
//
//  Port note: 8081. The collector stub has to own 8080 (the agent only accepts plain HTTP at exactly
//  "localhost:8080"), and HomeSearch's listing server sits on 8082.
//

import Foundation

final class LedgerStubServer {

    static let shared = LedgerStubServer()
    static let port: UInt16 = 8081
    static var baseURL: String { "http://127.0.0.1:\(port)" }

    private let server = HttpServer()
    private var isRunning = false

    /// Guards `ledgers`, which Swifter touches from its own connection queues.
    private let lock = NSLock()
    private var ledgers: [RecordKind: [LedgerRecord]] = [:]

    private init() {}

    // MARK: - URLs

    static func url(for kind: RecordKind, recordID: String? = nil) -> URL {
        var path = "\(baseURL)/\(kind.path)"
        if let recordID {
            path += "/\(recordID)"
        }
        return URL(string: path)!
    }

    static func slowURL(milliseconds: Int) -> URL {
        URL(string: "\(baseURL)/simulate/slow/\(milliseconds)")!
    }

    static func statusURL(_ code: Int, nonce: Int? = nil) -> URL {
        if let nonce {
            return URL(string: "\(baseURL)/simulate/status/\(code)/\(nonce)")!
        }
        return URL(string: "\(baseURL)/simulate/status/\(code)")!
    }

    // MARK: - Lifecycle

    func start() {
        guard !isRunning else { return }

        loadFromDisk()
        seedIfEmpty()
        registerLedgerRoutes()
        registerSimulationRoutes()

        do {
            try server.start(Self.port, forceIPv4: true)
            isRunning = true
            appLog("[ExpensesTracker] Ledger stub server on \(Self.baseURL)")
        } catch {
            appLog("[ExpensesTracker] Ledger stub server failed to start: \(error)")
        }
    }

    func stop() {
        server.stop()
        isRunning = false
    }

    // MARK: - Ledger routes

    private func registerLedgerRoutes() {
        for kind in RecordKind.allCases {
            server.GET["/\(kind.path)"] = { [weak self] _ in
                self?.respondWithLedger(kind) ?? .internalServerError(nil)
            }

            server.POST["/\(kind.path)"] = { [weak self] request in
                guard let self, let record = Self.decodeRecord(request.body) else {
                    return .badRequest(.text("expected a LedgerRecord body"))
                }
                self.mutate(kind) { $0.append(record) }
                return self.respondWithLedger(kind)
            }

            server.PUT["/\(kind.path)/:id"] = { [weak self] request in
                guard let self, let record = Self.decodeRecord(request.body) else {
                    return .badRequest(.text("expected a LedgerRecord body"))
                }
                let id = request.params[":id"] ?? record.id
                self.mutate(kind) { records in
                    if let index = records.firstIndex(where: { $0.id == id }) {
                        records[index] = record
                    } else {
                        records.append(record)
                    }
                }
                return self.respondWithLedger(kind)
            }

            server.DELETE["/\(kind.path)/:id"] = { [weak self] request in
                guard let self else { return .internalServerError(nil) }
                let id = request.params[":id"] ?? ""
                self.mutate(kind) { $0.removeAll { $0.id == id } }
                return self.respondWithLedger(kind)
            }
        }
    }

    /// Routes the New Relic test menu drives. They live on the stub rather than on postman-echo.com,
    /// which is what the Android app used: an external dependency in a failure-injection path means a
    /// test that fails for the wrong reason the day that host is slow.
    private func registerSimulationRoutes() {
        server.GET["/simulate/slow/:ms"] = { request in
            let milliseconds = Int(request.params[":ms"] ?? "") ?? 1000
            Thread.sleep(forTimeInterval: Double(milliseconds) / 1000)
            return .ok(.json(["slept_ms": milliseconds] as AnyObject))
        }

        let statusHandler: (HttpRequest) -> HttpResponse = { request in
            let code = Int(request.params[":code"] ?? "") ?? 500
            let body = Array("{\"error\":\"simulated \(code)\"}".utf8)
            return .raw(code, "Simulated", ["Content-Type": "application/json"]) { writer in
                try writer.write(body)
            }
        }
        server.GET["/simulate/status/:code"] = statusHandler
        server.GET["/simulate/status/:code/:nonce"] = statusHandler
    }

    // MARK: - Responses

    private func respondWithLedger(_ kind: RecordKind) -> HttpResponse {
        lock.lock()
        let records = ledgers[kind] ?? []
        lock.unlock()

        guard let data = try? JSONEncoder().encode(records) else {
            return .internalServerError(nil)
        }
        return .ok(.data(data, contentType: "application/json"))
    }

    private static func decodeRecord(_ body: [UInt8]) -> LedgerRecord? {
        try? JSONDecoder().decode(LedgerRecord.self, from: Data(body))
    }

    // MARK: - State

    private func mutate(_ kind: RecordKind, _ change: (inout [LedgerRecord]) -> Void) {
        lock.lock()
        var records = ledgers[kind] ?? []
        change(&records)
        ledgers[kind] = records
        lock.unlock()

        writeToDisk()
    }

    // MARK: - Persistence

    /// Application Support rather than Documents: this is app-managed state the user never sees as
    /// files, which is exactly the distinction those two directories draw.
    private static var storeURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("ledger.json")
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: Self.storeURL),
              let decoded = try? JSONDecoder().decode([String: [LedgerRecord]].self, from: data) else {
            return
        }
        lock.lock()
        for (rawKind, records) in decoded {
            if let kind = RecordKind(rawValue: rawKind) {
                ledgers[kind] = records
            }
        }
        lock.unlock()
    }

    private func writeToDisk() {
        lock.lock()
        let snapshot = Dictionary(uniqueKeysWithValues: ledgers.map { ($0.key.rawValue, $0.value) })
        lock.unlock()

        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        do {
            try data.write(to: Self.storeURL, options: .atomic)
        } catch {
            appLog("[ExpensesTracker] Could not persist the ledger: \(error)")
        }
    }

    /// A first launch on Android showed empty lists and a zero balance, which makes for a poor first
    /// look at a dashboard and an awkward starting point for a UI test. A handful of records means
    /// every screen has something on it immediately.
    private func seedIfEmpty() {
        lock.lock()
        let isEmpty = (ledgers[.income] ?? []).isEmpty && (ledgers[.expense] ?? []).isEmpty
        lock.unlock()
        guard isEmpty else { return }

        let calendar = Calendar.current
        let now = Date()
        func daysAgo(_ days: Int) -> String {
            LedgerRecord.timestamp(calendar.date(byAdding: .day, value: -days, to: now) ?? now)
        }

        let income = [
            LedgerRecord(amount: 4200, purpose: "Salary", note: "Monthly pay", dateText: daysAgo(6)),
            LedgerRecord(amount: 650, purpose: "Freelance", note: "Logo design", dateText: daysAgo(3)),
            LedgerRecord(amount: 120, purpose: "Dividend", note: "Index fund", dateText: daysAgo(1))
        ]
        let expenses = [
            LedgerRecord(amount: 126, purpose: "Groceries", note: "Weekly shop", dateText: daysAgo(5)),
            LedgerRecord(amount: 45, purpose: "Transport", note: "Fuel", dateText: daysAgo(4)),
            LedgerRecord(amount: 16, purpose: "Entertainment", note: "Streaming", dateText: daysAgo(2)),
            LedgerRecord(amount: 89, purpose: "Utilities", note: "Electricity", dateText: daysAgo(1))
        ]

        lock.lock()
        ledgers[.income] = income
        ledgers[.expense] = expenses
        lock.unlock()

        writeToDisk()
    }
}
