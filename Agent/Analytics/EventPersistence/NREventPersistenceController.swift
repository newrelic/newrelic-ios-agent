//
//  NREventPersistenceController.swift
//  Agent
//
//  Copyright © 2026 New Relic. All rights reserved.
//

import Foundation
@_implementationOnly import NewRelicPrivate

/// Coordinates the two event-persistence stores (`NRFileEventStore`,
/// `NRSessionManifestStore`): write, recovery, confirmation, and retention.
@objcMembers
public class NREventPersistenceController: NSObject {

    @objc public static let shared = NREventPersistenceController()

    /// Hard retention cap, in milliseconds -- 7 days.
    static let defaultRetentionMs: Int64 = 7 * 24 * 60 * 60 * 1000

    /// Hard count caps, oldest-evicted first.
    static let defaultMaxEventCount: Int = 1000
    static let defaultMaxSessionManifestCount: Int = 32

    private let eventStore: NRFileEventStore
    private let manifestStore: NRSessionManifestStore

    // UUIDs staged for an outgoing harvest, dropped only once that harvest succeeds.
    private var pendingConfirmationUUIDs: Set<String> = []
    // Recovered events, bucketed by the realAgentId they were actually recorded under
    // (NREventRecord.realAgentId) -- ingest resolves appVersion from data_token's
    // server-side mapping only, ignoring JSON attributes and header overrides, so every
    // bucket ships in its own upload stamped with that historical token. Keyed by
    // eventUUID, not a plain array, so a record re-discovered by a later sweep (this is
    // a process-wide singleton that outlives a harvester restart) overwrites its entry
    // instead of duplicating it -- see the Hex in-flight-dedup fix for the same pattern.
    private var pendingGroupedUploads: [UInt64: [String: [String: Any]]] = [:]
    private let stateLock = NSLock()

    public override convenience init() {
        self.init(eventStore: NRFileEventStore(storePath: NewRelicInternalUtils.getStorePath()),
                   manifestStore: NRSessionManifestStore(storePath: NewRelicInternalUtils.getStorePath()))
    }

    /// Testable entry point -- lets tests inject stores rooted at a temp
    /// directory instead of the real one.
    init(eventStore: NRFileEventStore, manifestStore: NRSessionManifestStore) {
        self.eventStore = eventStore
        self.manifestStore = manifestStore
        super.init()
    }

    // MARK: - Write path

    /// Persists a freshly-recorded event. No-ops when the feature flag is disabled.
    @objc(recordEventWithEventUUID:eventType:timestampMs:attributes:sessionId:realAgentId:)
    public func recordEvent(eventUUID: String,
                             eventType: String,
                             timestampMs: Int64,
                             attributes: [String: Any],
                             sessionId: String,
                             realAgentId: UInt64) {
        guard NRMAFlags.shouldEnableEventPersistence() else { return }
        let record = NREventRecord(eventUUID: eventUUID,
                                    eventType: eventType,
                                    name: attributes[kNRMA_Attrib_name] as? String,
                                    timestamp: timestampMs,
                                    attributes: attributes,
                                    sessionId: sessionId,
                                    realAgentId: realAgentId)
        eventStore.store(record)
    }

    /// Deletes one persisted event immediately. Called when an event is evicted from the
    /// live buffer, so it isn't resurrected by a later recovery sweep.
    @objc(discardPersistedEventWithEventUUID:)
    public func discardPersistedEvent(eventUUID: String) {
        guard NRMAFlags.shouldEnableEventPersistence() else { return }
        eventStore.delete(eventUUIDs: [eventUUID])
    }

    // MARK: - Session manifest

    /// Writes a fresh manifest at session start.
    @objc(writeSessionManifestWithSessionId:realAgentId:sessionStartMs:sessionAttributes:)
    public func writeSessionManifest(sessionId: String,
                                      realAgentId: UInt64,
                                      sessionStartMs: Int64,
                                      sessionAttributes: [String: Any]) {
        guard NRMAFlags.shouldEnableEventPersistence() else { return }
        let manifest = NRSessionManifest(sessionId: sessionId,
                                          realAgentId: realAgentId,
                                          sessionStartMs: sessionStartMs,
                                          lastUpdateMs: sessionStartMs,
                                          sessionAttributes: sessionAttributes)
        manifestStore.store(manifest)
    }

    /// Bumps `lastUpdateMs` and re-syncs `sessionAttributes` on each harvest tick.
    @objc(refreshSessionManifestWithSessionId:nowMs:sessionAttributes:)
    public func refreshSessionManifest(sessionId: String, nowMs: Int64, sessionAttributes: [String: Any]) {
        guard NRMAFlags.shouldEnableEventPersistence() else { return }
        guard var manifest = manifestStore.manifest(forSessionId: sessionId) else { return }
        manifest.lastUpdateMs = nowMs
        manifest.sessionAttributes = sessionAttributes
        manifestStore.store(manifest)
    }

    // MARK: - Replay

    /// Recovers every persisted event (resolving attributes via `resolveAttributes`) and
    /// stages it for a dedicated per-realAgentId upload via `pendingGroupedRecoveryUploads()`.
    /// `excludingSessionId` skips that session's events, left for the crash path to claim
    /// instead. Always returns `[]` -- recovered events never ride the regular harvest
    /// buffer; see `pendingGroupedUploads`'s doc comment for why.
    @discardableResult
    @objc(recoverPersistedEventsStagingForHarvestExcludingSessionId:)
    public func recoverPersistedEventsStagingForHarvest(excludingSessionId: String? = nil) -> [[String: Any]] {
        guard NRMAFlags.shouldEnableEventPersistence() else { return [] }
        guard eventStore.hasPersistedRecords() else { return [] }

        // This sweep can run again mid-process (foreground, startNewSessionForUserId:,
        // 4-hour restart) while an earlier harvest still has one of these events
        // in flight and marked pending. Skip those so they don't get staged twice.
        // Safe: pendingConfirmationUUIDs is in-memory only, so a skipped record is
        // still recoverable on the next launch.
        stateLock.lock()
        let inFlightUUIDs = pendingConfirmationUUIDs
        stateLock.unlock()

        let records = eventStore.fetchAll().filter { $0.sessionId != excludingSessionId && !inFlightUUIDs.contains($0.eventUUID) }
        guard !records.isEmpty else { return [] }
        NRLOG_AGENT_VERBOSE("NREventPersistence: recovering \(records.count) persisted event(s) from a previous session")

        var grouped: [UInt64: [String: [String: Any]]] = [:]
        for record in records {
            let sessionAttributes = resolveAttributes(manifest: manifestStore.manifest(forSessionId: record.sessionId))

            // Session attributes first, then the event's own fields on top -- otherwise
            // a recovered custom event would ship as an empty shell.
            var json = sessionAttributes
            for (key, value) in record.attributes {
                json[key] = value
            }
            // Re-assert in case record.attributes was corrupt/stale.
            json[kNRMA_RA_timestamp] = record.timestamp
            json[kNRMA_RA_eventType] = record.eventType
            json[kNRMA_RA_sessionId] = record.sessionId

            grouped[record.realAgentId, default: [:]][record.eventUUID] = json
        }

        stateLock.lock()
        for (realAgentId, entries) in grouped {
            // Merge, not append -- see pendingGroupedUploads's doc comment.
            pendingGroupedUploads[realAgentId, default: [:]].merge(entries) { _, new in new }
        }
        stateLock.unlock()

        return []
    }

    /// Hands back every recovered bucket, grouped by originating realAgentId, for a
    /// dedicated per-token upload -- clears internal state on read. Callers confirm each
    /// bucket via `confirmGroupedRecoveryUploadSucceeded(eventUUIDs:)`; an unconfirmed
    /// bucket stays persisted and is picked up again by the next sweep.
    @objc public func pendingGroupedRecoveryUploads() -> [[String: Any]] {
        stateLock.lock()
        let grouped = pendingGroupedUploads
        pendingGroupedUploads.removeAll()
        stateLock.unlock()
        return grouped.map { realAgentId, entries in
            [
                "realAgentId": NSNumber(value: realAgentId),
                "eventUUIDs": Array(entries.keys),
                "events": Array(entries.values)
            ]
        }
    }

    /// Deletes the persisted copies of a grouped bucket once its dedicated upload is
    /// confirmed successful. Independent of `confirmLastRecoveryHarvestSucceeded` since a
    /// grouped bucket's upload can succeed or fail independently of the regular harvest.
    @objc(confirmGroupedRecoveryUploadSucceededWithEventUUIDs:)
    public func confirmGroupedRecoveryUploadSucceeded(eventUUIDs: [String]) {
        guard !eventUUIDs.isEmpty else { return }
        eventStore.delete(eventUUIDs: eventUUIDs)
    }

    /// Manifest found -> its sessionAttributes. Missing/corrupt -> empty (graceful
    /// degradation; the record's own fields still ship, never dropped).
    private func resolveAttributes(manifest: NRSessionManifest?) -> [String: Any] {
        guard let manifest else {
            NRMASupportMetricHelper.enqueueEventPersistenceManifestMissingMetric()
            return [:]
        }
        NRMASupportMetricHelper.enqueueEventPersistenceReattributedMetric()
        return manifest.sessionAttributes
    }

    private func resolveAttributes(for record: NREventRecord) -> [String: Any] {
        resolveAttributes(manifest: manifestStore.manifest(forSessionId: record.sessionId))
    }

    // MARK: - Crash path

    /// Resolves a crash's true session's attributes from its manifest, for when the crash's
    /// authoritative sessionId doesn't match whatever "last session" attributes were read at
    /// next launch. Returns nil if no manifest is found -- caller falls back to dropping.
    @objc(reattributeCrashAttributesForSessionId:)
    public func reattributeCrashAttributes(forSessionId crashSessionId: String) -> [String: Any]? {
        guard NRMAFlags.shouldEnableEventPersistence() else { return nil }
        guard let manifest = manifestStore.manifest(forSessionId: crashSessionId) else {
            NRMASupportMetricHelper.enqueueEventPersistenceManifestMissingMetric()
            return nil
        }
        NRMASupportMetricHelper.enqueueEventPersistenceReattributedMetric()
        return manifest.sessionAttributes
    }

    /// Fetches and deletes every persisted event for `sessionId`, for attaching to a crash report.
    @discardableResult
    @objc(claimPersistedEventsForCrashSessionId:)
    public func claimPersistedEvents(forCrashSessionId sessionId: String) -> [[String: Any]] {
        guard NRMAFlags.shouldEnableEventPersistence() else { return [] }
        let records = eventStore.fetchAll().filter { $0.sessionId == sessionId }
        guard !records.isEmpty else { return [] }

        var payloads: [[String: Any]] = []
        for record in records {
            var json = resolveAttributes(for: record)
            for (key, value) in record.attributes {
                json[key] = value
            }
            json[kNRMA_RA_timestamp] = record.timestamp
            json[kNRMA_RA_eventType] = record.eventType
            json[kNRMA_RA_sessionId] = record.sessionId
            payloads.append(json)
        }

        eventStore.delete(eventUUIDs: records.map { $0.eventUUID })
        return payloads
    }

    // MARK: - Pending confirmation (fresh events pulled for a harvest attempt)

    /// Called when freshly-recorded (not recovered) events are pulled from the live buffer
    /// for an ordinary harvest attempt, so their persisted copies get cleaned up on success
    /// too -- otherwise they'd be wrongly recovered and re-sent on a later relaunch.
    @objc(markEventsPendingConfirmationWithEventUUIDs:)
    public func markEventsPendingConfirmation(eventUUIDs: [String]) {
        guard !eventUUIDs.isEmpty else { return }
        stateLock.lock()
        pendingConfirmationUUIDs.formUnion(eventUUIDs)
        stateLock.unlock()
    }

    // MARK: - Confirmation

    /// Call once the harvest carrying the staged events is confirmed *successful*, not
    /// merely attempted -- a failed harvest must never call this.
    public func confirmLastRecoveryHarvestSucceeded() {
        stateLock.lock()
        let uuids = pendingConfirmationUUIDs
        pendingConfirmationUUIDs.removeAll()
        stateLock.unlock()
        eventStore.delete(eventUUIDs: Array(uuids))
    }

    // MARK: - Retention

    /// 7-day age cap plus count cap on both stores.
    @objc(performRetentionSweepWithNowMs:)
    public func performRetentionSweep(nowMs: Int64) {
        eventStore.evictRecords(olderThanMs: NREventPersistenceController.defaultRetentionMs,
                                 nowMs: nowMs,
                                 maxCount: NREventPersistenceController.defaultMaxEventCount)
        let liveSessionIds = Set(eventStore.fetchAll().map { $0.sessionId })
        manifestStore.evictManifests(olderThanMs: NREventPersistenceController.defaultRetentionMs,
                                      nowMs: nowMs,
                                      liveSessionIds: liveSessionIds,
                                      maxCount: NREventPersistenceController.defaultMaxSessionManifestCount)
    }
}
