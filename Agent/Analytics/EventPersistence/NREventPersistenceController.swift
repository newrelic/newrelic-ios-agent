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
    /// returns per-event JSON ready for `NRMAHarvestController +addRecoveredAnalyticsEvents:`.
    /// `excludingSessionId` skips that session's events, left for the crash path to claim instead.
    @discardableResult
    @objc(recoverPersistedEventsStagingForHarvestExcludingSessionId:)
    public func recoverPersistedEventsStagingForHarvest(excludingSessionId: String? = nil) -> [[String: Any]] {
        guard NRMAFlags.shouldEnableEventPersistence() else { return [] }
        guard eventStore.hasPersistedRecords() else { return [] }
        let records = eventStore.fetchAll().filter { $0.sessionId != excludingSessionId }
        guard !records.isEmpty else { return [] }
        NRLOG_AGENT_VERBOSE("NREventPersistence: recovering \(records.count) persisted event(s) from a previous session")

        var payloads: [[String: Any]] = []
        var stagedUUIDs: [String] = []
        for record in records {
            // Session-level attributes first, then the event's own JSONObject output on top
            // (custom attributes + its own timestamp/eventType) -- otherwise a recovered
            // custom event would ship as an empty shell.
            var json = resolveAttributes(for: record)
            for (key, value) in record.attributes {
                json[key] = value
            }
            // Re-assert in case record.attributes was corrupt/stale.
            json[kNRMA_RA_timestamp] = record.timestamp
            json[kNRMA_RA_eventType] = record.eventType
            json[kNRMA_RA_sessionId] = record.sessionId
            payloads.append(json)
            stagedUUIDs.append(record.eventUUID)
        }

        stateLock.lock()
        pendingConfirmationUUIDs.formUnion(stagedUUIDs)
        stateLock.unlock()

        return payloads
    }

    /// Manifest found -> its sessionAttributes. Missing/corrupt -> empty (graceful
    /// degradation; the record's own fields still ship, never dropped).
    private func resolveAttributes(for record: NREventRecord) -> [String: Any] {
        guard let manifest = manifestStore.manifest(forSessionId: record.sessionId) else {
            NRMASupportMetricHelper.enqueueEventPersistenceManifestMissingMetric()
            return [:]
        }
        NRMASupportMetricHelper.enqueueEventPersistenceReattributedMetric()
        return manifest.sessionAttributes
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
