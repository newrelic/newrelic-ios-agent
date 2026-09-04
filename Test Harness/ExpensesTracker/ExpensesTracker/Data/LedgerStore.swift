//
//  LedgerStore.swift
//  ExpensesTracker
//
//  Stands in for the Firebase Realtime Database, and is the app's only source of records.
//
//  The Android app read and wrote through DatabaseReference, with `addValueEventListener` pushing new
//  snapshots into every screen whenever anything changed. Two things about that shape are worth
//  keeping and one is worth dropping:
//
//    keep — every write goes over the wire. The agent instruments URLSession, so a real request to
//           LedgerStubServer produces a genuine MobileRequest event that can be attributed to the
//           screen that issued it. Reading and writing a local file directly would produce no
//           network events at all, and network events are half of what this app exists to generate.
//
//    keep — screens observe rather than poll. `changes` is an AsyncStream; a screen that wants to
//           follow the ledger awaits it, which is the same contract addValueEventListener offered.
//
//    drop — the offline-cache-of-record. Android called keepSynced(true) and let Firebase decide what
//           was authoritative. Here the JSON file on disk is authoritative and the server reads from
//           it, so there is exactly one copy of the truth and a relaunch shows what you last saved.
//
//  Everything is confined to the main actor. The lists, totals and dialogs all touch it from the main
//  thread anyway, and an actor of its own would buy nothing but await noise.
//

import Foundation
import NewRelic

@MainActor
final class LedgerStore {

    static let shared = LedgerStore()

    private(set) var income: [LedgerRecord] = []
    private(set) var expenses: [LedgerRecord] = []
    private var hasLoaded = false

    /// Screens observe this instead of being told to refresh. Each continuation is a live observer;
    /// they are dropped when their consumer's task ends.
    private var observers: [UUID: AsyncStream<Void>.Continuation] = [:]

    private let session = URLSession(configuration: .default)

    private init() {}

    // MARK: - Observation

    var changes: AsyncStream<Void> {
        AsyncStream { continuation in
            let id = UUID()
            observers[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in self?.observers[id] = nil }
            }
        }
    }

    private func notifyObservers() {
        for continuation in observers.values {
            continuation.yield()
        }
    }

    // MARK: - Reading

    func records(for kind: RecordKind) -> [LedgerRecord] {
        switch kind {
        case .income:  return income
        case .expense: return expenses
        }
    }

    func total(for kind: RecordKind) -> Double {
        records(for: kind).reduce(0) { $0 + Double($1.amount) }
    }

    /// Income minus expenses, as the Android dashboard computed it — except that it did so by parsing
    /// the two labels it had already written into the UI, comma separators and all. Reading numbers
    /// back out of text it just formatted is exactly the kind of thing this port should not preserve.
    var balance: Double {
        total(for: .income) - total(for: .expense)
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await reload()
    }

    func reload() async {
        for kind in RecordKind.allCases {
            await fetch(kind)
        }
        hasLoaded = true
        notifyObservers()
    }

    private func fetch(_ kind: RecordKind) async {
        let url = LedgerStubServer.url(for: kind)
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            let records = try JSONDecoder().decode([LedgerRecord].self, from: data)
            apply(records, to: kind)
        } catch {
            ErrorReporter.reportHandled(error,
                                        source: "LedgerStore.fetch",
                                        additionalInfo: "kind=\(kind.rawValue) url=\(url.absoluteString)")
        }
    }

    private func apply(_ records: [LedgerRecord], to kind: RecordKind) {
        switch kind {
        case .income:  income = records
        case .expense: expenses = records
        }
    }

    // MARK: - Writing

    /// Android: `database.child(id).setValue(data)` — an insert with a generated key.
    func add(_ record: LedgerRecord, to kind: RecordKind) async {
        await send(.post, kind: kind, record: record)
    }

    /// Android: `database.child(post_key).setValue(dat)` — the update dialog reused the same call, so
    /// an update and an insert were indistinguishable. Here an update is a PUT, which makes the two
    /// legible apart in the request events.
    func update(_ record: LedgerRecord, in kind: RecordKind) async {
        await send(.put, kind: kind, record: record)
    }

    /// Android: `database.child(post_key).removeValue()`.
    func delete(_ record: LedgerRecord, from kind: RecordKind) async {
        await send(.delete, kind: kind, record: record)
    }

    private enum Method: String {
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
    }

    private func send(_ method: Method, kind: RecordKind, record: LedgerRecord) async {
        var request = URLRequest(url: LedgerStubServer.url(for: kind, recordID: method == .post ? nil : record.id))
        request.httpMethod = method.rawValue

        if method != .delete {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONEncoder().encode(record)
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            let records = try JSONDecoder().decode([LedgerRecord].self, from: data)
            apply(records, to: kind)
            notifyObservers()

            NewRelic.logDebug("LedgerStore: \(method.rawValue) \(kind.rawValue) → \(records.count) record(s)")
        } catch {
            ErrorReporter.reportHandled(error,
                                        source: "LedgerStore.\(method.rawValue.lowercased())",
                                        additionalInfo: "kind=\(kind.rawValue) id=\(record.id)")
        }
    }
}
