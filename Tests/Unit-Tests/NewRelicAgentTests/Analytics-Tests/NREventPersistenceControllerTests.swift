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
        sut.writeSessionManifest(sessionId: "session-1", realAgentId: 7, sessionStartMs: 1_000, stableAttributes: ["appVersion": "1.0"])
        manifestStore.synchronize()

        let manifest = manifestStore.manifest(forSessionId: "session-1")
        XCTAssertEqual(manifest?.stableAttributes["appVersion"] as? String, "1.0")
        XCTAssertEqual(manifest?.lastUpdateMs, 1_000)
    }

    func testRefreshSessionManifestUpdatesLastUpdateMs() {
        sut.writeSessionManifest(sessionId: "session-1", realAgentId: 7, sessionStartMs: 1_000, stableAttributes: [:])
        manifestStore.synchronize()

        sut.refreshSessionManifest(sessionId: "session-1", nowMs: 5_000)
        manifestStore.synchronize()

        XCTAssertEqual(manifestStore.manifest(forSessionId: "session-1")?.lastUpdateMs, 5_000)
    }

    func testRefreshSessionManifestOfUnknownSessionDoesNothing() {
        sut.refreshSessionManifest(sessionId: "no-such-session", nowMs: 5_000)
        manifestStore.synchronize()
        XCTAssertNil(manifestStore.manifest(forSessionId: "no-such-session"))
    }

    // MARK: - Replay / fallback ladder

    func testRecoverWithNothingPersistedReturnsEmpty() {
        XCTAssertTrue(sut.recoverPersistedEventsStagingForHarvest(currentSessionAttributes: [:]).isEmpty)
    }

    func testRecoverIsNoopWhenFlagDisabled() {
        eventStore.store(makeRecord(uuid: "uuid-1", sessionId: "session-1"))
        eventStore.synchronize()

        NRMAFlags.disableFeatures(NRMAFeatureFlags.NRFeatureFlag_EventPersistence)
        XCTAssertTrue(sut.recoverPersistedEventsStagingForHarvest(currentSessionAttributes: [:]).isEmpty)
    }

    func testRecoverUsesManifestStableAttributesWhenFound() {
        manifestStore.store(NRSessionManifest(sessionId: "session-1", realAgentId: 7, sessionStartMs: 0, lastUpdateMs: 0,
                                               stableAttributes: ["appVersion": "1.0"]))
        manifestStore.synchronize()
        eventStore.store(makeRecord(uuid: "uuid-1", sessionId: "session-1"))
        eventStore.synchronize()

        let payloads = sut.recoverPersistedEventsStagingForHarvest(currentSessionAttributes: [:])
        XCTAssertEqual(payloads.count, 1)
        XCTAssertEqual(payloads[0]["appVersion"] as? String, "1.0")
    }

    func testRecoverFallsBackToCurrentSessionAttributesWhenManifestMissing() {
        eventStore.store(makeRecord(uuid: "uuid-1", sessionId: "no-manifest-session"))
        eventStore.synchronize()

        let payloads = sut.recoverPersistedEventsStagingForHarvest(currentSessionAttributes: ["currentUserId": "fallback-user"])
        XCTAssertEqual(payloads.count, 1)
        XCTAssertEqual(payloads[0]["currentUserId"] as? String, "fallback-user", "a record with no manifest must never be dropped -- it falls back to current-session attributes")
    }

    func testRecoverPreservesOriginalTimestampAndSessionId() {
        eventStore.store(makeRecord(uuid: "uuid-1", sessionId: "original-session", timestampMs: 42_000))
        eventStore.synchronize()

        let payloads = sut.recoverPersistedEventsStagingForHarvest(currentSessionAttributes: [:])
        XCTAssertEqual(payloads[0][kNRMA_RA_timestamp] as? Int64, 42_000)
        XCTAssertEqual(payloads[0][kNRMA_RA_sessionId] as? String, "original-session")
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

        let payloads = sut.recoverPersistedEventsStagingForHarvest(currentSessionAttributes: [:])
        XCTAssertEqual(payloads.count, 1)
        XCTAssertEqual(payloads[0]["orderId"] as? String, "ABC123",
                       "the event's own custom attributes must survive into the recovered payload, not just session-level attributes")
        XCTAssertEqual(payloads[0]["revenue"] as? Double, 42.5)
    }

    func testRecoverEventOwnAttributesDoNotOverrideAuthoritativeTimestampSessionIdEventType() {
        // A deliberately mismatched/stale "timestamp" inside record.attributes
        // (as could happen with a malformed/old blob) must never win over the
        // record's own authoritative fields.
        eventStore.store(makeRecord(uuid: "uuid-1", sessionId: "original-session", timestampMs: 42_000,
                                     eventAttributes: [kNRMA_RA_timestamp: 999, kNRMA_RA_eventType: "WrongType"]))
        eventStore.synchronize()

        let payloads = sut.recoverPersistedEventsStagingForHarvest(currentSessionAttributes: [:])
        XCTAssertEqual(payloads[0][kNRMA_RA_timestamp] as? Int64, 42_000)
        XCTAssertEqual(payloads[0][kNRMA_RA_sessionId] as? String, "original-session")
        XCTAssertEqual(payloads[0][kNRMA_RA_eventType] as? String, "Mobile")
    }

    // MARK: - Crash path

    func testReattributeCrashAttributesReturnsManifestStableAttributesWhenFound() {
        manifestStore.store(NRSessionManifest(sessionId: "crashed-session", realAgentId: 7, sessionStartMs: 0, lastUpdateMs: 0,
                                               stableAttributes: ["appVersion": "2.0"]))
        manifestStore.synchronize()

        let reattributed = sut.reattributeCrashAttributes(forSessionId: "crashed-session")
        XCTAssertEqual(reattributed?["appVersion"] as? String, "2.0")
    }

    func testReattributeCrashAttributesReturnsNilWhenManifestMissing() {
        XCTAssertNil(sut.reattributeCrashAttributes(forSessionId: "no-such-session"))
    }

    func testReattributeCrashAttributesReturnsNilWhenFlagDisabled() {
        manifestStore.store(NRSessionManifest(sessionId: "crashed-session", realAgentId: 7, sessionStartMs: 0, lastUpdateMs: 0,
                                               stableAttributes: ["appVersion": "2.0"]))
        manifestStore.synchronize()

        NRMAFlags.disableFeatures(NRMAFeatureFlags.NRFeatureFlag_EventPersistence)
        XCTAssertNil(sut.reattributeCrashAttributes(forSessionId: "crashed-session"),
                     "reattribution must be a no-op when the feature flag is disabled")
    }

    func testClaimPersistedEventsForCrashSessionIdReturnsOnlyThatSessionsEvents() {
        manifestStore.store(NRSessionManifest(sessionId: "crashed-session", realAgentId: 7, sessionStartMs: 0, lastUpdateMs: 0,
                                               stableAttributes: ["appVersion": "2.0"]))
        eventStore.store(makeRecord(uuid: "crash-uuid", sessionId: "crashed-session",
                                     eventAttributes: ["orderId": "ABC123"]))
        eventStore.store(makeRecord(uuid: "other-uuid", sessionId: "other-session"))
        manifestStore.synchronize()
        eventStore.synchronize()

        let payloads = sut.claimPersistedEvents(forCrashSessionId: "crashed-session")
        XCTAssertEqual(payloads.count, 1)
        XCTAssertEqual(payloads[0]["appVersion"] as? String, "2.0")
        XCTAssertEqual(payloads[0]["orderId"] as? String, "ABC123")
        XCTAssertEqual(payloads[0][kNRMA_RA_sessionId] as? String, "crashed-session")

        eventStore.synchronize()
        let remaining = eventStore.fetchAll()
        XCTAssertEqual(remaining.count, 1, "claiming must delete only the claimed session's events")
        XCTAssertEqual(remaining.first?.sessionId, "other-session")
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

    // MARK: - excludingSessionId (crash/recovery partitioning)

    func testRecoverExcludingSessionIdOmitsOnlyThatSessionsEvents() {
        eventStore.store(makeRecord(uuid: "uuid-a", sessionId: "session-A"))
        eventStore.store(makeRecord(uuid: "uuid-b", sessionId: "session-B"))
        eventStore.synchronize()

        let payloads = sut.recoverPersistedEventsStagingForHarvest(currentSessionAttributes: [:], excludingSessionId: "session-A")
        XCTAssertEqual(payloads.count, 1)
        XCTAssertEqual(payloads[0][kNRMA_RA_sessionId] as? String, "session-B")
    }

    func testRecoverExcludingSessionIdLeavesExcludedEventOnDiskForLaterClaim() {
        eventStore.store(makeRecord(uuid: "uuid-a", sessionId: "session-A"))
        eventStore.synchronize()

        _ = sut.recoverPersistedEventsStagingForHarvest(currentSessionAttributes: [:], excludingSessionId: "session-A")
        sut.confirmLastRecoveryHarvestSucceeded()
        eventStore.synchronize()

        XCTAssertEqual(eventStore.fetchAll().count, 1,
                       "an excluded session's event must not be staged (and thus never confirmed/deleted) by the ordinary recovery sweep")

        let claimed = sut.claimPersistedEvents(forCrashSessionId: "session-A")
        XCTAssertEqual(claimed.count, 1, "the excluded event must still be available for the crash path to claim")
    }

    func testRecoverWithNilExcludingSessionIdBehavesAsBefore() {
        eventStore.store(makeRecord(uuid: "uuid-a", sessionId: "session-A"))
        eventStore.synchronize()

        let payloads = sut.recoverPersistedEventsStagingForHarvest(currentSessionAttributes: [:], excludingSessionId: nil)
        XCTAssertEqual(payloads.count, 1)
    }

    func testRecoverAndClaimPartitionEventsWithNoDuplicatesOrGaps() {
        eventStore.store(makeRecord(uuid: "uuid-a", sessionId: "session-A"))
        eventStore.store(makeRecord(uuid: "uuid-b", sessionId: "session-B"))
        eventStore.synchronize()

        let recovered = sut.recoverPersistedEventsStagingForHarvest(currentSessionAttributes: [:], excludingSessionId: "session-A")
        let claimed = sut.claimPersistedEvents(forCrashSessionId: "session-A")

        let recoveredSessionIds = Set(recovered.map { $0[kNRMA_RA_sessionId] as? String })
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

    // MARK: - Confirmation

    func testConfirmSuccessDeletesStagedEvents() {
        eventStore.store(makeRecord(uuid: "uuid-1", sessionId: "session-1"))
        eventStore.synchronize()

        _ = sut.recoverPersistedEventsStagingForHarvest(currentSessionAttributes: [:])
        sut.confirmLastRecoveryHarvestSucceeded()
        eventStore.synchronize()

        XCTAssertTrue(eventStore.fetchAll().isEmpty)
    }

    func testUnconfirmedRecoveryLeavesEventsForRetry() {
        eventStore.store(makeRecord(uuid: "uuid-1", sessionId: "session-1"))
        eventStore.synchronize()

        let firstAttempt = sut.recoverPersistedEventsStagingForHarvest(currentSessionAttributes: [:])
        XCTAssertEqual(firstAttempt.count, 1)
        // Simulate a failed harvest: never call confirmLastRecoveryHarvestSucceeded().

        XCTAssertEqual(eventStore.fetchAll().count, 1, "a failed/unconfirmed harvest must not drop the persisted record")

        let secondAttempt = sut.recoverPersistedEventsStagingForHarvest(currentSessionAttributes: [:])
        XCTAssertEqual(secondAttempt.count, 1, "the event must still be recoverable on a later retry")
    }

    // MARK: - Retention

    func testRetentionSweepEvictsStaleEventAndItsUnreferencedManifest() {
        let maxAgeMs = NREventPersistenceController.defaultRetentionMs
        let nowMs: Int64 = 100 * 24 * 60 * 60 * 1000
        eventStore.store(makeRecord(uuid: "stale-uuid", sessionId: "stale-session", timestampMs: nowMs - maxAgeMs - 1_000))
        manifestStore.store(NRSessionManifest(sessionId: "stale-session", realAgentId: 7, sessionStartMs: 0,
                                               lastUpdateMs: nowMs - maxAgeMs - 1_000, stableAttributes: [:]))
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
                                               lastUpdateMs: nowMs - 1_000, stableAttributes: [:]))
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
                             eventAttributes: [String: Any] = [:]) -> NREventRecord {
        NREventRecord(eventUUID: uuid,
                       eventType: "Mobile",
                       name: nil,
                       timestamp: timestampMs,
                       attributes: eventAttributes,
                       sessionId: sessionId,
                       realAgentId: 7)
    }
}
