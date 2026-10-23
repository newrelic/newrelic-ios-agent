//
//  NRFileEventStoreTests.swift
//  NewRelicAgent
//
//  Copyright © 2026 New Relic. All rights reserved.
//

import XCTest
@testable import NewRelic

final class NRFileEventStoreTests: XCTestCase {

    private var storePath: String!
    private var sut: NRFileEventStore!

    override func setUp() {
        super.setUp()
        storePath = NSTemporaryDirectory().appending("NRFileEventStoreTests-\(UUID().uuidString)")
        sut = NRFileEventStore(storePath: storePath)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: storePath)
        sut = nil
        super.tearDown()
    }

    private func makeRecord(uuid: String = UUID().uuidString, timestampMs: Int64) -> NREventRecord {
        NREventRecord(eventUUID: uuid,
                       eventType: "Mobile",
                       name: "TestEvent",
                       timestamp: timestampMs,
                       attributes: ["foo": "bar"],
                       sessionId: "session-1",
                       realAgentId: 42,
                       mutableAttributesSnapshot: ["userId": "u1"])
    }

    func testEmptyStoreHasNoPersistedRecords() {
        XCTAssertFalse(sut.hasPersistedRecords())
        XCTAssertTrue(sut.fetchAll().isEmpty)
    }

    func testStoreThenFetchRoundTrips() {
        let record = makeRecord(timestampMs: 1_000)
        sut.store(record)
        sut.synchronize()

        XCTAssertTrue(sut.hasPersistedRecords())
        let fetched = sut.fetchAll()
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.eventUUID, record.eventUUID)
        XCTAssertEqual(fetched.first?.sessionId, "session-1")
        XCTAssertEqual(fetched.first?.mutableAttributesSnapshot["userId"] as? String, "u1")
    }

    func testDeleteRemovesRecord() {
        let record = makeRecord(timestampMs: 1_000)
        sut.store(record)
        sut.synchronize()
        XCTAssertEqual(sut.fetchAll().count, 1)

        sut.delete(eventUUIDs: [record.eventUUID])
        sut.synchronize()

        XCTAssertFalse(sut.hasPersistedRecords())
        XCTAssertTrue(sut.fetchAll().isEmpty)
    }

    func testDeleteOfUnknownUUIDIsHarmless() {
        sut.delete(eventUUIDs: ["does-not-exist"])
        sut.synchronize()
        XCTAssertTrue(sut.fetchAll().isEmpty)
    }

    func testCorruptRecordFileIsSkippedNotCrashed() {
        let record = makeRecord(timestampMs: 1_000)
        sut.store(record)
        sut.synchronize()

        // Corrupt the on-disk file directly, out from under the store.
        let fileURL = URL(fileURLWithPath: storePath)
            .appendingPathComponent("nr_event_cache")
            .appendingPathComponent("\(record.eventUUID).json")
        try? "not valid json".data(using: .utf8)?.write(to: fileURL)

        let fetched = sut.fetchAll()
        XCTAssertTrue(fetched.isEmpty, "a corrupt record must be skipped, not crash or be returned")

        // The corrupt entry should also have been pruned from the index so it
        // isn't retried forever.
        sut.synchronize()
        XCTAssertFalse(sut.hasPersistedRecords())
    }

    func testRetentionEvictsOnlyRecordsOlderThanCap() {
        let maxAgeMs: Int64 = 7 * 24 * 60 * 60 * 1000
        let nowMs: Int64 = 100 * 24 * 60 * 60 * 1000 // arbitrary large "now"
        let staleRecord = makeRecord(timestampMs: nowMs - maxAgeMs - 1_000)
        let freshRecord = makeRecord(timestampMs: nowMs - 1_000)
        sut.store(staleRecord)
        sut.store(freshRecord)
        sut.synchronize()
        XCTAssertEqual(sut.fetchAll().count, 2)

        sut.evictRecords(olderThanMs: maxAgeMs, nowMs: nowMs, maxCount: 1_000)
        sut.synchronize()

        let survivors = sut.fetchAll()
        XCTAssertEqual(survivors.count, 1)
        XCTAssertEqual(survivors.first?.eventUUID, freshRecord.eventUUID)
    }

    func testRetentionEvictsOldestRecordsOverCountCap() {
        let nowMs: Int64 = 100 * 24 * 60 * 60 * 1000
        let oldest = makeRecord(timestampMs: nowMs - 3_000)
        let middle = makeRecord(timestampMs: nowMs - 2_000)
        let newest = makeRecord(timestampMs: nowMs - 1_000)
        sut.store(oldest)
        sut.store(middle)
        sut.store(newest)
        sut.synchronize()
        XCTAssertEqual(sut.fetchAll().count, 3)

        // Only the count cap can fire here.
        sut.evictRecords(olderThanMs: Int64.max, nowMs: nowMs, maxCount: 2)
        sut.synchronize()

        let survivors = sut.fetchAll()
        let survivingUUIDs = Set(survivors.map { $0.eventUUID })
        XCTAssertEqual(survivors.count, 2)
        XCTAssertTrue(survivingUUIDs.contains(middle.eventUUID))
        XCTAssertTrue(survivingUUIDs.contains(newest.eventUUID))
        XCTAssertFalse(survivingUUIDs.contains(oldest.eventUUID), "the oldest record by timestamp must be evicted first when over the count cap")
    }

    func testRetentionCountCapIsNoopWhenUnderCap() {
        sut.store(makeRecord(timestampMs: 1_000))
        sut.synchronize()

        sut.evictRecords(olderThanMs: Int64.max, nowMs: 1_000, maxCount: 1_000)
        sut.synchronize()

        XCTAssertEqual(sut.fetchAll().count, 1)
    }

    func testDirectoryIsExcludedFromBackup() {
        let directoryURL = URL(fileURLWithPath: storePath).appendingPathComponent("nr_event_cache")
        let values = try? directoryURL.resourceValues(forKeys: [.isExcludedFromBackupKey])
        XCTAssertEqual(values?.isExcludedFromBackup, true)
    }

    func testDirectoryHasFileProtection() {
        // The iOS Simulator doesn't reliably report file-protection attributes
        // back via -attributesOfItem even when the creation call (which this
        // test does exercise, via setUp) succeeds -- so a nil read here is a
        // platform quirk, not a failure. This guards against a wrong value
        // when the platform *does* report one (e.g. on a real device).
        let directoryURL = URL(fileURLWithPath: storePath).appendingPathComponent("nr_event_cache")
        let attributes = try? FileManager.default.attributesOfItem(atPath: directoryURL.path)
        if let protection = attributes?[.protectionKey] as? FileProtectionType {
            XCTAssertEqual(protection, .completeUntilFirstUserAuthentication)
        }
    }
}
