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

    @discardableResult
    private func append(session: String, _ events: String...) -> ExternalReplayAppendResult {
        return buffer.append(Data(rrwebBatch(events).utf8), sessionId: session, isFirstChunk: true)
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

    func testBatchesBeforeTheFirstMetaAreDropped() {
        XCTAssertEqual(append(rrwebEvent(3, 1), rrwebEvent(3, 2)), .appended(kept: 0, droppedBeforeMeta: 2))
        XCTAssertNil(buffer.openSessionId)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("s1").path))
    }

    func testABatchThatHoldsAMetaIsKeptWhole() {
        XCTAssertEqual(append(rrwebEvent(3, 1), rrwebEvent(4, 2), rrwebEvent(2, 2)), .appended(kept: 3, droppedBeforeMeta: 0))
        XCTAssertEqual(buffer.openSessionId, "s1")
        XCTAssertEqual(file("s1/frame_0.json"), rrwebBatch([rrwebEvent(3, 1), rrwebEvent(4, 2), rrwebEvent(2, 2)]))
    }

    func testInvalidBatchesAreRejected() {
        for batch in ["not json", "{}", "[1,2]", #"[{"type":4}]"#, #"[{"timestamp":1}]"#, "\u{FEFF}" + rrwebBatch([rrwebEvent(4, 1)])] {
            XCTAssertEqual(buffer.append(Data(batch.utf8), sessionId: "s1", isFirstChunk: true), .invalid, batch)
        }
        XCTAssertNil(buffer.openSessionId)
    }

    // The upload URL converts timestamps to Int, which stops the app for a value outside Int's range.
    func testTimestampsOutsideTheMillisecondRangeAreInvalid() {
        for timestamp in ["1e19", "-1e19", "99999999999999999999", "1e15", "-1"] {
            let batch = #"[{"type":4,"timestamp":\#(timestamp),"data":{}}]"#
            XCTAssertEqual(buffer.append(Data(batch.utf8), sessionId: "s1", isFirstChunk: true), .invalid, timestamp)
        }
        XCTAssertEqual(append(rrwebEvent(4, 1_731_783_600_000)), .appended(kept: 1, droppedBeforeMeta: 0))
    }

    func testEachBatchIsOneFile() {
        append(rrwebEvent(4, 1), rrwebEvent(2, 1))
        append(rrwebEvent(3, 2))
        append(rrwebEvent(3, 3), rrwebEvent(4, 4), rrwebEvent(2, 4))
        XCTAssertEqual(file("s1/frame_0.json"), rrwebBatch([rrwebEvent(4, 1), rrwebEvent(2, 1)]))
        XCTAssertEqual(file("s1/frame_1.json"), rrwebBatch([rrwebEvent(3, 2)]))
        XCTAssertEqual(file("s1/frame_2.json"), rrwebBatch([rrwebEvent(3, 3), rrwebEvent(4, 4), rrwebEvent(2, 4)]))
    }

    func testEventBytesAreKeptAsSent() {
        let odd = #"{"timestamp":1,"type":4,"data":{"href":"http:\/\/x","w":1.0,"t":"€"}}"#
        append(odd)
        XCTAssertEqual(file("s1/frame_0.json"), "[" + odd + "]")
    }

    func testWhitespaceAroundTheArrayIsTrimmed() {
        let padded = " \n" + rrwebBatch([rrwebEvent(4, 1)]) + "\t\r\n"
        XCTAssertEqual(buffer.append(Data(padded.utf8), sessionId: "s1", isFirstChunk: true), .appended(kept: 1, droppedBeforeMeta: 0))
        XCTAssertEqual(file("s1/frame_0.json"), rrwebBatch([rrwebEvent(4, 1)]))
    }

    func testAnEmptyBatchWritesNothing() {
        append(rrwebEvent(4, 1), rrwebEvent(2, 1))
        XCTAssertEqual(buffer.append(Data("[]".utf8), sessionId: "s1", isFirstChunk: true), .appended(kept: 0, droppedBeforeMeta: 0))
        XCTAssertNil(file("s1/frame_1.json"))
    }

    func testURLFileDescribesEverythingOnDisk() {
        append(rrwebEvent(4, 1), rrwebEvent(2, 1))
        append(rrwebEvent(4, 4), rrwebEvent(2, 4), rrwebEvent(3, 5))
        XCTAssertEqual(file("s1_upload_url.txt"), "https://test.invalid/recovered")
        let onDisk = ["s1/frame_0.json", "s1/frame_1.json"].map { file($0)!.utf8.count }.reduce(0, +)
        XCTAssertEqual(provided.last, ExternalReplayUploadMetadata(uncompressedSize: onDisk, firstTimestamp: 1, lastTimestamp: 5,
                                                                   isFirstChunk: true, isGZipped: true, hasMeta: true))
    }

    func testURLFileSaysWhetherTheBufferHoldsAMeta() {
        append(rrwebEvent(4, 1), rrwebEvent(2, 1))
        XCTAssertEqual(provided.last?.hasMeta, true)
        _ = buffer.takeChunks(final: false, isFirstChunk: true)
        append(rrwebEvent(3, 2))
        XCTAssertEqual(provided.last?.hasMeta, false)
    }

    func testResetRequiresANewMeta() {
        append(rrwebEvent(4, 1), rrwebEvent(2, 1))
        buffer.reset()
        XCTAssertNil(buffer.openSessionId)
        XCTAssertEqual(append(rrwebEvent(3, 2)), .appended(kept: 0, droppedBeforeMeta: 1))
    }

    func testANewSessionNeedsItsOwnMeta() {
        append(rrwebEvent(4, 1), rrwebEvent(2, 1))
        XCTAssertEqual(append(session: "s2", rrwebEvent(3, 2)), .appended(kept: 0, droppedBeforeMeta: 1))
        XCTAssertNotNil(file("s1/frame_0.json"))      // left for recovery
        XCTAssertNotNil(file("s1_upload_url.txt"))
        XCTAssertEqual(append(session: "s2", rrwebEvent(4, 3), rrwebEvent(2, 3)), .appended(kept: 2, droppedBeforeMeta: 0))
        XCTAssertEqual(buffer.sessionId, "s2")
        XCTAssertNotNil(file("s2/frame_0.json"))
    }

    func testAFailedWriteClosesTheStream() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let blocker = directory.appendingPathComponent("s1")
        XCTAssertTrue(FileManager.default.createFile(atPath: blocker.path, contents: Data()))   // a file where the folder goes
        XCTAssertEqual(append(rrwebEvent(4, 1), rrwebEvent(2, 1)), .appended(kept: 0, droppedBeforeMeta: 0))
        XCTAssertNil(buffer.openSessionId)
        XCTAssertNil(buffer.sessionId)
        try FileManager.default.removeItem(at: blocker)
        XCTAssertEqual(append(rrwebEvent(3, 2)), .appended(kept: 0, droppedBeforeMeta: 1))
        XCTAssertEqual(append(rrwebEvent(4, 3), rrwebEvent(2, 3)), .appended(kept: 2, droppedBeforeMeta: 0))
    }

    // MARK: - Taking chunks

    func testRegularTakeSendsEverythingAndKeepsTheStreamOpen() throws {
        append(rrwebEvent(4, 1), rrwebEvent(2, 1), rrwebEvent(3, 2))
        append(rrwebEvent(3, 3))
        let chunks = buffer.takeChunks(final: false, isFirstChunk: true)
        XCTAssertEqual(try chunks.map(payloadTimestamps), [[1, 1, 2, 3]])
        XCTAssertEqual(chunks[0].metadata.firstTimestamp, 1)
        XCTAssertEqual(chunks[0].metadata.lastTimestamp, 3)
        XCTAssertNil(file("s1/frame_0.json"))
        XCTAssertNil(file("s1_upload_url.txt"))
        XCTAssertEqual(buffer.openSessionId, "s1")
        XCTAssertEqual(append(rrwebEvent(3, 4)), .appended(kept: 1, droppedBeforeMeta: 0))
        XCTAssertEqual(file("s1/frame_0.json"), rrwebBatch([rrwebEvent(3, 4)]))
    }

    func testAfterATakeANewSessionStillNeedsItsOwnMeta() {
        append(rrwebEvent(4, 1), rrwebEvent(2, 1))
        _ = buffer.takeChunks(final: false, isFirstChunk: true)
        XCTAssertEqual(append(session: "s2", rrwebEvent(3, 2)), .appended(kept: 0, droppedBeforeMeta: 1))
    }

    func testATakeOfAnEmptyBufferSendsNothing() {
        XCTAssertTrue(buffer.takeChunks(final: false, isFirstChunk: true).isEmpty)
    }

    func testFinalTakeSendsEverythingAndClosesTheStream() throws {
        append(rrwebEvent(4, 1), rrwebEvent(2, 1))
        append(rrwebEvent(3, 2))
        XCTAssertEqual(try buffer.takeChunks(final: true, isFirstChunk: true).map(payloadTimestamps), [[1, 1, 2]])
        XCTAssertNil(buffer.openSessionId)
        XCTAssertNil(file("s1_upload_url.txt"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("s1").path))
        XCTAssertEqual(append(rrwebEvent(3, 3)), .appended(kept: 0, droppedBeforeMeta: 1))
    }

    func testChunksSayWhetherTheyHoldAMeta() {
        append(rrwebEvent(4, 1), rrwebEvent(2, 1))
        XCTAssertEqual(buffer.takeChunks(final: false, isFirstChunk: true).map(\.metadata.hasMeta), [true])
        append(rrwebEvent(3, 2))
        XCTAssertEqual(buffer.takeChunks(final: false, isFirstChunk: false).map(\.metadata.hasMeta), [false])
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

    func testWholeBatchesArePackedUnderTheLimit() throws {
        buffer = makeBuffer(maxUploadBytes: 5_000)
        for t in 1...6 { append(rrwebEvent(4, t), rrwebEvent(2, t, #"{"t":"\#(randomText(1_500))"}"#)) }
        let chunks = buffer.takeChunks(final: true, isFirstChunk: true)
        XCTAssertGreaterThan(chunks.count, 1)
        XCTAssertTrue(chunks.allSatisfy { $0.payload.count <= 5_000 })
        XCTAssertEqual(try chunks.flatMap(payloadTimestamps), (1...6).flatMap { [$0, $0] })   // whole batches, in order
    }

    func testABatchOverTheLimitGoesOutAlone() throws {
        buffer = makeBuffer(maxUploadBytes: 1_000)
        append(rrwebEvent(4, 1), rrwebEvent(2, 1, #"{"t":"\#(randomText(3_000))"}"#))
        append(rrwebEvent(4, 2), rrwebEvent(2, 2))
        let chunks = buffer.takeChunks(final: true, isFirstChunk: true)
        XCTAssertEqual(try chunks.map(payloadTimestamps), [[1, 1], [2, 2]])
        XCTAssertGreaterThan(chunks[0].payload.count, 1_000)   // the reporter drops it and counts the max-payload metric
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
