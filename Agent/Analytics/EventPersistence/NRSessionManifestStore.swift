//
//  NRSessionManifestStore.swift
//  Agent
//
//  Copyright © 2026 New Relic. All rights reserved.
//

import Foundation

/// File-per-session persisted store for `NRSessionManifest`s, under
/// `<storePath>/nr_session_manifest/`. Looked up directly by filename
/// (`<sessionId>.json`) -- O(1), no index needed since `NREventRecord.sessionId`
/// is exactly the lookup key.
///
/// Shares one serial queue for all reads/writes/deletes so retention eviction
/// can never race a concurrent write for the same manifest.
final class NRSessionManifestStore {

    private let directoryURL: URL
    private let queue = DispatchQueue(label: "com.newrelic.eventpersistence.manifeststore")

    init(storePath: String) {
        directoryURL = URL(fileURLWithPath: storePath).appendingPathComponent("nr_session_manifest", isDirectory: true)
        NREventPersistenceFileSupport.prepareProtectedDirectory(at: directoryURL)
    }

    private func fileURL(forSessionId sessionId: String) -> URL {
        directoryURL.appendingPathComponent("\(sessionId).json")
    }

    func store(_ manifest: NRSessionManifest) {
        queue.async { [directoryURL] in
            guard let data = try? JSONSerialization.data(withJSONObject: manifest.dictionaryRepresentation) else {
                NRLOG_AGENT_ERROR("NREventPersistence: failed to serialize session manifest \(manifest.sessionId)")
                return
            }
            let url = directoryURL.appendingPathComponent("\(manifest.sessionId).json")
            do {
                try data.write(to: url, options: .atomic)
            } catch {
                NRLOG_AGENT_ERROR("NREventPersistence: failed to write session manifest \(manifest.sessionId): \(error)")
            }
        }
    }

    func manifest(forSessionId sessionId: String) -> NRSessionManifest? {
        queue.sync {
            NRSessionManifestStore.readManifest(at: fileURL(forSessionId: sessionId))
        }
    }

    func delete(sessionId: String) {
        queue.async { [directoryURL] in
            try? FileManager.default.removeItem(at: directoryURL.appendingPathComponent("\(sessionId).json"))
        }
    }

    /// Blocks until every store/delete/evict enqueued before this call has
    /// finished. Used by tests.
    func synchronize() {
        queue.sync {}
    }

    /// Evicts a manifest once it's both unreferenced by any still-live event
    /// record and older than the retention cap -- `liveSessionIds` is the set
    /// of sessionIds any currently-persisted `NREventRecord` still points at,
    /// so a manifest a long-running session keeps refreshing isn't evicted out
    /// from under events that still need it.
    func evictManifests(olderThanMs maxAgeMs: Int64, nowMs: Int64, liveSessionIds: Set<String>) {
        queue.async { [directoryURL] in
            let fileManager = FileManager.default
            guard let contents = try? fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil) else {
                return
            }
            for url in contents where url.pathExtension == "json" {
                let sessionId = url.deletingPathExtension().lastPathComponent
                if liveSessionIds.contains(sessionId) {
                    continue
                }
                guard let manifest = NRSessionManifestStore.readManifest(at: url) else {
                    try? fileManager.removeItem(at: url) // corrupt, unreferenced -- safe to drop
                    continue
                }
                if nowMs - manifest.lastUpdateMs > maxAgeMs {
                    try? fileManager.removeItem(at: url)
                }
            }
        }
    }

    private static func readManifest(at url: URL) -> NRSessionManifest? {
        guard let data = try? Data(contentsOf: url),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let manifest = NRSessionManifest(dictionary: dict) else {
            return nil
        }
        return manifest
    }
}
