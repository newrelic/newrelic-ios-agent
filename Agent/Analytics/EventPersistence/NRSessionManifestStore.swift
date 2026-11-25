//
//  NRSessionManifestStore.swift
//  Agent
//
//  Copyright © 2026 New Relic. All rights reserved.
//

import Foundation
@_implementationOnly import NewRelicPrivate

/// Persisted `NRSessionManifest`s, one per session, stored beside that session's events as
/// `<storePath>/nr_event_cache/<sessionId>/_manifest.json` (see `NREventPersistenceFileSupport`).
/// Looked up directly by path -- O(1), no index needed since `NREventRecord.sessionId` is
/// exactly the lookup key.
///
/// Shares one serial queue for all reads/writes/deletes so retention eviction
/// can never race a concurrent write for the same manifest. It never touches event files;
/// a session directory is only removed when empty, so it can't race `NRFileEventStore`.
final class NRSessionManifestStore {

    private let rootURL: URL
    private let queue = DispatchQueue(label: "com.newrelic.eventpersistence.manifeststore")

    init(storePath: String) {
        rootURL = NREventPersistenceFileSupport.rootURL(storePath: storePath)
        NREventPersistenceFileSupport.prepareProtectedDirectory(at: rootURL)
    }

    private func sessionDirectoryURL(forSessionId sessionId: String) -> URL {
        rootURL.appendingPathComponent(NREventPersistenceFileSupport.encodedName(sessionId), isDirectory: true)
    }

    private func manifestURL(inDirectory directory: URL) -> URL {
        directory.appendingPathComponent(NREventPersistenceFileSupport.manifestFileName)
    }

    func store(_ manifest: NRSessionManifest) {
        queue.async {
            guard let data = try? NRMAJSON.data(withJSONObject: manifest.dictionaryRepresentation, options: []) else {
                NRLOG_AGENT_ERROR("NREventPersistence: failed to serialize session manifest \(manifest.sessionId)")
                return
            }
            let directory = self.sessionDirectoryURL(forSessionId: manifest.sessionId)
            let url = self.manifestURL(inDirectory: directory)
            do {
                do {
                    try data.write(to: url, options: .atomic)
                } catch {
                    // First write for the session, or the directory was removed while empty.
                    NREventPersistenceFileSupport.prepareProtectedDirectory(at: directory)
                    try data.write(to: url, options: .atomic)
                }
            } catch {
                NRLOG_AGENT_ERROR("NREventPersistence: failed to write session manifest \(manifest.sessionId): \(error)")
            }
        }
    }

    func manifest(forSessionId sessionId: String) -> NRSessionManifest? {
        queue.sync {
            NRSessionManifestStore.readManifest(at: manifestURL(inDirectory: sessionDirectoryURL(forSessionId: sessionId)))
        }
    }

    func delete(sessionId: String) {
        queue.async {
            let directory = self.sessionDirectoryURL(forSessionId: sessionId)
            try? FileManager.default.removeItem(at: self.manifestURL(inDirectory: directory))
            NREventPersistenceFileSupport.removeDirectoryIfEmpty(directory)
        }
    }

    /// Blocks until every store/delete/evict enqueued before this call has
    /// finished. Used by tests.
    func synchronize() {
        queue.sync {}
    }

    /// Evicts a manifest once unreferenced by any live event and older than the
    /// retention cap, then evicts the oldest remaining non-live manifests (by
    /// `lastUpdateMs`) if still over `maxCount`. Live sessions are never evicted.
    /// Session directories left empty are removed.
    func evictManifests(olderThanMs maxAgeMs: Int64, nowMs: Int64, liveSessionIds: Set<String>, maxCount: Int) {
        queue.async {
            let fileManager = FileManager.default
            guard let directories = try? fileManager.contentsOfDirectory(at: self.rootURL, includingPropertiesForKeys: nil) else {
                return
            }

            var survivingNonLive: [(directory: URL, lastUpdateMs: Int64)] = []
            var liveCount = 0

            for directory in directories {
                let url = self.manifestURL(inDirectory: directory)
                guard fileManager.fileExists(atPath: url.path) else {
                    NREventPersistenceFileSupport.removeDirectoryIfEmpty(directory) // nothing in it
                    continue
                }
                let sessionId = NREventPersistenceFileSupport.decodedName(directory.lastPathComponent)
                if liveSessionIds.contains(sessionId) {
                    liveCount += 1
                    continue
                }
                guard let manifest = NRSessionManifestStore.readManifest(at: url) else {
                    self.removeManifest(in: directory) // corrupt, unreferenced -- safe to drop
                    continue
                }
                if nowMs - manifest.lastUpdateMs > maxAgeMs {
                    self.removeManifest(in: directory)
                    continue
                }
                survivingNonLive.append((directory, manifest.lastUpdateMs))
            }

            let overflow = (liveCount + survivingNonLive.count) - maxCount
            guard overflow > 0 else { return }
            survivingNonLive.sort { $0.lastUpdateMs < $1.lastUpdateMs }
            for entry in survivingNonLive.prefix(overflow) {
                self.removeManifest(in: entry.directory)
            }
        }
    }

    private func removeManifest(in directory: URL) {
        try? FileManager.default.removeItem(at: manifestURL(inDirectory: directory))
        NREventPersistenceFileSupport.removeDirectoryIfEmpty(directory)
    }

    private static func readManifest(at url: URL) -> NRSessionManifest? {
        guard let data = try? Data(contentsOf: url),
              let dict = try? NRMAJSON.jsonObject(with: data, options: []) as? [String: Any],
              let manifest = NRSessionManifest(dictionary: dict) else {
            return nil
        }
        return manifest
    }
}
