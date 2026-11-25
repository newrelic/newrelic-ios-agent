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
    }

    func testRecoverIsNoopWhenFlagDisabled() {
        eventStore.store(makeRecord(uuid: "uuid-1", sessionId: "session-1"))
        eventStore.synchronize()

        NRMAFlags.disableFeatures(NRMAFeatureFlags.NRFeatureFlag_EventPersistence)
        XCTAssertTrue(sut.recoverPersistedEventsStagingForHarvest().isEmpty)
    }

    func testRecoverUsesManifestSessionAttributesWhenFound() {
        manifestStore.store(NRSessionManifest(sessionId: "session-1", realAgentId: 7, sessionStartMs: 0, lastUpdateMs: 0,
                                               sessionAttributes: ["userId": "abc"]))
        manifestStore.synchronize()
        eventStore.store(makeRecord(uuid: "uuid-1", sessionId: "session-1"))
        eventStore.synchronize()

        let payloads = sut.recoverPersistedEventsStagingForHarvest()
        XCTAssertEqual(payloads.count, 1)
        XCTAssertEqual(payloads[0]["userId"] as? String, "abc")
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

        let payloads = sut.recoverPersistedEventsStagingForHarvest()
        XCTAssertEqual(payloads.count, 1, "a record with no manifest must never be dropped")
        XCTAssertEqual(payloads[0]["orderId"] as? String, "ABC123")
        XCTAssertNil(payloads[0]["userId"], "must never fabricate attribution it can't vouch for")
        XCTAssertEqual(payloads[0][kNRMA_RA_sessionId] as? String, "no-manifest-session")
    }

    func testRecoverPreservesOriginalTimestampAndSessionId() {
        eventStore.store(makeRecord(uuid: "uuid-1", sessionId: "original-session", timestampMs: 42_000))
        eventStore.synchronize()

        let payloads = sut.recoverPersistedEventsStagingForHarvest()
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

        let payloads = sut.recoverPersistedEventsStagingForHarvest()
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

        let payloads = sut.recoverPersistedEventsStagingForHarvest()
        XCTAssertEqual(payloads[0][kNRMA_RA_timestamp] as? Int64, 42_000)
        XCTAssertEqual(payloads[0][kNRMA_RA_sessionId] as? String, "original-session")
        XCTAssertEqual(payloads[0][kNRMA_RA_eventType] as? String, "Mobile")
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

    // MARK: - excludingSessionId (crash/recovery partitioning)

    func testRecoverExcludingSessionIdOmitsOnlyThatSessionsEvents() {
        eventStore.store(makeRecord(uuid: "uuid-a", sessionId: "session-A"))
        eventStore.store(makeRecord(uuid: "uuid-b", sessionId: "session-B"))
        eventStore.synchronize()

        let payloads = sut.recoverPersistedEventsStagingForHarvest(excludingSessionId: "session-A")
        XCTAssertEqual(payloads.count, 1)
        XCTAssertEqual(payloads[0][kNRMA_RA_sessionId] as? String, "session-B")
    }

    func testRecoverExcludingSessionIdLeavesExcludedEventOnDiskForLaterClaim() {
        eventStore.store(makeRecord(uuid: "uuid-a", sessionId: "session-A"))
        eventStore.synchronize()

        _ = sut.recoverPersistedEventsStagingForHarvest(excludingSessionId: "session-A")
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

        let payloads = sut.recoverPersistedEventsStagingForHarvest(excludingSessionId: nil)
        XCTAssertEqual(payloads.count, 1)
    }

    func testRecoverAndClaimPartitionEventsWithNoDuplicatesOrGaps() {
        eventStore.store(makeRecord(uuid: "uuid-a", sessionId: "session-A"))
        eventStore.store(makeRecord(uuid: "uuid-b", sessionId: "session-B"))
        eventStore.synchronize()

        let recovered = sut.recoverPersistedEventsStagingForHarvest(excludingSessionId: "session-A")
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

        _ = sut.recoverPersistedEventsStagingForHarvest()
        sut.confirmLastRecoveryHarvestSucceeded()
        eventStore.synchronize()

        XCTAssertTrue(eventStore.fetchAll().isEmpty)
    }

    func testUnconfirmedRecoveryLeavesEventsForRetry() {
        eventStore.store(makeRecord(uuid: "uuid-1", sessionId: "session-1"))
        eventStore.synchronize()

        let firstAttempt = sut.recoverPersistedEventsStagingForHarvest()
        XCTAssertEqual(firstAttempt.count, 1)
        // Simulate a failed harvest: never call confirmLastRecoveryHarvestSucceeded().

        XCTAssertEqual(eventStore.fetchAll().count, 1, "a failed/unconfirmed harvest must not drop the persisted record")

        let secondAttempt = sut.recoverPersistedEventsStagingForHarvest()
        XCTAssertEqual(secondAttempt.count, 1, "the event must still be recoverable on a later retry")
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

// MARK: - Stress tests

final class NREventPersistenceStressTests: XCTestCase {

    private var storePath: String!
    private var eventStore: NRFileEventStore!
    private var manifestStore: NRSessionManifestStore!
    private var sut: NREventPersistenceController!

    override func setUp() {
        super.setUp()
        NRMAFlags.enableFeatures(NRMAFeatureFlags.NRFeatureFlag_EventPersistence)
        storePath = NSTemporaryDirectory().appending("NREventPersistenceStressTests-\(UUID().uuidString)")
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

    private func record(_ i: Int, session: String = "s1", ts: Int64? = nil, attrs: [String: Any] = [:]) {
        sut.recordEvent(eventUUID: "uuid-\(i)", eventType: "Mobile", timestampMs: ts ?? Int64(i),
                        attributes: attrs, sessionId: session, realAgentId: 1)
    }

    private var cacheRoot: String { (storePath as NSString).appendingPathComponent("nr_event_cache") }

    /// UUIDs of every event file across all session directories (manifests excluded).
    private func eventFilesOnDisk() -> Set<String> {
        var uuids = Set<String>()
        let sessions = (try? FileManager.default.contentsOfDirectory(atPath: cacheRoot)) ?? []
        for session in sessions {
            let dir = (cacheRoot as NSString).appendingPathComponent(session)
            for name in (try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []
            where name.hasSuffix(".json") && name != "_manifest.json" {
                uuids.insert((name as NSString).deletingPathExtension)
            }
        }
        return uuids
    }

    // 1. Burst writes from many threads: every event lands exactly once, and report timing.
    func testBurstConcurrentWrites() {
        let total = 5_000
        let start = Date()
        DispatchQueue.concurrentPerform(iterations: total) { self.record($0) }
        let enqueued = Date().timeIntervalSince(start)
        eventStore.synchronize()
        let drained = Date().timeIntervalSince(start)
        print("STRESS burst \(total): enqueue=\(enqueued)s drained=\(drained)s")

        let uuids = Set(eventStore.fetchAll().map { $0.eventUUID })
        XCTAssertEqual(uuids.count, total)
        XCTAssertEqual(eventFilesOnDisk(), uuids, "files on disk must match what the store returns")
    }

    // 1b. Writing past the 1000 cap: the cap is only enforced by the retention sweep.
    func testOverflowPastCapUntilSweep() {
        let total = 3_000
        DispatchQueue.concurrentPerform(iterations: total) { self.record($0) }
        eventStore.synchronize()
        let before = eventStore.fetchAll().count
        print("STRESS overflow: \(before) persisted before sweep (cap \(NREventPersistenceController.defaultMaxEventCount))")

        sut.performRetentionSweep(nowMs: Int64(total))
        eventStore.synchronize()
        XCTAssertEqual(eventStore.fetchAll().count, NREventPersistenceController.defaultMaxEventCount)
        XCTAssertEqual(eventFilesOnDisk().count, NREventPersistenceController.defaultMaxEventCount)
    }

    // 1c. Large payloads.
    func testLargePayloads() {
        let big = String(repeating: "x", count: 100_000)
        DispatchQueue.concurrentPerform(iterations: 200) { self.record($0, attrs: ["blob": big]) }
        eventStore.synchronize()
        XCTAssertEqual(eventStore.fetchAll().count, 200)
    }

    // 2. Mixed random operations from many threads, then check invariants.
    func testRandomOperationFuzz() {
        let ops = 8_000
        let live = NSLock()
        var expectedLive = Set<Int>()   // written and not discarded
        DispatchQueue.concurrentPerform(iterations: ops) { i in
            switch Int.random(in: 0..<6) {
            case 0, 1, 2:
                self.record(i)
                live.lock(); expectedLive.insert(i); live.unlock()
            case 3:
                let victim = Int.random(in: 0..<ops)
                // Only discard ids we know were written *before* this call to avoid ordering ambiguity.
                live.lock(); let known = expectedLive.contains(victim); if known { expectedLive.remove(victim) }; live.unlock()
                if known { self.sut.discardPersistedEvent(eventUUID: "uuid-\(victim)") }
            case 4:
                _ = self.sut.recoverPersistedEventsStagingForHarvest()
            default:
                self.sut.refreshSessionManifest(sessionId: "s1", nowMs: Int64(i), sessionAttributes: ["a": i])
                self.sut.writeSessionManifest(sessionId: "s1", realAgentId: 1, sessionStartMs: 0, sessionAttributes: ["a": i])
            }
        }
        eventStore.synchronize(); manifestStore.synchronize()
        let onDisk = Set(eventStore.fetchAll().map { $0.eventUUID })
        let expected = Set(expectedLive.map { "uuid-\($0)" })
        XCTAssertEqual(onDisk, expected, "persisted set diverged from expected live set")
        XCTAssertEqual(eventFilesOnDisk(), onDisk, "files on disk diverged from what the store returns")
    }

    // 2b. Harvest contract: a failed cycle's staged events stay on disk, and the next successful
    // cycle confirms them together with the events it picked up -- nothing is lost or left behind.
    func testFailedCycleEventsShipAndConfirmWithNextCycle() {
        record(1); record(2)
        eventStore.synchronize()
        sut.markEventsPendingConfirmation(eventUUIDs: ["uuid-1", "uuid-2"])   // cycle 1 pulls events...
        // ...and fails: no confirm. The events must survive on disk.
        eventStore.synchronize()
        XCTAssertEqual(Set(eventStore.fetchAll().map { $0.eventUUID }), ["uuid-1", "uuid-2"])

        record(3)                                                             // arrives after cycle 1 pulled
        eventStore.synchronize()
        sut.markEventsPendingConfirmation(eventUUIDs: ["uuid-3"])             // cycle 2 pulls it (plus retained 1, 2)
        sut.confirmLastRecoveryHarvestSucceeded()                             // cycle 2 succeeds
        eventStore.synchronize()
        XCTAssertEqual(eventStore.fetchAll().count, 0)
        XCTAssertEqual(eventFilesOnDisk().count, 0)
    }

    // 2c. Events recorded but not yet pulled for a harvest must survive any confirm.
    func testConfirmDoesNotTouchEventsNeverStaged() {
        record(1); record(2)
        eventStore.synchronize()
        sut.markEventsPendingConfirmation(eventUUIDs: ["uuid-1"])
        sut.confirmLastRecoveryHarvestSucceeded()
        eventStore.synchronize()
        XCTAssertEqual(Set(eventStore.fetchAll().map { $0.eventUUID }), ["uuid-2"])
    }

    // 2c'. App terminated during an attempted harvest: the events were pulled for it, the upload
    // never completed, and nothing confirmed. They must still be on disk and recovered on relaunch.
    func testTerminationDuringHarvestLeavesEventsForRecoveryOnRelaunch() {
        record(1); record(2)
        eventStore.synchronize()
        sut.markEventsPendingConfirmation(eventUUIDs: ["uuid-1", "uuid-2"])   // pulled for the termination harvest
        // process killed here: no confirm

        let relaunched = NREventPersistenceController(eventStore: NRFileEventStore(storePath: storePath),
                                                      manifestStore: NRSessionManifestStore(storePath: storePath))
        XCTAssertEqual(relaunched.recoverPersistedEventsStagingForHarvest().count, 2,
                       "events from an interrupted harvest must be recovered, not lost")
    }

    // 2c''. Once the relaunch's recovered events upload and are confirmed, they are gone for good.
    func testRecoveredEventsAreDeletedOnceConfirmed() {
        record(1); record(2)
        eventStore.synchronize()
        let relaunched = NREventPersistenceController(eventStore: NRFileEventStore(storePath: storePath),
                                                      manifestStore: NRSessionManifestStore(storePath: storePath))
        XCTAssertEqual(relaunched.recoverPersistedEventsStagingForHarvest().count, 2)
        relaunched.confirmLastRecoveryHarvestSucceeded()

        let relaunchedAgain = NREventPersistenceController(eventStore: NRFileEventStore(storePath: storePath),
                                                           manifestStore: NRSessionManifestStore(storePath: storePath))
        XCTAssertEqual(relaunchedAgain.recoverPersistedEventsStagingForHarvest().count, 0)
    }

    // 2d. Manifest write/refresh race: final manifest must be one of the written values and parseable.
    func testManifestRefreshRace() {
        sut.writeSessionManifest(sessionId: "s1", realAgentId: 1, sessionStartMs: 0, sessionAttributes: ["v": 0])
        manifestStore.synchronize()
        DispatchQueue.concurrentPerform(iterations: 2_000) { i in
            if i % 2 == 0 { self.sut.refreshSessionManifest(sessionId: "s1", nowMs: Int64(i), sessionAttributes: ["v": i]) }
            else { self.sut.writeSessionManifest(sessionId: "s1", realAgentId: 1, sessionStartMs: 0, sessionAttributes: ["v": i]) }
        }
        manifestStore.synchronize()
        XCTAssertNotNil(manifestStore.manifest(forSessionId: "s1"))
    }

    // 4. Corruption: truncated, missing and garbage event files never block recovery.
    func testCorruptStorageDoesNotBlockRecovery() {
        for i in 0..<20 { record(i) }
        eventStore.synchronize()
        let dir = cacheRoot + "/s1"
        try? Data("{truncated".utf8).write(to: URL(fileURLWithPath: dir + "/uuid-3.json"))
        try? FileManager.default.removeItem(atPath: dir + "/uuid-4.json")
        XCTAssertEqual(eventStore.fetchAll().count, 18)
        XCTAssertEqual(eventFilesOnDisk().count, 18, "the unreadable file must be deleted, not retried forever")

        // Garbage in every remaining file, seen by a fresh store (a relaunch).
        for file in eventFilesOnDisk() {
            try? Data("not json".utf8).write(to: URL(fileURLWithPath: dir + "/\(file).json"))
        }
        let relaunched = NRFileEventStore(storePath: storePath)
        XCTAssertEqual(relaunched.fetchAll().count, 0)
        XCTAssertFalse(relaunched.hasPersistedRecords())
        XCTAssertEqual(eventFilesOnDisk().count, 0)
    }

    // 3. Crash consistency: the event file is the only state, so a record that reached disk is
    // always found by the next launch -- there is no second write that could be missing.
    func testEventFileOnDiskIsRecoveredByAFreshStore() {
        record(1)
        eventStore.synchronize()
        let record = NREventRecord(eventUUID: "written-just-before-kill", eventType: "Mobile", name: nil, timestamp: 1,
                                   attributes: [:], sessionId: "s1", realAgentId: 1)
        let data = try! NRMAJSON.data(withJSONObject: record.dictionaryRepresentation, options: [])
        try! data.write(to: URL(fileURLWithPath: cacheRoot + "/s1/written-just-before-kill.json"))

        let relaunched = NRFileEventStore(storePath: storePath)
        XCTAssertEqual(Set(relaunched.fetchAll().map { $0.eventUUID }), ["uuid-1", "written-just-before-kill"])
    }

    // Stray files (temp files from an interrupted atomic write, .DS_Store, a non-session file)
    // are never mistaken for events and never break recovery.
    func testStrayFilesInTheCacheAreIgnored() {
        record(1)
        eventStore.synchronize()
        try? Data("x".utf8).write(to: URL(fileURLWithPath: cacheRoot + "/s1/.uuid-1.json.tmp123"))
        try? Data("x".utf8).write(to: URL(fileURLWithPath: cacheRoot + "/.DS_Store"))
        try? FileManager.default.createDirectory(atPath: cacheRoot + "/empty-session", withIntermediateDirectories: true)

        let relaunched = NRFileEventStore(storePath: storePath)
        XCTAssertEqual(relaunched.fetchAll().map { $0.eventUUID }, ["uuid-1"])
    }

    // Session ids become directory names: path separators and dot-dot must not escape the cache.
    func testHostileSessionIdStaysInsideTheCache() {
        record(1, session: "../../escape")
        record(2, session: "a/b")
        eventStore.synchronize()
        XCTAssertEqual(eventStore.fetchAll().count, 2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: (storePath as NSString).deletingLastPathComponent + "/escape"))
        XCTAssertEqual(sut.claimPersistedEvents(forCrashSessionId: "../../escape").count, 1)
    }

    // The manifest lives beside its events; emptying a session removes its directory only once
    // nothing (events or manifest) is left.
    func testSessionDirectoryIsRemovedOnlyWhenEmpty() {
        sut.writeSessionManifest(sessionId: "s1", realAgentId: 1, sessionStartMs: 0, sessionAttributes: [:])
        record(1)
        eventStore.synchronize(); manifestStore.synchronize()
        sut.discardPersistedEvent(eventUUID: "uuid-1")
        eventStore.synchronize()
        XCTAssertTrue(FileManager.default.fileExists(atPath: cacheRoot + "/s1/_manifest.json"),
                      "deleting the last event must not take the manifest with it")
        manifestStore.delete(sessionId: "s1")
        manifestStore.synchronize()
        XCTAssertFalse(FileManager.default.fileExists(atPath: cacheRoot + "/s1"))
    }

    // 5. Soak-lite: repeated record/harvest/confirm cycles must not leak files.
    func testRecordHarvestConfirmCyclesDoNotLeak() {
        for cycle in 0..<200 {
            for j in 0..<10 { record(cycle * 10 + j) }
            let uuids = (0..<10).map { "uuid-\(cycle * 10 + $0)" }
            sut.markEventsPendingConfirmation(eventUUIDs: uuids)
            sut.confirmLastRecoveryHarvestSucceeded()
        }
        eventStore.synchronize()
        XCTAssertEqual(eventStore.fetchAll().count, 0)
        XCTAssertEqual(eventFilesOnDisk().count, 0)
    }

    // MARK: - Crash path (claimPersistedEvents)

    private func recordSessions(_ sessions: Int, perSession: Int) {
        DispatchQueue.concurrentPerform(iterations: sessions * perSession) { i in
            self.record(i, session: "s\(i % sessions)")
        }
        eventStore.synchronize()
    }

    private func uuids(_ payloads: [[String: Any]]) -> [String] {
        payloads.compactMap { $0[kNRMA_RA_sessionId] as? String }
    }

    // Claim returns exactly the crashed session's events, deletes them, and leaves the rest.
    func testClaimReturnsOnlyCrashedSessionAndDeletesIt() {
        recordSessions(5, perSession: 40)
        let claimed = sut.claimPersistedEvents(forCrashSessionId: "s2")
        XCTAssertEqual(claimed.count, 40)
        XCTAssertTrue(uuids(claimed).allSatisfy { $0 == "s2" })
        eventStore.synchronize()
        let remaining = eventStore.fetchAll()
        XCTAssertEqual(remaining.count, 160)
        XCTAssertFalse(remaining.contains { $0.sessionId == "s2" })
        XCTAssertEqual(eventFilesOnDisk().count, 160)
    }

    // Claiming twice must not hand out the same events again.
    func testClaimIsIdempotent() {
        recordSessions(2, perSession: 50)
        XCTAssertEqual(sut.claimPersistedEvents(forCrashSessionId: "s0").count, 50)
        XCTAssertEqual(sut.claimPersistedEvents(forCrashSessionId: "s0").count, 0)
    }

    // Concurrent claims of the same session: every event is handed out exactly once in total.
    func testConcurrentClaimsOfSameSessionNeverDuplicate() {
        recordSessions(1, perSession: 500)
        let lock = NSLock()
        var total = 0
        DispatchQueue.concurrentPerform(iterations: 8) { _ in
            let n = self.sut.claimPersistedEvents(forCrashSessionId: "s0").count
            lock.lock(); total += n; lock.unlock()
        }
        XCTAssertEqual(total, 500, "claimed events were duplicated or lost across concurrent claims")
        eventStore.synchronize()
        XCTAssertEqual(eventStore.fetchAll().count, 0)
    }

    // Crash claim for one session racing launch-time recovery (which excludes it), retention
    // sweeps and manifest refreshes: recovery + claim must partition the events, with no overlap.
    func testClaimRacingRecoverySweepAndRefreshPartitionsEvents() {
        let sessions = 6, perSession = 120
        for s in 0..<sessions {
            sut.writeSessionManifest(sessionId: "s\(s)", realAgentId: 1, sessionStartMs: 0, sessionAttributes: ["s": s])
        }
        recordSessions(sessions, perSession: perSession)
        manifestStore.synchronize()

        let lock = NSLock()
        var claimed: [[String: Any]] = []
        var recovered: [[String: Any]] = []
        DispatchQueue.concurrentPerform(iterations: 40) { i in
            switch i % 4 {
            case 0:
                let c = self.sut.claimPersistedEvents(forCrashSessionId: "s3")
                lock.lock(); claimed += c; lock.unlock()
            case 1:
                let r = self.sut.recoverPersistedEventsStagingForHarvest(excludingSessionId: "s3")
                lock.lock(); recovered += r; lock.unlock()
            case 2:
                self.sut.performRetentionSweep(nowMs: 1_000)
            default:
                self.sut.refreshSessionManifest(sessionId: "s3", nowMs: Int64(i), sessionAttributes: ["s": 3])
            }
        }
        eventStore.synchronize(); manifestStore.synchronize()

        XCTAssertEqual(claimed.count, perSession, "crash session's events must be claimed exactly once")
        XCTAssertTrue(uuids(claimed).allSatisfy { $0 == "s3" })
        XCTAssertFalse(uuids(recovered).contains("s3"), "recovery must leave the crashed session to the claim")
        let remaining = eventStore.fetchAll()
        XCTAssertFalse(remaining.contains { $0.sessionId == "s3" })
        XCTAssertEqual(remaining.count, (sessions - 1) * perSession, "other sessions' events must be untouched")
    }

    // Claim after the crashed session's manifest is gone still ships the events (graceful degradation).
    func testClaimWithMissingManifestStillShipsEvents() {
        recordSessions(1, perSession: 25)
        let claimed = sut.claimPersistedEvents(forCrashSessionId: "s0")
        XCTAssertEqual(claimed.count, 25)
    }

    // A claim must not be undone by a later confirm or retention sweep.
    func testClaimedEventsDoNotComeBackAfterConfirmOrSweep() {
        recordSessions(2, perSession: 30)
        _ = sut.claimPersistedEvents(forCrashSessionId: "s0")
        sut.confirmLastRecoveryHarvestSucceeded()
        sut.performRetentionSweep(nowMs: 1_000)
        eventStore.synchronize()
        XCTAssertFalse(eventStore.fetchAll().contains { $0.sessionId == "s0" })
        XCTAssertEqual(eventStore.fetchAll().count, 30)
    }
}
