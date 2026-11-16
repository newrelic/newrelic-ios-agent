//
//  SessionReplayExternalBufferTests.swift
//  NewRelicAgent
//
//  Copyright © 2026 New Relic. All rights reserved.
//

import XCTest
@testable import NewRelic

final class SessionReplayExternalBufferTests: XCTestCase {
    private var directory: URL!
    private var buffer: SessionReplayExternalBuffer!
    private var provided: [ExternalReplayUploadMetadata] = []

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SessionReplayExternalBufferTests-\(UUID().uuidString)")
        provided = []
        buffer = makeBuffer(maxUploadBytes: 1_000_000)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    private func makeBuffer(maxUploadBytes: Int) -> SessionReplayExternalBuffer {
        return SessionReplayExternalBuffer(directory: directory, maxUploadBytes: maxUploadBytes) { [weak self] metadata in
            self?.provided.append(metadata)
            return URL(string: "https://test.invalid/recovered?v=\(metadata.rrwebVersion)")
        }
    }

    @discardableResult
    private func append(_ events: String...) -> ExternalReplayAppendResult {
        return buffer.append(Data(rrwebBatch(events).utf8), rrwebVersion: "2.0.0-test", sessionId: "s1", isFirstChunk: true)
    }

    private func file(_ path: String) -> String? {
        guard let data = FileManager.default.contents(atPath: directory.appendingPathComponent(path).path) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    // MARK: - Appending

    func testEventsBeforeTheFirstMetaAreDropped() {
        XCTAssertEqual(append(rrwebEvent(3, 1), rrwebEvent(4, 2), rrwebEvent(2, 2), rrwebEvent(3, 3)),
                       .appended(kept: 3, droppedBeforeMeta: 1))
        XCTAssertTrue(buffer.hasOpenSegment)
    }

    func testABatchBeforeAnySegmentWritesNothing() {
        XCTAssertEqual(append(rrwebEvent(3, 1)), .appended(kept: 0, droppedBeforeMeta: 1))
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("s1").path))
    }

    func testInvalidBatchesAreRejected() {
        for batch in ["not json", "{}", "[1,2]", #"[{"type":4}]"#, #"[{"timestamp":1}]"#] {
            XCTAssertEqual(buffer.append(Data(batch.utf8), rrwebVersion: "v", sessionId: "s1", isFirstChunk: true), .invalid, batch)
        }
        XCTAssertFalse(buffer.hasOpenSegment)
    }

    func testEachSegmentIsOneFileThatStartsWithItsMeta() {
        append(rrwebEvent(4, 1), rrwebEvent(2, 1), rrwebEvent(3, 2))
        append(rrwebEvent(3, 3), rrwebEvent(4, 4))   // the second segment's Meta ends this batch
        append(rrwebEvent(2, 4), rrwebEvent(3, 5))   // and its FullSnapshot starts the next
        XCTAssertEqual(file("s1/frame_0.json"), rrwebBatch([rrwebEvent(4, 1), rrwebEvent(2, 1), rrwebEvent(3, 2), rrwebEvent(3, 3)]))
        XCTAssertEqual(file("s1/frame_1.json"), rrwebBatch([rrwebEvent(4, 4), rrwebEvent(2, 4), rrwebEvent(3, 5)]))
    }

    func testEventBytesAreKeptAsSent() {
        let odd = #"{"timestamp":1,"type":4,"data":{"href":"http:\/\/x","w":1.0,"t":"€"}}"#
        append(odd)
        XCTAssertEqual(file("s1/frame_0.json"), "[" + odd + "]")
    }

    func testURLFileDescribesEverythingOnDisk() {
        append(rrwebEvent(4, 1), rrwebEvent(2, 1))
        append(rrwebEvent(4, 4), rrwebEvent(2, 4), rrwebEvent(3, 5))
        XCTAssertEqual(file("s1_upload_url.txt"), "https://test.invalid/recovered?v=2.0.0-test")
        let onDisk = ["s1/frame_0.json", "s1/frame_1.json"].map { file($0)!.utf8.count }.reduce(0, +)
        XCTAssertEqual(provided.last, ExternalReplayUploadMetadata(uncompressedSize: onDisk, firstTimestamp: 1, lastTimestamp: 5,
                                                                   isFirstChunk: true, isGZipped: true, rrwebVersion: "2.0.0-test"))
    }

    func testResetRequiresANewMeta() {
        append(rrwebEvent(4, 1), rrwebEvent(2, 1))
        buffer.reset()
        XCTAssertFalse(buffer.hasOpenSegment)
        XCTAssertEqual(append(rrwebEvent(3, 2)), .appended(kept: 0, droppedBeforeMeta: 1))
    }

    // Runs the real recovery path over files the buffer wrote, as after a crash.
    func testCrashRecoveryUploadsTheBufferFromItsFirstMeta() throws {
        let frames = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SessionReplayFrames")
        let session = "recovery-\(UUID().uuidString)"
        let url = "https://test.invalid/recovered/\(session)"
        let crashed = SessionReplayExternalBuffer(directory: frames, maxUploadBytes: 1_000_000) { _ in URL(string: url) }
        _ = crashed.append(Data(rrwebBatch([rrwebEvent(4, 1), rrwebEvent(2, 1), rrwebEvent(3, 2), rrwebEvent(4, 3)]).utf8),
                           rrwebVersion: "2.0.0-test", sessionId: session, isFirstChunk: true)
        _ = crashed.append(Data(rrwebBatch([rrwebEvent(2, 3)]).utf8), rrwebVersion: "2.0.0-test", sessionId: session, isFirstChunk: true)

        let reporter = CapturingSessionReplayReporter(applicationToken: "test-token", url: "mobile-collector.newrelic.com" as NSString)
        let manager = SessionReplayManager(reporter: reporter, url: "mobile-collector.newrelic.com" as NSString)
        manager.checkForPreviousSessionFiles()
        _ = manager.isManuallyActive()   // a replay-queue barrier: recovery has run

        let recovered = try XCTUnwrap(reporter.uploads.first { $0.url.absoluteString == url })
        let events = try XCTUnwrap(JSONSerialization.jsonObject(with: gunzipForTests(recovered.sessionReplayFramesData)) as? [[String: Any]])
        XCTAssertEqual(events.map { $0["type"] as? Int }, [4, 2, 3, 4, 2])
        XCTAssertFalse(FileManager.default.fileExists(atPath: frames.appendingPathComponent(session).path))
    }
}
