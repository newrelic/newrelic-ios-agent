//
//  SessionReplayExternalIngestTests.swift
//  NewRelicAgent
//
//  Copyright © 2026 New Relic. All rights reserved.
//
//  The manager uploading rrweb events from an external replay source with its own replay:
//  at the regular harvest, at pause and at session end, with native capture suppressed.
//

import XCTest
@testable import NewRelic

/// Files external events under a session the test can change.
private final class SessionSwitchingManager: SessionReplayManager {
    var sessionId = "session-a-\(UUID().uuidString)"

    override func currentSessionId() -> String {
        return sessionId
    }
}

final class SessionReplayExternalIngestTests: XCTestCase {
    private var reporter: CapturingSessionReplayReporter!
    private var manager: SessionReplayManager!

    override func setUp() {
        super.setUp()
        reporter = CapturingSessionReplayReporter(applicationToken: "test-token", url: "mobile-collector.newrelic.com" as NSString)
        manager = SessionReplayManager(reporter: reporter, url: "mobile-collector.newrelic.com" as NSString)
        manager.externalCaptureSource = true
        manager.start(with: .full)
        drain()
    }

    override func tearDown() {
        manager.stop()
        manager.clearAllData()
        drain()
        super.tearDown()
    }

    // isManuallyActive() runs a replay-queue sync, so everything queued before it has run.
    private func drain() {
        _ = manager.isManuallyActive()
    }

    private func record(_ events: String...) {
        manager.recordExternalEvents(rrwebBatch(events), rrwebVersion: "2.0.0-test")
        drain()
    }

    private func uploadedTimestamps(_ index: Int) throws -> [Int] {
        let payload = try gunzipForTests(reporter.uploads[index].sessionReplayFramesData)
        let events = try XCTUnwrap(JSONSerialization.jsonObject(with: payload) as? [[String: Any]])
        return events.map { ($0["timestamp"] as? Int) ?? -1 }
    }

    private func request(for upload: SessionReplayData) -> CapturingSessionReplayReporter.Request? {
        return reporter.requests[upload.url]
    }

    /// Looks through Documents/SessionReplayFrames/*/frame_*.json for a file that starts with the event.
    private func segmentFileExists(startingWith event: String) throws -> Bool {
        let frames = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SessionReplayFrames")
        for folder in try FileManager.default.contentsOfDirectory(at: frames, includingPropertiesForKeys: nil) {
            let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
            for file in files where file.lastPathComponent.hasPrefix("frame_") && file.pathExtension == "json" {
                if let contents = try? String(contentsOf: file), contents.hasPrefix("[" + event) {
                    return true
                }
            }
        }
        return false
    }

    func testRegularHarvestUploadsFinishedSegments() throws {
        record(rrwebEvent(4, 1), rrwebEvent(2, 1), rrwebEvent(3, 2))
        record(rrwebEvent(4, 3), rrwebEvent(2, 3))
        manager.harvest(); drain()
        XCTAssertEqual(reporter.uploads.count, 1)
        XCTAssertEqual(try uploadedTimestamps(0), [1, 1, 2])
        let request = try XCTUnwrap(request(for: reporter.uploads[0]))
        XCTAssertEqual(request.rrwebVersion, "2.0.0-test")
        XCTAssertTrue(request.isFirstChunk)
        XCTAssertEqual(request.firstTimestamp, 1)
        XCTAssertEqual(request.lastTimestamp, 2)
        // The URL file that crash recovery reads is built through the same call, so it carries the version too.
        XCTAssertGreaterThan(reporter.requests.count, 1)
        XCTAssertTrue(reporter.requests.values.allSatisfy { $0.rrwebVersion == "2.0.0-test" })
    }

    func testLaterUploadsAreNotFirstChunk() throws {
        record(rrwebEvent(4, 1), rrwebEvent(2, 1)); record(rrwebEvent(4, 3), rrwebEvent(2, 3))
        manager.harvest(); drain()
        record(rrwebEvent(4, 5), rrwebEvent(2, 5))
        manager.harvest(); drain()
        XCTAssertEqual(try uploadedTimestamps(1), [3, 3])
        XCTAssertEqual(request(for: reporter.uploads[1])?.isFirstChunk, false)
    }

    // Native's frame path would wipe the whole frames folder here.
    func testHarvestWhileSuppressedKeepsTheOpenSegmentOnDisk() throws {
        record(rrwebEvent(4, 1), rrwebEvent(2, 1)); record(rrwebEvent(4, 3), rrwebEvent(2, 3))
        manager.harvest(); drain()
        XCTAssertTrue(try segmentFileExists(startingWith: rrwebEvent(4, 3)))
    }

    func testPauseFlushesEverythingAndRecordNeedsANewMeta() throws {
        record(rrwebEvent(4, 1), rrwebEvent(2, 1), rrwebEvent(3, 2)); record(rrwebEvent(4, 3), rrwebEvent(2, 3))
        XCTAssertTrue(manager.manualPauseReplay())
        XCTAssertEqual(try uploadedTimestamps(0), [1, 1, 2, 3, 3])
        XCTAssertTrue(manager.manualRecordReplay()); drain()
        record(rrwebEvent(3, 4))
        manager.harvest(final: true); drain()
        XCTAssertEqual(reporter.uploads.count, 1)
    }

    func testSessionEndFlushesAndTheNextSessionStartsFirstChunk() throws {
        record(rrwebEvent(4, 1), rrwebEvent(2, 1)); record(rrwebEvent(4, 3), rrwebEvent(2, 3))
        manager.endSession(); drain()
        XCTAssertEqual(try uploadedTimestamps(0), [1, 1, 3, 3])
        manager.start(with: .full); drain()
        record(rrwebEvent(3, 6))                                     // a late diff from the old screen
        record(rrwebEvent(4, 7), rrwebEvent(2, 7)); record(rrwebEvent(4, 8), rrwebEvent(2, 8))
        manager.harvest(); drain()
        XCTAssertEqual(try uploadedTimestamps(1), [7, 7])            // the new session starts at its own Meta
        XCTAssertEqual(request(for: reporter.uploads[1])?.isFirstChunk, true)
    }

    // A reconnect can stop capture, and the session can then change without endSession, so replay
    // starts again with the earlier session's segments still buffered.
    func testAnEarlierSessionsEventsArentUploadedWithTheNextSession() throws {
        let switching = SessionSwitchingManager(reporter: reporter, url: "mobile-collector.newrelic.com" as NSString)
        switching.externalCaptureSource = true
        switching.start(with: .full)
        switching.recordExternalEvents(rrwebBatch([rrwebEvent(4, 1), rrwebEvent(2, 1)]), rrwebVersion: "2.0.0-test")
        switching.recordExternalEvents(rrwebBatch([rrwebEvent(4, 2), rrwebEvent(2, 2)]), rrwebVersion: "2.0.0-test")
        switching.stop()
        let earlierSession = switching.sessionId
        switching.sessionId = "session-b-\(UUID().uuidString)"
        switching.start(with: .full)
        switching.recordExternalEvents(rrwebBatch([rrwebEvent(4, 5), rrwebEvent(2, 5)]), rrwebVersion: "2.0.0-test")
        switching.recordExternalEvents(rrwebBatch([rrwebEvent(4, 6), rrwebEvent(2, 6)]), rrwebVersion: "2.0.0-test")
        switching.harvest()
        switching.stop()
        XCTAssertEqual(try uploadedTimestamps(0), [5, 5])
        // The earlier session's events stay on disk, for the next launch's recovery under their own URL file.
        let frames = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SessionReplayFrames")
        XCTAssertTrue(FileManager.default.fileExists(atPath: frames.appendingPathComponent("\(earlierSession)/frame_0.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: frames.appendingPathComponent("\(earlierSession)_upload_url.txt").path))
    }

    func testBatchQueuedAfterTheSessionEndedIsDropped() {
        manager.endSession(); drain()
        record(rrwebEvent(4, 1), rrwebEvent(2, 1))
        manager.start(with: .full); drain()
        manager.harvest(final: true); drain()
        XCTAssertTrue(reporter.uploads.isEmpty)
    }

    func testWithoutSuppressionExternalEventsAreIgnored() {
        let native = SessionReplayManager(reporter: reporter, url: "mobile-collector.newrelic.com" as NSString)
        native.start(with: .full); _ = native.isManuallyActive()
        native.recordExternalEvents(rrwebBatch([rrwebEvent(4, 1), rrwebEvent(2, 1)]), rrwebVersion: "2.0.0-test")
        _ = native.isManuallyActive()
        // Storing a batch builds its crash-recovery URL file, which asks the reporter for a URL.
        XCTAssertTrue(reporter.requests.isEmpty, "nothing was stored")
        native.harvest(final: true); _ = native.isManuallyActive()
        native.stop()
        XCTAssertTrue(reporter.uploads.isEmpty)
    }

    func testInvalidBatchWritesNothing() {
        manager.recordExternalEvents("not json", rrwebVersion: "2.0.0-test"); drain()
        manager.harvest(final: true); drain()
        XCTAssertTrue(reporter.uploads.isEmpty)
    }
}
