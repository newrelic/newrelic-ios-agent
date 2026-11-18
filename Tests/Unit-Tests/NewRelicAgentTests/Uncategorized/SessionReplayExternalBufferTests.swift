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
            return URL(string: "https://test.invalid/recovered")
        }
    }

    @discardableResult
    private func append(_ events: String...) -> ExternalReplayAppendResult {
        return buffer.append(Data(rrwebBatch(events).utf8), sessionId: "s1", isFirstChunk: true)
    }

    private func file(_ path: String) -> String? {
        guard let data = FileManager.default.contents(atPath: directory.appendingPathComponent(path).path) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    private func payloadTimestamps(_ chunk: ExternalReplayChunk) throws -> [Int] {
        let events = try XCTUnwrap(JSONSerialization.jsonObject(with: gunzipForTests(chunk.payload)) as? [[String: Any]])
        return events.map { ($0["timestamp"] as? Int) ?? -1 }
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
            XCTAssertEqual(buffer.append(Data(batch.utf8), sessionId: "s1", isFirstChunk: true), .invalid, batch)
        }
        XCTAssertFalse(buffer.hasOpenSegment)
    }

    // The upload URL converts timestamps to Int, which stops the app for a value outside Int's range.
    func testTimestampsOutsideTheMillisecondRangeAreInvalid() {
        for timestamp in ["1e19", "-1e19", "99999999999999999999", "1e15", "-1"] {
            let batch = #"[{"type":4,"timestamp":\#(timestamp),"data":{}}]"#
            XCTAssertEqual(buffer.append(Data(batch.utf8), sessionId: "s1", isFirstChunk: true), .invalid, timestamp)
        }
        XCTAssertEqual(append(rrwebEvent(4, 1_731_783_600_000)), .appended(kept: 1, droppedBeforeMeta: 0))
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
        XCTAssertEqual(file("s1_upload_url.txt"), "https://test.invalid/recovered")
        let onDisk = ["s1/frame_0.json", "s1/frame_1.json"].map { file($0)!.utf8.count }.reduce(0, +)
        XCTAssertEqual(provided.last, ExternalReplayUploadMetadata(uncompressedSize: onDisk, firstTimestamp: 1, lastTimestamp: 5,
                                                                   isFirstChunk: true, isGZipped: true))
    }

    func testResetRequiresANewMeta() {
        append(rrwebEvent(4, 1), rrwebEvent(2, 1))
        buffer.reset()
        XCTAssertFalse(buffer.hasOpenSegment)
        XCTAssertEqual(append(rrwebEvent(3, 2)), .appended(kept: 0, droppedBeforeMeta: 1))
    }

    // MARK: - Taking chunks

    func testRegularTakeKeepsTheSegmentInProgress() throws {
        append(rrwebEvent(4, 1), rrwebEvent(2, 1), rrwebEvent(3, 2))
        append(rrwebEvent(4, 3), rrwebEvent(2, 3))
        let chunks = buffer.takeChunks(final: false, isFirstChunk: true)
        XCTAssertEqual(try chunks.map(payloadTimestamps), [[1, 1, 2]])
        XCTAssertEqual(chunks[0].metadata.firstTimestamp, 1)
        XCTAssertEqual(chunks[0].metadata.lastTimestamp, 2)
        XCTAssertNil(file("s1/frame_0.json"))
        XCTAssertNotNil(file("s1/frame_1.json"))
        XCTAssertTrue(buffer.hasOpenSegment)
    }

    func testRegularTakeWithOnlyTheOpenSegmentSendsNothing() {
        append(rrwebEvent(4, 1), rrwebEvent(2, 1))
        XCTAssertTrue(buffer.takeChunks(final: false, isFirstChunk: true).isEmpty)
        XCTAssertNotNil(file("s1/frame_0.json"))
    }

    func testFinalTakeSendsEverythingAndClosesTheBuffer() throws {
        append(rrwebEvent(4, 1), rrwebEvent(2, 1))
        append(rrwebEvent(4, 3), rrwebEvent(2, 3))
        XCTAssertEqual(try buffer.takeChunks(final: true, isFirstChunk: true).map(payloadTimestamps), [[1, 1, 3, 3]])
        XCTAssertFalse(buffer.hasOpenSegment)
        XCTAssertNil(file("s1_upload_url.txt"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("s1").path))
    }

    func testFinalTakeDropsATrailingSegmentWithoutItsFullSnapshot() throws {
        append(rrwebEvent(4, 1), rrwebEvent(2, 1), rrwebEvent(4, 9))
        XCTAssertEqual(try buffer.takeChunks(final: true, isFirstChunk: true).map(payloadTimestamps), [[1, 1]])
    }

    func testOnlyTheFirstChunkIsMarkedFirst() {
        buffer = makeBuffer(maxUploadBytes: 3_000)
        for t in 1...3 { append(rrwebEvent(4, t), rrwebEvent(2, t, #"{"t":"\#(randomText(2_000))"}"#)) }
        XCTAssertEqual(buffer.takeChunks(final: true, isFirstChunk: true).map(\.metadata.isFirstChunk), [true, false, false])
    }

    func testEventsAreNotReordered() throws {
        append(rrwebEvent(4, 10), rrwebEvent(2, 10), rrwebEvent(3, 5))
        let chunk = try XCTUnwrap(buffer.takeChunks(final: true, isFirstChunk: false).first)
        XCTAssertEqual(try payloadTimestamps(chunk), [10, 10, 5])
        XCTAssertEqual(chunk.metadata.lastTimestamp, 5)
    }

    func testWholeSegmentsArePackedUnderTheLimit() throws {
        buffer = makeBuffer(maxUploadBytes: 5_000)
        for t in 1...6 { append(rrwebEvent(4, t), rrwebEvent(2, t, #"{"t":"\#(randomText(1_500))"}"#)) }
        let chunks = buffer.takeChunks(final: true, isFirstChunk: true)
        XCTAssertGreaterThan(chunks.count, 1)
        XCTAssertTrue(chunks.allSatisfy { $0.payload.count <= 5_000 })
        XCTAssertEqual(try chunks.flatMap(payloadTimestamps), (1...6).flatMap { [$0, $0] })   // whole segments, in order
    }

    func testASegmentOverTheLimitGoesOutAlone() throws {
        buffer = makeBuffer(maxUploadBytes: 1_000)
        append(rrwebEvent(4, 1), rrwebEvent(2, 1, #"{"t":"\#(randomText(3_000))"}"#))
        append(rrwebEvent(4, 2), rrwebEvent(2, 2))
        let chunks = buffer.takeChunks(final: true, isFirstChunk: true)
        XCTAssertEqual(try chunks.map(payloadTimestamps), [[1, 1], [2, 2]])
        XCTAssertGreaterThan(chunks[0].payload.count, 1_000)   // the reporter drops it and counts the max-payload metric
    }

    func testURLFileIsRewrittenForWhatRemains() {
        append(rrwebEvent(4, 1), rrwebEvent(2, 1))
        append(rrwebEvent(4, 3), rrwebEvent(2, 3), rrwebEvent(3, 4))
        _ = buffer.takeChunks(final: false, isFirstChunk: true)
        XCTAssertEqual(provided.last?.firstTimestamp, 3)
        XCTAssertEqual(provided.last?.lastTimestamp, 4)
        XCTAssertEqual(provided.last?.isFirstChunk, false)
    }

    // Runs the real recovery path over files the buffer wrote, as after a crash.
    func testCrashRecoveryUploadsTheBufferFromItsFirstMeta() throws {
        let frames = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SessionReplayFrames")
        let session = "recovery-\(UUID().uuidString)"
        let url = "https://test.invalid/recovered/\(session)"
        let crashed = SessionReplayExternalBuffer(directory: frames, maxUploadBytes: 1_000_000) { _ in URL(string: url) }
        _ = crashed.append(Data(rrwebBatch([rrwebEvent(4, 1), rrwebEvent(2, 1), rrwebEvent(3, 2), rrwebEvent(4, 3)]).utf8),
                           sessionId: session, isFirstChunk: true)
        _ = crashed.append(Data(rrwebBatch([rrwebEvent(2, 3)]).utf8), sessionId: session, isFirstChunk: true)

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
