//
//  NRFileEventStore.swift
//  Agent
//
//  Copyright © 2026 New Relic. All rights reserved.
//

import Foundation
@_implementationOnly import NewRelicPrivate

/// File-per-event persisted store for `NREventRecord`s, laid out as
/// `<storePath>/nr_event_cache/<sessionId>/<eventUUID>.json` (see `NREventPersistenceFileSupport`).
/// The files are the only persisted state -- there is no index -- so a record is either fully
/// on disk or not there at all. All reads/writes/deletes run on one serial queue, so a write can
/// never land after -- and resurrect -- a delete for the same event.
final class NRFileEventStore {

    private let rootURL: URL
    private let queue = DispatchQueue(label: "com.newrelic.eventpersistence.eventstore")

    // eventUUID -> session directory name. A cache of what is on disk, built by one directory
    // scan on first use and kept in step by store/delete; it exists so a delete-by-UUID needn't
    // search every session directory. Only touched on `queue`.
    private var sessionDirectoryByUUID: [String: String]?

    init(storePath: String) {
        rootURL = NREventPersistenceFileSupport.rootURL(storePath: storePath)
        NREventPersistenceFileSupport.prepareProtectedDirectory(at: rootURL)
    }

    // MARK: - Layout (queue-confined)

    private func sessionDirectoryURL(_ name: String) -> URL {
        rootURL.appendingPathComponent(name, isDirectory: true)
    }

    private func fileURL(uuid: String, sessionDirectory: String) -> URL {
        sessionDirectoryURL(sessionDirectory)
            .appendingPathComponent("\(NREventPersistenceFileSupport.encodedName(uuid)).json")
    }

    private func scannedIndex() -> [String: String] {
        if let sessionDirectoryByUUID { return sessionDirectoryByUUID }
        var map: [String: String] = [:]
        let fileManager = FileManager.default
        let sessionDirs = (try? fileManager.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: nil)) ?? []
        for dir in sessionDirs {
            let files = (try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
            for file in files where file.pathExtension == "json"
                && file.lastPathComponent != NREventPersistenceFileSupport.manifestFileName {
                let uuid = NREventPersistenceFileSupport.decodedName(file.deletingPathExtension().lastPathComponent)
                map[uuid] = dir.lastPathComponent
            }
        }
        sessionDirectoryByUUID = map
        return map
    }

    /// Removes the files for `uuids`, drops them from the cache, and removes any session
    /// directory left empty. Safe for UUIDs that are already gone.
    private func removeFiles(forUUIDs uuids: Set<String>) {
        var index = scannedIndex()
        var touchedDirectories: Set<String> = []
        for uuid in uuids {
            guard let directory = index.removeValue(forKey: uuid) else { continue }
            try? FileManager.default.removeItem(at: fileURL(uuid: uuid, sessionDirectory: directory))
            touchedDirectories.insert(directory)
        }
        sessionDirectoryByUUID = index
        for directory in touchedDirectories {
            NREventPersistenceFileSupport.removeDirectoryIfEmpty(sessionDirectoryURL(directory))
        }
    }

    /// Whether any event is persisted -- the "is the event shadow file present and non-empty"
    /// check from the CDD.
    func hasPersistedRecords() -> Bool {
        queue.sync { !scannedIndex().isEmpty }
    }

    /// Session ids that currently have at least one persisted event.
    func sessionIdsWithEvents() -> Set<String> {
        queue.sync { Set(scannedIndex().values.map { NREventPersistenceFileSupport.decodedName($0) }) }
    }

    /// Blocks until every store/delete/evict enqueued so far has finished. Used by tests;
    /// production reads already run on the same queue.
    func synchronize() {
        queue.sync {}
    }

    // MARK: - Store / delete

    func store(_ record: NREventRecord) {
        queue.async {
            guard let data = try? NRMAJSON.data(withJSONObject: record.dictionaryRepresentation, options: []) else {
                NRLOG_AGENT_ERROR("NREventPersistence: failed to serialize event \(record.eventUUID)")
                return
            }
            var index = self.scannedIndex()
            let directory = NREventPersistenceFileSupport.encodedName(record.sessionId)
            let url = self.fileURL(uuid: record.eventUUID, sessionDirectory: directory)
            do {
                do {
                    try data.write(to: url, options: .atomic)
                } catch {
                    // First event of the session, or the directory was removed while empty.
                    NREventPersistenceFileSupport.prepareProtectedDirectory(at: self.sessionDirectoryURL(directory))
                    try data.write(to: url, options: .atomic)
                }
            } catch {
                NRLOG_AGENT_ERROR("NREventPersistence: failed to write event \(record.eventUUID): \(error)")
                return
            }
            index[record.eventUUID] = directory
            self.sessionDirectoryByUUID = index
            NRLOG_AGENT_VERBOSE("NREventPersistence: stored event \(record.eventUUID) type=\(record.eventType) session=\(record.sessionId)")
        }
    }

    /// Deletes the given events' on-disk records. Safe to call with UUIDs
    /// that are already gone (e.g. a retention sweep raced a confirm).
    func delete(eventUUIDs: [String]) {
        guard !eventUUIDs.isEmpty else { return }
        queue.async {
            self.removeFiles(forUUIDs: Set(eventUUIDs))
        }
    }

    // MARK: - Fetch

    /// Reads every persisted event, oldest first. A record file that fails to parse is deleted
    /// rather than retried forever (treated the same as a corrupt/missing manifest -- never
    /// block replay on bad storage).
    func fetchAll() -> [NREventRecord] {
        queue.sync { loadAllRecords() }
    }

    /// Queue-confined body of `fetchAll()`, shared with `claim(where:)` and retention.
    private func loadAllRecords() -> [NREventRecord] {
        var records: [NREventRecord] = []
        var corruptUUIDs: Set<String> = []
        for (uuid, directory) in scannedIndex() {
            if let record = NRFileEventStore.readRecord(at: fileURL(uuid: uuid, sessionDirectory: directory)) {
                records.append(record)
            } else {
                corruptUUIDs.insert(uuid)
            }
        }
        if !corruptUUIDs.isEmpty {
            removeFiles(forUUIDs: corruptUUIDs)
        }
        return records.sorted { ($0.timestamp, $0.eventUUID) < ($1.timestamp, $1.eventUUID) }
    }

    /// Atomically reads and deletes every record matching `predicate`: the read and the
    /// delete run as one step on the store's queue, so two concurrent claims can never both
    /// receive the same record.
    func claim(where predicate: (NREventRecord) -> Bool) -> [NREventRecord] {
        queue.sync {
            let claimed = loadAllRecords().filter(predicate)
            guard !claimed.isEmpty else { return [] }
            removeFiles(forUUIDs: Set(claimed.map { $0.eventUUID }))
            return claimed
        }
    }

    // MARK: - Retention

    /// Hard age cap: deletes any record whose own `timestamp` is older than
    /// `maxAgeMs`, regardless of upload/confirmation state. Then evicts the oldest
    /// remaining records (by `timestamp`) if still over `maxCount`.
    func evictRecords(olderThanMs maxAgeMs: Int64, nowMs: Int64, maxCount: Int) {
        queue.async {
            let records = self.loadAllRecords()   // oldest first; unreadable ones are already gone
            var evicted: Set<String> = []
            var survivors: [NREventRecord] = []
            for record in records {
                if nowMs - record.timestamp > maxAgeMs {
                    evicted.insert(record.eventUUID)
                } else {
                    survivors.append(record)
                }
            }
            if survivors.count > maxCount {
                for record in survivors.prefix(survivors.count - maxCount) {
                    evicted.insert(record.eventUUID)
                }
            }
            if !evicted.isEmpty {
                self.removeFiles(forUUIDs: evicted)
            }
        }
    }

    // MARK: - Helpers

    private static func readRecord(at url: URL) -> NREventRecord? {
        guard let data = try? Data(contentsOf: url),
              let dict = try? NRMAJSON.jsonObject(with: data, options: []) as? [String: Any],
              let record = NREventRecord(dictionary: dict) else {
            return nil
        }
        return record
    }
}
