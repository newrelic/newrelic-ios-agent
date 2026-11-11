//
//  NREventPersistenceControllerTests.swift
//  NewRelicAgent
//
//  Copyright © 2026 New Relic. All rights reserved.
//

import XCTest
@testable import NewRelic

final class NREventPersistenceControllerTests: XCTestCase {

    private var storePath: String!
    private var eventStore: NRFileEventStore!
    private var manifestStore: NRSessionManifestStore!
    private var sut: NREventPersistenceController!

    override func setUp() {
        super.setUp()
        NRMAFlags.enableFeatures(NRMAFeatureFlags.NRFeatureFlag_EventPersistence)
        storePath = NSTemporaryDirectory().appending("NREventPersistenceControllerTests-\(UUID().uuidString)")
        eventStore = NRFileEventStore(storePath: storePath)
        manifestStore = NRSessionManifestStore(storePath: storePath)
        sut = NREventPersistenceController(eventStore: eventStore, manifestStore: manifestStore)
    }

    override func tearDown() {
        NRMAFlags.disableFeatures(NRMAFeatureFlags.NRFeatureFlag_EventPersistence)
        try? FileManager.default.removeItem(atPath: storePath)
        sut = nil
        super.tearDown()
    }

    // MARK: - Write path

    func testRecordEventPersistsToStore() {
        sut.recordEvent(eventUUID: "uuid-1",
                         eventType: "Mobile",
                         timestampMs: 1_000,
                         attributes: ["name": "MyEvent", "foo": "bar"],
                         sessionId: "session-1",
                         realAgentId: 7)
        eventStore.synchronize()

        let records = eventStore.fetchAll()
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.eventUUID, "uuid-1")
        XCTAssertEqual(records.first?.name, "MyEvent")
        XCTAssertEqual(records.first?.sessionId, "session-1")
        XCTAssertEqual(records.first?.realAgentId, 7)
    }

    func testDiscardPersistedEventDeletesIt() {
        eventStore.store(makeRecord(uuid: "uuid-1", sessionId: "session-1"))
        eventStore.store(makeRecord(uuid: "uuid-2", sessionId: "session-1"))
        eventStore.synchronize()

        sut.discardPersistedEvent(eventUUID: "uuid-1")
        eventStore.synchronize()

        let remaining = eventStore.fetchAll()
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.eventUUID, "uuid-2")
    }

    func testDiscardPersistedEventOfUnknownUUIDIsHarmless() {
        eventStore.store(makeRecord(uuid: "uuid-1", sessionId: "session-1"))
        eventStore.synchronize()

        sut.discardPersistedEvent(eventUUID: "does-not-exist")
        eventStore.synchronize()

        XCTAssertEqual(eventStore.fetchAll().count, 1)
    }

    func testDiscardPersistedEventIsNoopWhenFlagDisabled() {
        eventStore.store(makeRecord(uuid: "uuid-1", sessionId: "session-1"))
        eventStore.synchronize()

        NRMAFlags.disableFeatures(NRMAFeatureFlags.NRFeatureFlag_EventPersistence)
        sut.discardPersistedEvent(eventUUID: "uuid-1")
        eventStore.synchronize()

        XCTAssertEqual(eventStore.fetchAll().count, 1)
    }

    func testRecordEventIsNoopWhenFlagDisabled() {
        NRMAFlags.disableFeatures(NRMAFeatureFlags.NRFeatureFlag_EventPersistence)
        sut.recordEvent(eventUUID: "uuid-1",
                         eventType: "Mobile",
                         timestampMs: 1_000,
                         attributes: [:],
                         sessionId: "session-1",
                         realAgentId: 7)
        eventStore.synchronize()
        XCTAssertTrue(eventStore.fetchAll().isEmpty)
    }

    // MARK: - Session manifest

    func testWriteSessionManifestPersists() {
        sut.writeSessionManifest(sessionId: "session-1", realAgentId: 7, sessionStartMs: 1_000, sessionAttributes: ["userId": "abc"])
        manifestStore.synchronize()

        let manifest = manifestStore.manifest(forSessionId: "session-1")
        XCTAssertEqual(manifest?.sessionAttributes["userId"] as? String, "abc")
        XCTAssertEqual(manifest?.lastUpdateMs, 1_000)
    }

    func testRefreshSessionManifestUpdatesLastUpdateMsAndSessionAttributes() {
        sut.writeSessionManifest(sessionId: "session-1", realAgentId: 7, sessionStartMs: 1_000, sessionAttributes: [:])
        manifestStore.synchronize()

        sut.refreshSessionManifest(sessionId: "session-1", nowMs: 5_000, sessionAttributes: ["userId": "abc"])
        manifestStore.synchronize()

        let manifest = manifestStore.manifest(forSessionId: "session-1")
        XCTAssertEqual(manifest?.lastUpdateMs, 5_000)
        XCTAssertEqual(manifest?.sessionAttributes["userId"] as? String, "abc")
    }

    func testRefreshSessionManifestOfUnknownSessionDoesNothing() {
        sut.refreshSessionManifest(sessionId: "no-such-session", nowMs: 5_000, sessionAttributes: [:])
        manifestStore.synchronize()
        XCTAssertNil(manifestStore.manifest(forSessionId: "no-such-session"))
    }

    // MARK: - Replay / fallback ladder

    func testRecoverWithNothingPersistedReturnsEmpty() {
        XCTAssertTrue(sut.recoverPersistedEventsStagingForHarvest().isEmpty)
        XCTAssertTrue(sut.pendingGroupedRecoveryUploads().isEmpty)
    }

    func testRecoverIsNoopWhenFlagDisabled() {
        eventStore.store(makeRecord(uuid: "uuid-1", sessionId: "session-1"))
        eventStore.synchronize()

        NRMAFlags.disableFeatures(NRMAFeatureFlags.NRFeatureFlag_EventPersistence)
        XCTAssertTrue(sut.recoverPersistedEventsStagingForHarvest().isEmpty)
        XCTAssertTrue(sut.pendingGroupedRecoveryUploads().isEmpty, "a disabled flag must not stage anything for a grouped upload either")
    }

    func testRecoverUsesManifestSessionAttributesWhenFound() {
        manifestStore.store(NRSessionManifest(sessionId: "session-1", realAgentId: 7, sessionStartMs: 0, lastUpdateMs: 0,
                                               sessionAttributes: ["userId": "abc"]))
        manifestStore.synchronize()
        eventStore.store(makeRecord(uuid: "uuid-1", sessionId: "session-1"))
        eventStore.synchronize()

        _ = sut.recoverPersistedEventsStagingForHarvest()
        let grouped = sut.pendingGroupedRecoveryUploads()
        XCTAssertEqual(grouped.count, 1)
        let events = grouped[0]["events"] as? [[String: Any]]
        XCTAssertEqual(events?.count, 1)
        XCTAssertEqual(events?[0]["userId"] as? String, "abc")
    }

    // MARK: - Grouped-by-originating-realAgentId recovery
    //
    // Every recovered event ships in its own dedicated upload stamped with the data_token
    // (realAgentId) it was actually recorded under -- it never rides the regular harvest
    // buffer anymore. Ingest resolves `appVersion` purely from data_token's server-side
    // mapping; it ignores both the request's own JSON attributes and any header override
    // (confirmed empirically), so there is no cheaper, event-level way to get this right.

    func testRecoverNeverReturnsEventsDirectly() {
        eventStore.store(makeRecord(uuid: "uuid-1", sessionId: "session-1"))
        eventStore.synchronize()

        XCTAssertTrue(sut.recoverPersistedEventsStagingForHarvest().isEmpty,
                      "recovered events are staged for a dedicated upload, never returned for the regular harvest buffer")
    }

    func testPendingGroupedRecoveryUploadsReturnsTheRecoveredBucket() {
        manifestStore.store(NRSessionManifest(sessionId: "session-1", realAgentId: 42, sessionStartMs: 0, lastUpdateMs: 0,
                                               sessionAttributes: [:]))
        manifestStore.synchronize()
        eventStore.store(makeRecord(uuid: "uuid-1", sessionId: "session-1", eventAttributes: ["orderId": "XYZ"], realAgentId: 42))
        eventStore.synchronize()

        _ = sut.recoverPersistedEventsStagingForHarvest()
        let grouped = sut.pendingGroupedRecoveryUploads()

        XCTAssertEqual(grouped.count, 1)
        XCTAssertEqual((grouped[0]["realAgentId"] as? NSNumber)?.uint64Value, 42)
        XCTAssertEqual(grouped[0]["eventUUIDs"] as? [String], ["uuid-1"])
        let events = grouped[0]["events"] as? [[String: Any]]
        XCTAssertEqual(events?.count, 1)
        XCTAssertEqual(events?[0]["orderId"] as? String, "XYZ")
    }

    func testPendingGroupedRecoveryUploadsBucketsByDistinctRealAgentId() {
        eventStore.store(makeRecord(uuid: "uuid-a1", sessionId: "session-A", realAgentId: 1))
        eventStore.store(makeRecord(uuid: "uuid-a2", sessionId: "session-A", realAgentId: 1))
        eventStore.store(makeRecord(uuid: "uuid-b1", sessionId: "session-B", realAgentId: 2))
        eventStore.synchronize()

        _ = sut.recoverPersistedEventsStagingForHarvest()
        let grouped = sut.pendingGroupedRecoveryUploads()

        XCTAssertEqual(grouped.count, 2, "distinct originating realAgentIds must ship in separate buckets/uploads")
        let eventCountsByRealAgentId = Dictionary(uniqueKeysWithValues: grouped.map {
            (($0["realAgentId"] as! NSNumber).uint64Value, ($0["events"] as! [[String: Any]]).count)
        })
        XCTAssertEqual(eventCountsByRealAgentId[1], 2)
        XCTAssertEqual(eventCountsByRealAgentId[2], 1)
    }

    func testPendingGroupedRecoveryUploadsClearsStateOnRead() {
        eventStore.store(makeRecord(uuid: "uuid-1", sessionId: "session-1"))
        eventStore.synchronize()

        _ = sut.recoverPersistedEventsStagingForHarvest()
        XCTAssertEqual(sut.pendingGroupedRecoveryUploads().count, 1)
        XCTAssertTrue(sut.pendingGroupedRecoveryUploads().isEmpty, "a bucket must only be handed back once")
    }

    // Regression guard for a real duplicate-upload bug found via manual testing: `sut` is
    // a process-wide singleton, so a second `onSessionStart` in the same process (e.g. an
    // agent restart/reseed) before the first sweep's grouped bucket was ever drained used
    // to re-add the same still-undeleted persisted record a second time, and both copies
    // shipped in one upload.
    func testRecoverTwiceBeforeDrainingDoesNotDuplicateTheGroupedBucket() {
        eventStore.store(makeRecord(uuid: "uuid-1", sessionId: "session-1"))
        eventStore.synchronize()

        // Simulate the recovery sweep running twice (e.g. two onSessionStart calls) before
        // anything drains/confirms the bucket in between.
        _ = sut.recoverPersistedEventsStagingForHarvest()
        _ = sut.recoverPersistedEventsStagingForHarvest()

        let grouped = sut.pendingGroupedRecoveryUploads()
        XCTAssertEqual(grouped.count, 1)
        XCTAssertEqual(grouped[0]["eventUUIDs"] as? [String], ["uuid-1"],
                       "the same persisted record re-discovered by a second sweep must not be queued twice")
        XCTAssertEqual((grouped[0]["events"] as? [[String: Any]])?.count, 1,
                       "must not ship the same event twice in one upload")
    }

    func testConfirmGroupedRecoveryUploadSucceededDeletesOnlyThoseEvents() {
        eventStore.store(makeRecord(uuid: "other-uuid", sessionId: "session-B", realAgentId: 2))
        eventStore.store(makeRecord(uuid: "target-uuid", sessionId: "session-A", realAgentId: 1))
        eventStore.synchronize()

        _ = sut.recoverPersistedEventsStagingForHarvest()
        let grouped = sut.pendingGroupedRecoveryUploads()
        let targetBucket = grouped.first { ($0["realAgentId"] as? NSNumber)?.uint64Value == 1 }!
        sut.confirmGroupedRecoveryUploadSucceeded(eventUUIDs: targetBucket["eventUUIDs"] as! [String])
        eventStore.synchronize()

        let remaining = eventStore.fetchAll()
        XCTAssertEqual(remaining.count, 1, "confirming a grouped upload must delete only that bucket's events")
        XCTAssertEqual(remaining.first?.eventUUID, "other-uuid")
    }

    func testUnconfirmedGroupedRecoveryUploadLeavesEventsForRetry() {
        eventStore.store(makeRecord(uuid: "uuid-1", sessionId: "session-1"))
        eventStore.synchronize()

        _ = sut.recoverPersistedEventsStagingForHarvest()
        _ = sut.pendingGroupedRecoveryUploads()
        // Simulate a failed dedicated upload: never call confirmGroupedRecoveryUploadSucceeded().

        XCTAssertEqual(eventStore.fetchAll().count, 1, "a failed grouped upload must not drop the persisted record")

        _ = sut.recoverPersistedEventsStagingForHarvest()
        XCTAssertEqual(sut.pendingGroupedRecoveryUploads().count, 1, "the event must still be recoverable into a grouped bucket on a later retry")
    }

    // When the manifest is missing/corrupt, we never fabricate session-level attribution
    // (osVersion, userId, etc. from whatever session happens to be running right now) --
    // a "current" fallback could be wrong in exactly the ways that matter (different
    // logged-in user, different OS). The record still ships -- just with only its own
    // fields, never dropped.
    func testRecoverShipsOnlyTheEventsOwnFieldsWhenManifestMissing() {
        eventStore.store(makeRecord(uuid: "uuid-1", sessionId: "no-manifest-session",
                                     eventAttributes: ["orderId": "ABC123"]))
        eventStore.synchronize()

        _ = sut.recoverPersistedEventsStagingForHarvest()
        let events = sut.pendingGroupedRecoveryUploads()[0]["events"] as? [[String: Any]]
        XCTAssertEqual(events?.count, 1, "a record with no manifest must never be dropped")
        XCTAssertEqual(events?[0]["orderId"] as? String, "ABC123")
        XCTAssertNil(events?[0]["userId"], "must never fabricate attribution it can't vouch for")
        XCTAssertEqual(events?[0][kNRMA_RA_sessionId] as? String, "no-manifest-session")
    }

    func testRecoverPreservesOriginalTimestampAndSessionId() {
        eventStore.store(makeRecord(uuid: "uuid-1", sessionId: "original-session", timestampMs: 42_000))
        eventStore.synchronize()

        _ = sut.recoverPersistedEventsStagingForHarvest()
        let events = sut.pendingGroupedRecoveryUploads()[0]["events"] as? [[String: Any]]
        XCTAssertEqual(events?[0][kNRMA_RA_timestamp] as? Int64, 42_000)
        XCTAssertEqual(events?[0][kNRMA_RA_sessionId] as? String, "original-session")
    }

    // Regression guard for a real bug found via manual testing: a recovered
    // custom event's own content (its custom attributes, and the
    // timestamp/sessionElapsedTime/eventType baked into its original
    // JSONObject output) was being discarded entirely -- only session-level
    // attributes survived, so every recovered event shipped as an empty shell.
    func testRecoverPreservesTheEventsOwnAttributes() {
        eventStore.store(makeRecord(uuid: "uuid-1", sessionId: "session-1",
                                     eventAttributes: ["orderId": "ABC123", "revenue": 42.5, "eventType": "CustomOrder"]))
        eventStore.synchronize()

        _ = sut.recoverPersistedEventsStagingForHarvest()
        let grouped = sut.pendingGroupedRecoveryUploads()
        XCTAssertEqual(grouped.count, 1)
        let events = grouped[0]["events"] as? [[String: Any]]
        XCTAssertEqual(events?.count, 1)
        XCTAssertEqual(events?[0]["orderId"] as? String, "ABC123",
                       "the event's own custom attributes must survive into the recovered payload, not just session-level attributes")
        XCTAssertEqual(events?[0]["revenue"] as? Double, 42.5)
    }

    func testRecoverEventOwnAttributesDoNotOverrideAuthoritativeTimestampSessionIdEventType() {
        // A deliberately mismatched/stale "timestamp" inside record.attributes
        // (as could happen with a malformed/old blob) must never win over the
        // record's own authoritative fields.
        eventStore.store(makeRecord(uuid: "uuid-1", sessionId: "original-session", timestampMs: 42_000,
                                     eventAttributes: [kNRMA_RA_timestamp: 999, kNRMA_RA_eventType: "WrongType"]))
        eventStore.synchronize()

        _ = sut.recoverPersistedEventsStagingForHarvest()
        let events = sut.pendingGroupedRecoveryUploads()[0]["events"] as? [[String: Any]]
        XCTAssertEqual(events?[0][kNRMA_RA_timestamp] as? Int64, 42_000)
        XCTAssertEqual(events?[0][kNRMA_RA_sessionId] as? String, "original-session")
        XCTAssertEqual(events?[0][kNRMA_RA_eventType] as? String, "Mobile")
    }

    // MARK: - Crash path

    func testReattributeCrashAttributesReturnsManifestSessionAttributesWhenFound() {
        manifestStore.store(NRSessionManifest(sessionId: "crashed-session", realAgentId: 7, sessionStartMs: 0, lastUpdateMs: 0,
                                               sessionAttributes: ["userId": "abc"]))
        manifestStore.synchronize()

        let reattributed = sut.reattributeCrashAttributes(forSessionId: "crashed-session")
        XCTAssertEqual(reattributed?["userId"] as? String, "abc")
    }

    func testReattributeCrashAttributesReturnsNilWhenManifestMissing() {
        XCTAssertNil(sut.reattributeCrashAttributes(forSessionId: "no-such-session"))
    }

    func testReattributeCrashAttributesReturnsNilWhenFlagDisabled() {
        manifestStore.store(NRSessionManifest(sessionId: "crashed-session", realAgentId: 7, sessionStartMs: 0, lastUpdateMs: 0,
                                               sessionAttributes: [:]))
        manifestStore.synchronize()

        NRMAFlags.disableFeatures(NRMAFeatureFlags.NRFeatureFlag_EventPersistence)
        XCTAssertNil(sut.reattributeCrashAttributes(forSessionId: "crashed-session"),
                     "reattribution must be a no-op when the feature flag is disabled")
    }

    func testClaimPersistedEventsForCrashSessionIdReturnsOnlyThatSessionsEvents() {
        manifestStore.store(NRSessionManifest(sessionId: "crashed-session", realAgentId: 7, sessionStartMs: 0, lastUpdateMs: 0,
                                               sessionAttributes: ["userId": "abc"]))
        eventStore.store(makeRecord(uuid: "crash-uuid", sessionId: "crashed-session",
                                     eventAttributes: ["orderId": "ABC123"]))
        eventStore.store(makeRecord(uuid: "other-uuid", sessionId: "other-session"))
        manifestStore.synchronize()
        eventStore.synchronize()

        let payloads = sut.claimPersistedEvents(forCrashSessionId: "crashed-session")
        XCTAssertEqual(payloads.count, 1)
        XCTAssertEqual(payloads[0]["userId"] as? String, "abc")
        XCTAssertEqual(payloads[0]["orderId"] as? String, "ABC123")
        XCTAssertEqual(payloads[0][kNRMA_RA_sessionId] as? String, "crashed-session")

        eventStore.synchronize()
        let remaining = eventStore.fetchAll()
        XCTAssertEqual(remaining.count, 1, "claiming must delete only the claimed session's events")
        XCTAssertEqual(remaining.first?.sessionId, "other-session")
    }

    func testClaimPersistedEventsForCrashSessionIdShipsOnlyTheEventsOwnFieldsWhenManifestMissing() {
        eventStore.store(makeRecord(uuid: "crash-uuid", sessionId: "crashed-session"))
        eventStore.synchronize()

        let payloads = sut.claimPersistedEvents(forCrashSessionId: "crashed-session")
        XCTAssertEqual(payloads.count, 1, "a record with no manifest must never be dropped")
        XCTAssertNil(payloads[0]["userId"], "must never fabricate attribution it can't vouch for")
    }

    func testClaimPersistedEventsForCrashSessionIdDeletesClaimedEvents() {
        eventStore.store(makeRecord(uuid: "crash-uuid", sessionId: "crashed-session"))
        eventStore.synchronize()

        _ = sut.claimPersistedEvents(forCrashSessionId: "crashed-session")
        eventStore.synchronize()

        XCTAssertTrue(sut.claimPersistedEvents(forCrashSessionId: "crashed-session").isEmpty,
                      "a second claim for the same session must find nothing left to claim")
    }

    func testClaimPersistedEventsForCrashSessionIdReturnsEmptyWhenNoRecordsForSession() {
        XCTAssertTrue(sut.claimPersistedEvents(forCrashSessionId: "no-such-session").isEmpty)
    }

    func testClaimPersistedEventsForCrashSessionIdReturnsEmptyWhenFlagDisabled() {
        eventStore.store(makeRecord(uuid: "crash-uuid", sessionId: "crashed-session"))
        eventStore.synchronize()

        NRMAFlags.disableFeatures(NRMAFeatureFlags.NRFeatureFlag_EventPersistence)
        XCTAssertTrue(sut.claimPersistedEvents(forCrashSessionId: "crashed-session").isEmpty)
    }

    // MARK: - In-flight dedup against a concurrent live harvest

    // Regression guard for a real duplicate-upload bug found via manual testing:
    // `onSessionStart` (and this sweep) can run again mid-process -- on foreground,
    // `startNewSessionForUserId:`, or the 4-hour session restart -- while an earlier,
    // still in-flight harvest has already pulled this exact event off the live buffer
    // and marked it pending confirmation, but the network request hasn't resolved yet.
    // A sweep that ignores that must not re-stage (and thus re-upload) the same event.
    func testRecoverSkipsEventsCurrentlyPendingConfirmationFromALiveHarvest() {
        eventStore.store(makeRecord(uuid: "in-flight-uuid", sessionId: "session-1"))
        eventStore.synchronize()

        sut.markEventsPendingConfirmation(eventUUIDs: ["in-flight-uuid"])

        _ = sut.recoverPersistedEventsStagingForHarvest()
        XCTAssertTrue(sut.pendingGroupedRecoveryUploads().isEmpty,
                      "a record currently staged for an in-flight harvest attempt must not be re-staged by a concurrent/later sweep")
    }

    func testRecoverStillRecoversEventsNotPendingConfirmation() {
        eventStore.store(makeRecord(uuid: "in-flight-uuid", sessionId: "session-1"))
        eventStore.store(makeRecord(uuid: "unrelated-uuid", sessionId: "session-1"))
        eventStore.synchronize()

        sut.markEventsPendingConfirmation(eventUUIDs: ["in-flight-uuid"])

        _ = sut.recoverPersistedEventsStagingForHarvest()
        let grouped = sut.pendingGroupedRecoveryUploads()
        XCTAssertEqual(grouped.count, 1)
        XCTAssertEqual(grouped[0]["eventUUIDs"] as? [String], ["unrelated-uuid"],
                       "only the in-flight record should be held back, not every record in the same sweep")
    }

    func testRecoverEventuallyRecoversAfterConfirmationResolves() {
        eventStore.store(makeRecord(uuid: "in-flight-uuid", sessionId: "session-1"))
        eventStore.synchronize()

        sut.markEventsPendingConfirmation(eventUUIDs: ["in-flight-uuid"])
        _ = sut.recoverPersistedEventsStagingForHarvest()
        XCTAssertTrue(sut.pendingGroupedRecoveryUploads().isEmpty)

        // The in-flight harvest resolves (success or offline-persisted) and confirms,
        // deleting the persisted copy -- it must not resurrect as "still recoverable".
        sut.confirmLastRecoveryHarvestSucceeded()
        eventStore.synchronize()

        _ = sut.recoverPersistedEventsStagingForHarvest()
        XCTAssertTrue(sut.pendingGroupedRecoveryUploads().isEmpty,
                      "once confirmed, the event's persisted copy is gone -- nothing left to recover")
    }

    // MARK: - excludingSessionId (crash/recovery partitioning)

    func testRecoverExcludingSessionIdOmitsOnlyThatSessionsEvents() {
        eventStore.store(makeRecord(uuid: "uuid-a", sessionId: "session-A"))
        eventStore.store(makeRecord(uuid: "uuid-b", sessionId: "session-B"))
        eventStore.synchronize()

        _ = sut.recoverPersistedEventsStagingForHarvest(excludingSessionId: "session-A")
        let grouped = sut.pendingGroupedRecoveryUploads()
        XCTAssertEqual(grouped.count, 1)
        let events = grouped[0]["events"] as? [[String: Any]]
        XCTAssertEqual(events?.count, 1)
        XCTAssertEqual(events?[0][kNRMA_RA_sessionId] as? String, "session-B")
    }

    func testRecoverExcludingSessionIdLeavesExcludedEventOnDiskForLaterClaim() {
        eventStore.store(makeRecord(uuid: "uuid-a", sessionId: "session-A"))
        eventStore.synchronize()

        _ = sut.recoverPersistedEventsStagingForHarvest(excludingSessionId: "session-A")
        eventStore.synchronize()

        XCTAssertEqual(eventStore.fetchAll().count, 1,
                       "an excluded session's event must not be staged by the ordinary recovery sweep")

        let claimed = sut.claimPersistedEvents(forCrashSessionId: "session-A")
        XCTAssertEqual(claimed.count, 1, "the excluded event must still be available for the crash path to claim")
    }

    func testRecoverWithNilExcludingSessionIdBehavesAsBefore() {
        eventStore.store(makeRecord(uuid: "uuid-a", sessionId: "session-A"))
        eventStore.synchronize()

        _ = sut.recoverPersistedEventsStagingForHarvest(excludingSessionId: nil)
        XCTAssertEqual(sut.pendingGroupedRecoveryUploads().count, 1)
    }

    func testRecoverAndClaimPartitionEventsWithNoDuplicatesOrGaps() {
        eventStore.store(makeRecord(uuid: "uuid-a", sessionId: "session-A"))
        eventStore.store(makeRecord(uuid: "uuid-b", sessionId: "session-B"))
        eventStore.synchronize()

        _ = sut.recoverPersistedEventsStagingForHarvest(excludingSessionId: "session-A")
        let grouped = sut.pendingGroupedRecoveryUploads()
        let recoveredSessionIds = Set(grouped.flatMap { bucket in
            (bucket["events"] as! [[String: Any]]).map { $0[kNRMA_RA_sessionId] as? String }
        })
        let claimed = sut.claimPersistedEvents(forCrashSessionId: "session-A")
        let claimedSessionIds = Set(claimed.map { $0[kNRMA_RA_sessionId] as? String })

        XCTAssertEqual(recoveredSessionIds, ["session-B"])
        XCTAssertEqual(claimedSessionIds, ["session-A"])
        XCTAssertTrue(recoveredSessionIds.isDisjoint(with: claimedSessionIds))
    }

    // MARK: - Pending confirmation (fresh events pulled for a normal harvest)

    func testMarkEventsPendingConfirmationThenConfirmDeletesThem() {
        // Simulates a *freshly-recorded* event (never recovered) that gets
        // pulled out of the live buffer for an ordinary harvest attempt.
        eventStore.store(makeRecord(uuid: "fresh-uuid", sessionId: "session-1"))
        eventStore.synchronize()

        sut.markEventsPendingConfirmation(eventUUIDs: ["fresh-uuid"])
        sut.confirmLastRecoveryHarvestSucceeded()
        eventStore.synchronize()

        XCTAssertTrue(eventStore.fetchAll().isEmpty,
                      "a freshly-harvested event's persisted copy must be deleted once that harvest is confirmed successful -- otherwise it would be wrongly recovered as a duplicate on a later relaunch")
    }

    func testMarkEventsPendingConfirmationWithoutConfirmLeavesEventIntact() {
        eventStore.store(makeRecord(uuid: "fresh-uuid", sessionId: "session-1"))
        eventStore.synchronize()

        sut.markEventsPendingConfirmation(eventUUIDs: ["fresh-uuid"])
        // Simulate a failed harvest: never confirm.

        XCTAssertEqual(eventStore.fetchAll().count, 1,
                       "a failed/unattempted harvest must not drop the persisted record")
    }

    func testMarkEventsPendingConfirmationIgnoresEmptyArray() {
        eventStore.store(makeRecord(uuid: "fresh-uuid", sessionId: "session-1"))
        eventStore.synchronize()

        sut.markEventsPendingConfirmation(eventUUIDs: [])
        sut.confirmLastRecoveryHarvestSucceeded()
        eventStore.synchronize()

        XCTAssertEqual(eventStore.fetchAll().count, 1, "confirming with nothing pending must not delete unrelated records")
    }

    // MARK: - Retention

    func testRetentionSweepEvictsStaleEventAndItsUnreferencedManifest() {
        let maxAgeMs = NREventPersistenceController.defaultRetentionMs
        let nowMs: Int64 = 100 * 24 * 60 * 60 * 1000
        eventStore.store(makeRecord(uuid: "stale-uuid", sessionId: "stale-session", timestampMs: nowMs - maxAgeMs - 1_000))
        manifestStore.store(NRSessionManifest(sessionId: "stale-session", realAgentId: 7, sessionStartMs: 0,
                                               lastUpdateMs: nowMs - maxAgeMs - 1_000, sessionAttributes: [:]))
        eventStore.synchronize()
        manifestStore.synchronize()

        sut.performRetentionSweep(nowMs: nowMs)
        eventStore.synchronize()
        manifestStore.synchronize()

        XCTAssertTrue(eventStore.fetchAll().isEmpty)
        XCTAssertNil(manifestStore.manifest(forSessionId: "stale-session"))
    }

    func testRetentionSweepKeepsFreshEventAndItsManifest() {
        let nowMs: Int64 = 100 * 24 * 60 * 60 * 1000
        eventStore.store(makeRecord(uuid: "fresh-uuid", sessionId: "fresh-session", timestampMs: nowMs - 1_000))
        manifestStore.store(NRSessionManifest(sessionId: "fresh-session", realAgentId: 7, sessionStartMs: 0,
                                               lastUpdateMs: nowMs - 1_000, sessionAttributes: [:]))
        eventStore.synchronize()
        manifestStore.synchronize()

        sut.performRetentionSweep(nowMs: nowMs)
        eventStore.synchronize()
        manifestStore.synchronize()

        XCTAssertEqual(eventStore.fetchAll().count, 1)
        XCTAssertNotNil(manifestStore.manifest(forSessionId: "fresh-session"))
    }

    // MARK: - Helpers

    private func makeRecord(uuid: String,
                             sessionId: String,
                             timestampMs: Int64 = 1_000,
                             eventAttributes: [String: Any] = [:],
                             realAgentId: UInt64 = 7) -> NREventRecord {
        NREventRecord(eventUUID: uuid,
                       eventType: "Mobile",
                       name: nil,
                       timestamp: timestampMs,
                       attributes: eventAttributes,
                       sessionId: sessionId,
                       realAgentId: realAgentId)
    }
}
