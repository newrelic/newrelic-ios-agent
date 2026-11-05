//
//  NRFileEventStore.swift
//  Agent
//
//  Copyright © 2026 New Relic. All rights reserved.
//

import Foundation

/// File-per-event persisted store for `NREventRecord`s, under
/// `<storePath>/nr_event_cache/`. Each event is its own `<eventUUID>.json` file;
/// `eventIndex.json` lists the UUIDs currently on disk, so replay never needs to
/// list the directory. All reads/writes/deletes run on one serial queue, so a
/// write can never land after -- and resurrect -- a delete for the same event.
final class NRFileEventStore {

    private let directoryURL: URL
    private let indexFileURL: URL
    private let queue = DispatchQueue(label: "com.newrelic.eventpersistence.eventstore")

    init(storePath: String) {
        directoryURL = URL(fileURLWithPath: storePath).appendingPathComponent("nr_event_cache", isDirectory: true)
        indexFileURL = directoryURL.appendingPathComponent("eventIndex.json")
        NREventPersistenceFileSupport.prepareProtectedDirectory(at: directoryURL)
    }

    // MARK: - Index

    private func readIndex() -> [String] {
        guard let data = try? Data(contentsOf: indexFileURL),
              let array = try? JSONSerialization.jsonObject(with: data) as? [String] else {
            return []
        }
        return array
    }

    private func writeIndex(_ eventUUIDs: [String]) {
        guard let data = try? JSONSerialization.data(withJSONObject: eventUUIDs) else { return }
        try? data.write(to: indexFileURL, options: .atomic)
    }

    /// Whether the shadow file lists any persisted events -- the "is the
    /// event shadow file present and non-empty" check from the CDD.
    func hasPersistedRecords() -> Bool {
        queue.sync { !readIndex().isEmpty }
    }

    /// Blocks until every store/delete/evict enqueued so far has finished. Used by tests;
    /// production reads already run on the same queue.
    func synchronize() {
        queue.sync {}
    }

    // MARK: - Store / delete

    func store(_ record: NREventRecord) {
        queue.async { [directoryURL] in
            guard let data = try? JSONSerialization.data(withJSONObject: record.dictionaryRepresentation) else {
                NRLOG_AGENT_ERROR("NREventPersistence: failed to serialize event \(record.eventUUID)")
                return
            }
            let fileURL = directoryURL.appendingPathComponent("\(record.eventUUID).json")
            do {
                try data.write(to: fileURL, options: .atomic)
            } catch {
                NRLOG_AGENT_ERROR("NREventPersistence: failed to write event \(record.eventUUID): \(error)")
                return
            }
            var uuids = self.readIndex()
            if !uuids.contains(record.eventUUID) {
                uuids.append(record.eventUUID)
                self.writeIndex(uuids)
            }
            NRLOG_AGENT_VERBOSE("NREventPersistence: stored event \(record.eventUUID) type=\(record.eventType) session=\(record.sessionId)")
        }
    }

    /// Deletes the given events' on-disk records. Safe to call with UUIDs
    /// that are already gone (e.g. a retention sweep raced a confirm).
    func delete(eventUUIDs: [String]) {
        guard !eventUUIDs.isEmpty else { return }
        queue.async { [directoryURL] in
            let toRemove = Set(eventUUIDs)
            for uuid in toRemove {
                try? FileManager.default.removeItem(at: directoryURL.appendingPathComponent("\(uuid).json"))
            }
            let survivors = self.readIndex().filter { !toRemove.contains($0) }
            self.writeIndex(survivors)
        }
    }

    // MARK: - Fetch

    /// Reads every currently-indexed event record. A record file that's
    /// missing or fails to parse is dropped from the index rather than
    /// retried forever (treated the same as a corrupt/missing manifest --
    /// never block replay on bad storage).
    func fetchAll() -> [NREventRecord] {
        queue.sync { [directoryURL] in
            let uuids = readIndex()
            var records: [NREventRecord] = []
            var corruptUUIDs: [String] = []
            for uuid in uuids {
                if let record = NRFileEventStore.readRecord(uuid: uuid, directoryURL: directoryURL) {
                    records.append(record)
                } else {
                    corruptUUIDs.append(uuid)
                }
            }
            if !corruptUUIDs.isEmpty {
                let survivors = uuids.filter { !corruptUUIDs.contains($0) }
                writeIndex(survivors)
            }
            return records
        }
    }

    // MARK: - Retention

    /// Hard age cap: deletes any record whose own `timestamp` is older than
    /// `maxAgeMs`, regardless of upload/confirmation state. Then evicts the oldest
    /// remaining records (by `timestamp`) if still over `maxCount`.
    func evictRecords(olderThanMs maxAgeMs: Int64, nowMs: Int64, maxCount: Int) {
        queue.async { [directoryURL] in
            let uuids = self.readIndex()
            var survivors: [String] = []
            var timestamps: [String: Int64] = [:]
            var evictedUUIDs: Set<String> = []
            for uuid in uuids {
                guard let record = NRFileEventStore.readRecord(uuid: uuid, directoryURL: directoryURL) else {
                    evictedUUIDs.insert(uuid) // corrupt/missing -- drop from the index too
                    continue
                }
                if nowMs - record.timestamp > maxAgeMs {
                    evictedUUIDs.insert(uuid)
                } else {
                    survivors.append(uuid)
                    timestamps[uuid] = record.timestamp
                }
            }

            if survivors.count > maxCount {
                let overflow = survivors.count - maxCount
                let oldestFirst = survivors.sorted { (timestamps[$0] ?? 0) < (timestamps[$1] ?? 0) }
                for uuid in oldestFirst.prefix(overflow) {
                    evictedUUIDs.insert(uuid)
                }
                survivors.removeAll { evictedUUIDs.contains($0) }
            }

            guard !evictedUUIDs.isEmpty else { return }
            for uuid in evictedUUIDs {
                try? FileManager.default.removeItem(at: directoryURL.appendingPathComponent("\(uuid).json"))
            }
            self.writeIndex(survivors)
        }
    }

    // MARK: - Helpers

    private static func readRecord(uuid: String, directoryURL: URL) -> NREventRecord? {
        let fileURL = directoryURL.appendingPathComponent("\(uuid).json")
        guard let data = try? Data(contentsOf: fileURL),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let record = NREventRecord(dictionary: dict) else {
            return nil
        }
        return record
    }
}
