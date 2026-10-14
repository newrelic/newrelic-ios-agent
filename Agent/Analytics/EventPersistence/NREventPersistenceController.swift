//
//  NREventPersistenceController.swift
//  Agent
//
//  Copyright © 2026 New Relic. All rights reserved.
//

import Foundation
@_implementationOnly import NewRelicPrivate

/// Coordinates the two event-persistence stores (`NRFileEventStore`,
/// `NRSessionManifestStore`): the write path (persist a fresh event / refresh
/// a session's manifest), the replay path (recover persisted events on next
/// launch and resolve their final attributes via the manifest-overlay
/// fallback ladder), confirmation (drop persisted events once a recovery
/// harvest is confirmed delivered), and the 7-day retention sweep.
///
/// This class owns no reference to `NRMAEventManager`/`AnalyticsController`/
/// `NRMASAM` -- callers hand it the values it needs (sessionId, realAgentId,
/// attribute snapshots) so it stays decoupled and independently testable.
/// ObjC-visible (`@objcMembers`) since it's called from `NRMAEventManager`,
/// the legacy C++ bridge, `NewRelicAgentInternal`, `NRMAHarvester`, and
/// `NRMACrashDataWriter`.
@objcMembers
public class NREventPersistenceController: NSObject {

    @objc public static let shared = NREventPersistenceController()

    /// Hard retention cap, in milliseconds -- 7 days, per the CDD.
    static let defaultRetentionMs: Int64 = 7 * 24 * 60 * 60 * 1000

    private let eventStore: NRFileEventStore
    private let manifestStore: NRSessionManifestStore

    // UUIDs most recently staged into an outgoing recovery-harvest payload,
    // awaiting confirmation. Only dropped from the event store once that
    // harvest is confirmed *successful* -- a failed/unattempted harvest must
    // leave them on disk for the next try.
    private var pendingConfirmationUUIDs: [String] = []
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

    /// Persists a freshly-recorded event. `attributes` should be the event's
    /// already-flattened JSON representation (as produced by
    /// `-[NRMAAnalyticEventProtocol JSONObject]`, which already folds in
    /// timestamp/sessionElapsedTime/eventType/name alongside custom
    /// attributes) -- callers don't need to pick those apart. No-ops when
    /// the feature flag is disabled.
    @objc(recordEventWithEventUUID:eventType:timestampMs:attributes:sessionId:realAgentId:mutableAttributesSnapshot:)
    public func recordEvent(eventUUID: String,
                             eventType: String,
                             timestampMs: Int64,
                             attributes: [String: Any],
                             sessionId: String,
                             realAgentId: UInt64,
                             mutableAttributesSnapshot: [String: Any]) {
        guard NRMAFlags.shouldEnableEventPersistence() else { return }
        let record = NREventRecord(eventUUID: eventUUID,
                                    eventType: eventType,
                                    name: attributes[kNRMA_Attrib_name] as? String,
                                    timestamp: timestampMs,
                                    attributes: attributes,
                                    sessionId: sessionId,
                                    realAgentId: realAgentId,
                                    mutableAttributesSnapshot: mutableAttributesSnapshot)
        eventStore.store(record)
    }

    // MARK: - Session manifest

    /// Writes a fresh manifest at session start.
    @objc(writeSessionManifestWithSessionId:realAgentId:sessionStartMs:stableAttributes:)
    public func writeSessionManifest(sessionId: String,
                                      realAgentId: UInt64,
                                      sessionStartMs: Int64,
                                      stableAttributes: [String: Any]) {
        guard NRMAFlags.shouldEnableEventPersistence() else { return }
        let manifest = NRSessionManifest(sessionId: sessionId,
                                          realAgentId: realAgentId,
                                          sessionStartMs: sessionStartMs,
                                          lastUpdateMs: sessionStartMs,
                                          stableAttributes: stableAttributes)
        manifestStore.store(manifest)
    }

    /// Bumps a manifest's `lastUpdateMs` on each harvest tick, so a
    /// long-running session's manifest retention is judged independently of
    /// whether any event referencing it is also still live.
    @objc(refreshSessionManifestWithSessionId:nowMs:)
    public func refreshSessionManifest(sessionId: String, nowMs: Int64) {
        guard NRMAFlags.shouldEnableEventPersistence() else { return }
        guard var manifest = manifestStore.manifest(forSessionId: sessionId) else { return }
        manifest.lastUpdateMs = nowMs
        manifestStore.store(manifest)
    }

    // MARK: - Replay

    /// Recovers every persisted event, resolves its attributes via the
    /// fallback ladder below, and returns the per-event JSON ready to hand to
    /// `NRMAHarvestController +addRecoveredAnalyticsEvents:`. Cheap no-op
    /// (just checks the shadow file) when there's nothing to recover.
    ///
    /// Fallback ladder, matching the CDD:
    ///   1. Manifest found -> stableAttributes overlaid by the record's own
    ///      mutableAttributesSnapshot (mutable wins on conflict).
    ///   2. Manifest missing, record has its own snapshot -> that snapshot alone.
    ///   3. Both missing/corrupt -> `currentSessionAttributes` (graceful
    ///      degradation; the record is still delivered, never dropped).
    ///
    /// `currentSessionAttributes` is only consulted in case 3.
    @discardableResult
    @objc(recoverPersistedEventsStagingForHarvestWithCurrentSessionAttributes:)
    public func recoverPersistedEventsStagingForHarvest(currentSessionAttributes: [String: Any]) -> [[String: Any]] {
        guard NRMAFlags.shouldEnableEventPersistence() else { return [] }
        guard eventStore.hasPersistedRecords() else { return [] }
        let records = eventStore.fetchAll()
        guard !records.isEmpty else { return [] }
        NRLOG_AGENT_VERBOSE("NREventPersistence: recovering \(records.count) persisted event(s) from a previous session")

        var payloads: [[String: Any]] = []
        var stagedUUIDs: [String] = []
        for record in records {
            // Start from the resolved SESSION-level attributes (stable +
            // mutable snapshot / fallback), then overlay the event's own
            // captured content on top -- record.attributes is exactly
            // `[event JSONObject]`/`generateJSONObject()`'s original output,
            // so it already carries this event's own timestamp,
            // sessionElapsedTime, eventType, and any custom attributes the
            // event itself was recorded with. Without this overlay, a
            // recovered custom event would be sent as an empty shell missing
            // all of its actual content.
            var json = resolveAttributes(for: record, currentSessionAttributes: currentSessionAttributes)
            for (key, value) in record.attributes {
                json[key] = value
            }
            // Re-assert after the merge, as a guarantee independent of
            // whatever record.attributes does or doesn't contain (e.g. a
            // partially-corrupt blob) -- these three must always reflect the
            // record's own authoritative fields, never silently fall back to
            // something stale or missing.
            json[kNRMA_RA_timestamp] = record.timestamp
            json[kNRMA_RA_eventType] = record.eventType
            json[kNRMA_RA_sessionId] = record.sessionId
            payloads.append(json)
            stagedUUIDs.append(record.eventUUID)
        }

        stateLock.lock()
        pendingConfirmationUUIDs.append(contentsOf: stagedUUIDs)
        stateLock.unlock()

        return payloads
    }

    private func resolveAttributes(for record: NREventRecord, currentSessionAttributes: [String: Any]) -> [String: Any] {
        if let manifest = manifestStore.manifest(forSessionId: record.sessionId) {
            NRMASupportMetricHelper.enqueueEventPersistenceReattributedMetric()
            var merged = manifest.stableAttributes
            for (key, value) in record.mutableAttributesSnapshot {
                merged[key] = value
            }
            return merged
        }

        NRMASupportMetricHelper.enqueueEventPersistenceManifestMissingMetric()
        if !record.mutableAttributesSnapshot.isEmpty {
            return record.mutableAttributesSnapshot
        }
        return currentSessionAttributes
    }

    // MARK: - Crash path

    /// Called from the crash-write path when the crash's own recorded
    /// sessionId (authoritative -- captured synchronously at crash time)
    /// doesn't match the sessionId embedded in the "last session" attributes
    /// read at next launch (a race against a new session already starting
    /// before that async read runs). Rather than dropping the crash's
    /// attributes/events outright, looks up the crash's *true* session's
    /// manifest and returns its stableAttributes as a corrected replacement.
    ///
    /// The events themselves are not touched here and don't need to be --
    /// in this at-rest format they carry no per-event session identity of
    /// their own (unlike a `NREventRecord`), so a session-level attribute
    /// mismatch doesn't invalidate them.
    ///
    /// Returns nil if no manifest is found either (flag disabled, or the
    /// manifest already evicted/never written) -- caller should fall back
    /// to dropping, exactly as before this feature existed.
    @objc(reattributeCrashAttributesForSessionId:)
    public func reattributeCrashAttributes(forSessionId crashSessionId: String) -> [String: Any]? {
        guard NRMAFlags.shouldEnableEventPersistence() else { return nil }
        guard let manifest = manifestStore.manifest(forSessionId: crashSessionId) else {
            NRMASupportMetricHelper.enqueueEventPersistenceManifestMissingMetric()
            return nil
        }
        NRMASupportMetricHelper.enqueueEventPersistenceReattributedMetric()
        return manifest.stableAttributes
    }

    // MARK: - Pending confirmation (fresh events pulled for a harvest attempt)

    /// Called when a batch of *freshly-recorded* (not recovered) events is
    /// pulled out of the live buffer for a harvest attempt -- i.e. the normal,
    /// non-crash harvest path. Without this, a persisted event's on-disk copy
    /// would never be deleted after it's successfully delivered the ordinary
    /// way, and it would get wrongly recovered and re-sent as a duplicate the
    /// next time the app restarts (the exact bug Android hit historically).
    /// Shares the same pending set/confirmation mechanism as recovered events.
    @objc(markEventsPendingConfirmationWithEventUUIDs:)
    public func markEventsPendingConfirmation(eventUUIDs: [String]) {
        guard !eventUUIDs.isEmpty else { return }
        stateLock.lock()
        pendingConfirmationUUIDs.append(contentsOf: eventUUIDs)
        stateLock.unlock()
    }

    // MARK: - Confirmation

    /// Call once the harvest carrying the most recently staged recovered
    /// and/or freshly-harvested events is confirmed *successful* -- not
    /// merely attempted. Deletes those events' on-disk records; a
    /// failed/unattempted harvest should never call this, so the records
    /// remain for the next try.
    public func confirmLastRecoveryHarvestSucceeded() {
        stateLock.lock()
        let uuids = pendingConfirmationUUIDs
        pendingConfirmationUUIDs.removeAll()
        stateLock.unlock()
        eventStore.delete(eventUUIDs: uuids)
    }

    // MARK: - Retention

    /// Hard 7-day eviction, "regardless of upload state" -- run at startup
    /// (before replay) and on every harvest tick.
    @objc(performRetentionSweepWithNowMs:)
    public func performRetentionSweep(nowMs: Int64) {
        eventStore.evictRecords(olderThanMs: NREventPersistenceController.defaultRetentionMs, nowMs: nowMs)
        let liveSessionIds = Set(eventStore.fetchAll().map { $0.sessionId })
        manifestStore.evictManifests(olderThanMs: NREventPersistenceController.defaultRetentionMs,
                                      nowMs: nowMs,
                                      liveSessionIds: liveSessionIds)
    }
}
