//
//  NRSessionManifestStoreTests.swift
//  NewRelicAgent
//
//  Copyright © 2026 New Relic. All rights reserved.
//

import XCTest
@testable import NewRelic

final class NRSessionManifestStoreTests: XCTestCase {

    private var storePath: String!
    private var sut: NRSessionManifestStore!

    override func setUp() {
        super.setUp()
        storePath = NSTemporaryDirectory().appending("NRSessionManifestStoreTests-\(UUID().uuidString)")
        sut = NRSessionManifestStore(storePath: storePath)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: storePath)
        sut = nil
        super.tearDown()
    }

    private func makeManifest(sessionId: String, sessionStartMs: Int64, lastUpdateMs: Int64) -> NRSessionManifest {
        NRSessionManifest(sessionId: sessionId,
                           realAgentId: 42,
                           sessionStartMs: sessionStartMs,
                           lastUpdateMs: lastUpdateMs,
                           stableAttributes: ["appVersion": "1.0", "osName": "iOS"])
    }

    func testMissingManifestReturnsNil() {
        XCTAssertNil(sut.manifest(forSessionId: "no-such-session"))
    }

    func testStoreThenLookupRoundTrips() {
        let manifest = makeManifest(sessionId: "session-A", sessionStartMs: 1_000, lastUpdateMs: 2_000)
        sut.store(manifest)
        sut.synchronize()

        let fetched = sut.manifest(forSessionId: "session-A")
        XCTAssertEqual(fetched?.sessionId, "session-A")
        XCTAssertEqual(fetched?.realAgentId, 42)
        XCTAssertEqual(fetched?.stableAttributes["appVersion"] as? String, "1.0")
    }

    func testDeleteRemovesManifest() {
        let manifest = makeManifest(sessionId: "session-A", sessionStartMs: 1_000, lastUpdateMs: 2_000)
        sut.store(manifest)
        sut.synchronize()
        XCTAssertNotNil(sut.manifest(forSessionId: "session-A"))

        sut.delete(sessionId: "session-A")
        sut.synchronize()
        XCTAssertNil(sut.manifest(forSessionId: "session-A"))
    }

    func testEvictionSkipsLiveSessionIdsRegardlessOfAge() {
        let maxAgeMs: Int64 = 7 * 24 * 60 * 60 * 1000
        let nowMs: Int64 = 100 * 24 * 60 * 60 * 1000
        let staleButLive = makeManifest(sessionId: "live-session", sessionStartMs: 0, lastUpdateMs: nowMs - maxAgeMs - 1_000)
        sut.store(staleButLive)
        sut.synchronize()

        sut.evictManifests(olderThanMs: maxAgeMs, nowMs: nowMs, liveSessionIds: ["live-session"])
        sut.synchronize()

        XCTAssertNotNil(sut.manifest(forSessionId: "live-session"), "a manifest still referenced by a live event must not be evicted")
    }

    func testEvictionRemovesStaleUnreferencedManifest() {
        let maxAgeMs: Int64 = 7 * 24 * 60 * 60 * 1000
        let nowMs: Int64 = 100 * 24 * 60 * 60 * 1000
        let stale = makeManifest(sessionId: "stale-session", sessionStartMs: 0, lastUpdateMs: nowMs - maxAgeMs - 1_000)
        let fresh = makeManifest(sessionId: "fresh-session", sessionStartMs: 0, lastUpdateMs: nowMs - 1_000)
        sut.store(stale)
        sut.store(fresh)
        sut.synchronize()

        sut.evictManifests(olderThanMs: maxAgeMs, nowMs: nowMs, liveSessionIds: [])
        sut.synchronize()

        XCTAssertNil(sut.manifest(forSessionId: "stale-session"))
        XCTAssertNotNil(sut.manifest(forSessionId: "fresh-session"))
    }

    func testDirectoryIsExcludedFromBackup() {
        let directoryURL = URL(fileURLWithPath: storePath).appendingPathComponent("nr_session_manifest")
        let values = try? directoryURL.resourceValues(forKeys: [.isExcludedFromBackupKey])
        XCTAssertEqual(values?.isExcludedFromBackup, true)
    }

    func testDirectoryHasFileProtection() {
        // See NRFileEventStoreTests.testDirectoryHasFileProtection -- the
        // Simulator doesn't reliably report this attribute back even when
        // creation succeeds, so a nil read isn't itself a failure here.
        let directoryURL = URL(fileURLWithPath: storePath).appendingPathComponent("nr_session_manifest")
        let attributes = try? FileManager.default.attributesOfItem(atPath: directoryURL.path)
        if let protection = attributes?[.protectionKey] as? FileProtectionType {
            XCTAssertEqual(protection, .completeUntilFirstUserAuthentication)
        }
    }
}
