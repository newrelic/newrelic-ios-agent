//
//  SessionReplayHarvestEndToEndTests.swift
//  NewRelicAgent
//
//  Copyright © 2026 New Relic. All rights reserved.
//

import XCTest
import zlib
@testable import NewRelic

/// End-to-end reproduction of the "First event didn't include meta" defect,
/// through the REAL production path: SessionReplayManager.mergeReplayChunk()
/// + encodeReplayChunk() -- the merge+sort+encode+gzip logic extracted from
/// the private harvestSessionReplayFramesAndTouches()/buildReplayUploads(),
/// still the exact code the real harvest timer calls. Stops short of
/// building the final upload URL (which needs a resolvable harvester
/// configuration -- a real singleton that requires either a full collector
/// connect handshake or persisting matching data across two NSUserDefaults
/// keys, neither of which this test needs to prove the actual bug).
///
/// Unlike SessionReplayEventOrderingTests (which mirrors the sort logic in
/// isolation), this exercises the actual shipping methods and inspects the
/// actual gzipped JSON payload that would be POSTed.
class SessionReplayHarvestEndToEndTests: XCTestCase {

    func testRealHarvestPathCanEncodeTouchBeforeMetaEvent() throws {
        let reporter = SessionReplayReporter(
            applicationToken: "test-token",
            url: "mobile-collector.newrelic.com" as NSString
        )
        let manager = SessionReplayManager(reporter: reporter, url: "mobile-collector.newrelic.com" as NSString)

        let meta = makeMetaAnyRRWebEvent(timestamp: 1_000)
        let touch = makeTouchAnyRRWebEvent(timestamp: 999) // 1ms before the chunk's first frame

        let chunk = manager.mergeReplayChunk(frames: [meta], touches: [touch], webViewEvents: [])

        guard let payload = manager.encodeReplayChunk(chunk)?.first else {
            XCTFail("encodeReplayChunk returned nil -- expected real encoded+gzipped bytes to inspect")
            return
        }

        let decompressed = try gunzip(payload.data)
        let jsonArray = try JSONSerialization.jsonObject(with: decompressed) as? [[String: Any]]
        let firstEventType = jsonArray?.first?["type"] as? Int

        XCTAssertEqual(firstEventType, RRWebEventType.meta.rawValue,
            "The real end-to-end harvest path (merge, sort, JSON-encode, gzip) should never " +
            "produce an encoded chunk whose first event isn't Meta; got type \(String(describing: firstEventType)). " +
            "This is the exact payload shape that causes the rrweb player's " +
            "\"First event didn't include meta\" error.")
    }

    /// Reproduces a second, distinct defect in the same merge path: a raw
    /// frames array of [Meta, FullSnapshot, ...] (what getSessionReplayFrames()
    /// always produces) had only its Meta anchored -- the FullSnapshot right
    /// after it was sorted in with touches like any other event, so a touch
    /// timestamped at or before it could displace it. Confirmed via a real
    /// device repro where navigating across several screens (each forcing a
    /// fresh full snapshot) turned a raw [meta, fullSnapshot, ...] sequence
    /// into a merged [meta, touch, touch, fullSnapshot, ...] one.
    func testRealHarvestPathCanEncodeTouchBeforeFullSnapshotEvent() throws {
        let reporter = SessionReplayReporter(
            applicationToken: "test-token",
            url: "mobile-collector.newrelic.com" as NSString
        )
        let manager = SessionReplayManager(reporter: reporter, url: "mobile-collector.newrelic.com" as NSString)

        let meta = makeMetaAnyRRWebEvent(timestamp: 1_000)
        let fullSnapshot = makeFullSnapshotAnyRRWebEvent(timestamp: 1_000) // same timestamp as meta, as production always produces
        let touch = makeTouchAnyRRWebEvent(timestamp: 999) // 1ms before the chunk's leading events

        let container = manager.mergeAndSortReplayEvents(frames: [meta, fullSnapshot], touches: [touch])

        XCTAssertEqual(container.map { $0.base.type }, [.meta, .fullSnapshot, .incrementalSnapshot],
            "The FullSnapshot immediately following Meta establishes the DOM node IDs that later " +
            "incremental/touch events reference, so it must stay pinned right after Meta -- got " +
            "\(container.map { $0.base.type }). A touch sorting ahead of it produces a payload the " +
            "rrweb player can't apply its own later mutations against.")
    }
}

fileprivate func gunzip(_ data: Data) throws -> Data {
    var stream = z_stream()
    var status = inflateInit2_(&stream, 15 + 16, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
    guard status == Z_OK else {
        throw NSError(domain: "gunzip", code: Int(status), userInfo: nil)
    }
    defer { inflateEnd(&stream) }

    var output = Data()
    try data.withUnsafeBytes { (inputBuffer: UnsafeRawBufferPointer) in
        stream.next_in = UnsafeMutablePointer(mutating: inputBuffer.baseAddress!.assumingMemoryBound(to: Bytef.self))
        stream.avail_in = uInt(data.count)

        repeat {
            let chunkSize = 16384
            var outputBuffer = [UInt8](repeating: 0, count: chunkSize)
            try outputBuffer.withUnsafeMutableBytes { (outputBufferPointer: UnsafeMutableRawBufferPointer) in
                let typedPointer = outputBufferPointer.baseAddress!.assumingMemoryBound(to: Bytef.self)
                stream.next_out = typedPointer
                stream.avail_out = uInt(chunkSize)

                status = inflate(&stream, Z_NO_FLUSH)
                guard status == Z_OK || status == Z_STREAM_END else {
                    throw NSError(domain: "gunzip", code: Int(status), userInfo: nil)
                }

                let bytesWritten = chunkSize - Int(stream.avail_out)
                if bytesWritten > 0 {
                    output.append(typedPointer, count: bytesWritten)
                }
            }
        } while status != Z_STREAM_END
    }
    return output
}

/// Deterministic filler that gzip can't shrink much, so payload sizes are predictable without
/// having to build megabytes of real events.
fileprivate func incompressibleText(_ length: Int, seed: UInt64) -> String {
    let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
    var state = seed &+ 0x9E3779B97F4A7C15
    var characters = [Character]()
    characters.reserveCapacity(length)
    for _ in 0..<length {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        characters.append(alphabet[Int(state >> 58)])
    }
    return String(characters)
}

fileprivate func jsonArray(_ data: Data) throws -> [[String: Any]] {
    return try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
}

/// ReplayPayloadSplitter on its own, with an identity "compressor" so sizes are exact.
class ReplayPayloadSplitterTests: XCTestCase {

    /// A piece whose JSON is exactly `size` bytes: {"tag":"<tag>","pad":"…"}.
    private func piece(_ tag: String, size: Int, at timestamp: TimeInterval = 0, canStartUpload: Bool = true) -> ReplayPayloadSplitter.Piece {
        let skeleton = "{\"tag\":\"\(tag)\",\"pad\":\"\"}"
        let json = "{\"tag\":\"\(tag)\",\"pad\":\"\(String(repeating: "x", count: max(0, size - skeleton.utf8.count)))\"}"
        return .init(json: Data(json.utf8), timestamp: timestamp, canStartUpload: canStartUpload)
    }

    private func split(_ pieces: [ReplayPayloadSplitter.Piece], limit: Int) -> (payloads: [ReplayPayloadSplitter.Payload], dropped: [Int]) {
        return ReplayPayloadSplitter.split(pieces, limit: limit) { $0 }
    }

    private func tags(_ payload: ReplayPayloadSplitter.Payload) throws -> [String] {
        return try jsonArray(payload.data).map { $0["tag"] as? String ?? "?" }
    }

    func testChunkUnderTheCapIsOnePayloadOfTheWholeChunk() throws {
        let pieces = [piece("a", size: 40, at: 1), piece("b", size: 40, at: 2), piece("c", size: 40, at: 3)]

        let result = split(pieces, limit: 1_000)

        XCTAssertEqual(result.payloads.count, 1)
        XCTAssertTrue(result.dropped.isEmpty)
        let payload = try XCTUnwrap(result.payloads.first)
        XCTAssertEqual(payload.data, ReplayPayloadSplitter.joinedJSON(pieces))
        XCTAssertEqual(payload.uncompressedSize, payload.data.count)
        XCTAssertEqual(try tags(payload), ["a", "b", "c"])
        XCTAssertEqual(payload.firstTimestamp, 1)
        XCTAssertEqual(payload.lastTimestamp, 3)
    }

    func testOverCapChunkSplitsIntoInOrderPayloadsThatEachFit() throws {
        let pieces = (0..<10).map { piece("p\($0)", size: 100, at: TimeInterval($0)) }

        let result = split(pieces, limit: 350)

        XCTAssertGreaterThan(result.payloads.count, 1)
        XCTAssertTrue(result.dropped.isEmpty, "Nothing fits the cap on its own only if it is over it alone")
        for payload in result.payloads {
            XCTAssertLessThanOrEqual(payload.data.count, 350)
            let payloadTags = try tags(payload)
            XCTAssertEqual(payload.firstTimestamp, TimeInterval(Int(payloadTags.first!.dropFirst())!))
            XCTAssertEqual(payload.lastTimestamp, TimeInterval(Int(payloadTags.last!.dropFirst())!))
        }
        XCTAssertEqual(try result.payloads.flatMap { try tags($0) }, (0..<10).map { "p\($0)" },
                       "Every event is uploaded exactly once, in the original order")
    }

    func testChunkIsCutByBytesNotByEventCount() throws {
        // By count, the first cut would be [big, s1] | [s2, s3, s4], and [big, s1] is over the cap.
        let pieces = [piece("big", size: 600), piece("s1", size: 100), piece("s2", size: 100), piece("s3", size: 100), piece("s4", size: 100)]

        let result = split(pieces, limit: 650)

        XCTAssertEqual(try result.payloads.map { try tags($0) }, [["big"], ["s1", "s2", "s3", "s4"]])
    }

    func testPieceOverTheCapOnItsOwnIsDroppedAndTheRestKept() throws {
        let pieces = [piece("a", size: 50), piece("huge", size: 500), piece("b", size: 50)]

        let result = split(pieces, limit: 200)

        XCTAssertEqual(result.dropped, [1])
        XCTAssertEqual(try result.payloads.flatMap { try tags($0) }, ["a", "b"])
    }

    func testUploadDoesNotStartAtAPieceThatDependsOnTheOneBefore() throws {
        // The byte midpoint is right before "fullSnapshot", which must stay with "meta".
        let pieces = [piece("meta", size: 450), piece("fullSnapshot", size: 450, canStartUpload: false),
                      piece("x", size: 50), piece("y", size: 50)]

        let result = split(pieces, limit: 950)

        XCTAssertEqual(try result.payloads.map { try tags($0) }, [["meta", "fullSnapshot"], ["x", "y"]])
    }

    func testChunkWithNowhereAllowedToCutIsStillSplitRatherThanLost() throws {
        let pieces = [piece("a", size: 300)] + (1..<4).map { piece("p\($0)", size: 300, canStartUpload: false) }

        let result = split(pieces, limit: 700)

        XCTAssertGreaterThan(result.payloads.count, 1)
        XCTAssertEqual(try result.payloads.flatMap { try tags($0) }, ["a", "p1", "p2", "p3"])
    }

    func testEmptyChunkHasNoPayloads() {
        let result = split([], limit: 100)
        XCTAssertTrue(result.payloads.isEmpty)
        XCTAssertTrue(result.dropped.isEmpty)
    }
}

/// The splitter wired into the real harvest and crash-recovery paths, with real gzip.
class SessionReplayPayloadSplitTests: XCTestCase {

    private func makeManager() -> SessionReplayManager {
        let reporter = SessionReplayReporter(applicationToken: "test-token", url: "mobile-collector.newrelic.com" as NSString)
        return SessionReplayManager(reporter: reporter, url: "mobile-collector.newrelic.com" as NSString)
    }

    private func webViewEvent(_ tag: String, group: Int?, padding: Int, at timestamp: TimeInterval, seed: UInt64) -> ReplayChunkEvent {
        let json = "{\"type\":3,\"timestamp\":\(Int(timestamp)),\"data\":{\"source\":0,\"tag\":\"\(tag)\",\"pad\":\"\(incompressibleText(padding, seed: seed))\"}}"
        return .webView(WebViewReplayOutputEvent(channelId: 7, timestamp: timestamp, json: Data(json.utf8), graftGroup: group))
    }

    private func label(_ event: [String: Any]) -> String {
        if let data = event["data"] as? [String: Any], let tag = data["tag"] as? String {
            return tag
        }
        return "type\(event["type"] as? Int ?? -1)@\(event["timestamp"] as? Int ?? -1)"
    }

    func testOversizedHarvestIsSplitWithoutLosingOrSeparatingAnything() throws {
        let manager = makeManager()
        let chunk: [ReplayChunkEvent] = [
            .native(makeMetaAnyRRWebEvent(timestamp: 1000)),
            .native(makeFullSnapshotAnyRRWebEvent(timestamp: 1000)),
            webViewEvent("graft1", group: 1, padding: 2000, at: 1000, seed: 1),
            webViewEvent("backlog1", group: 1, padding: 1000, at: 1000, seed: 2),
            .native(makeTouchAnyRRWebEvent(timestamp: 1500)),
            webViewEvent("live", group: nil, padding: 200, at: 1600, seed: 3),
            webViewEvent("graft2", group: 2, padding: 2000, at: 2000, seed: 4),
            webViewEvent("backlog2", group: 2, padding: 1000, at: 2000, seed: 5),
        ]
        let unsplit = try XCTUnwrap(manager.encodeReplayChunk(chunk, limit: Int.max))
        XCTAssertEqual(unsplit.count, 1)
        let limit = unsplit[0].data.count * 2 / 3

        let payloads = try XCTUnwrap(manager.encodeReplayChunk(chunk, limit: limit))

        XCTAssertGreaterThan(payloads.count, 1)
        var uploaded = [[String]]()
        for payload in payloads {
            XCTAssertTrue(payload.data.isGzipped)
            XCTAssertLessThanOrEqual(payload.data.count, limit)
            let json = try gunzip(payload.data)
            XCTAssertEqual(payload.uncompressedSize, json.count)
            let events = try jsonArray(json)
            XCTAssertEqual(payload.firstTimestamp, TimeInterval(events.first?["timestamp"] as? Int ?? -1))
            XCTAssertEqual(payload.lastTimestamp, TimeInterval(events.last?["timestamp"] as? Int ?? -1))
            uploaded.append(events.map(label))
        }

        let expected = try jsonArray(try gunzip(unsplit[0].data)).map(label)
        XCTAssertEqual(uploaded.flatMap { $0 }, expected, "Every event is uploaded exactly once, in order")
        XCTAssertEqual(Array(uploaded[0].prefix(2)), ["type4@1000", "type2@1000"], "Meta and its FullSnapshot lead the first upload")
        for (graft, backlog) in [("graft1", "backlog1"), ("graft2", "backlog2")] {
            XCTAssertTrue(uploaded.contains { $0.contains(graft) && $0.contains(backlog) },
                          "\(graft) and its backlog go in the same upload: \(uploaded)")
        }
    }

    func testReplayEventsDecodeFromTheirOwnEncoding() throws {
        let original = Data("""
        [{"type":4,"timestamp":1000,"data":{"href":"http://newrelic.com","width":390,"height":844}},
         {"type":2,"timestamp":1000,"data":{"node":{"type":0,"id":1,"childNodes":[{"type":2,"id":2,"tagName":"html","attributes":{},"childNodes":[{"type":2,"id":3,"tagName":"body","attributes":{"style":"color: red"},"childNodes":[{"type":3,"id":4,"isStyle":false,"textContent":"hi"}]}]}]},"initialOffset":{"top":0,"left":0}}},
         {"type":3,"timestamp":1100,"data":{"source":2,"type":7,"id":3,"x":10,"y":20}},
         {"type":3,"timestamp":1150,"data":{"source":6,"positions":[{"x":1,"y":2,"id":3,"timeOffset":0}]}},
         {"type":3,"timestamp":1200,"data":{"source":0,"adds":[{"parentId":3,"node":{"type":3,"id":5,"isStyle":false,"textContent":"new"}}],"removes":[{"parentId":3,"id":4}],"texts":[],"attributes":[]}}]
        """.utf8)

        let decoded = try JSONDecoder().decode([AnyRRWebEvent].self, from: original)
        XCTAssertEqual(decoded.map { $0.base.type }, [.meta, .fullSnapshot, .incrementalSnapshot, .incrementalSnapshot, .incrementalSnapshot])

        let reencoded = try JSONEncoder().encode(decoded)
        XCTAssertEqual(try JSONSerialization.jsonObject(with: reencoded) as? NSArray,
                       try JSONSerialization.jsonObject(with: original) as? NSArray)
    }

    func testElementWithoutChildNodesDecodes() throws {
        let json = Data(#"[{"type":3,"timestamp":1,"data":{"source":0,"adds":[{"parentId":1,"node":{"type":2,"id":2,"tagName":"div","attributes":{}}}]}}]"#.utf8)
        XCTAssertEqual(try JSONDecoder().decode([AnyRRWebEvent].self, from: json).count, 1)
    }

    // MARK: - Crash recovery

    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("ReplaySplitTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func writeFrame(_ index: Int, _ json: String) throws {
        try Data(json.utf8).write(to: directory.appendingPathComponent("frame_\(index).json"))
    }

    private func incremental(at timestamp: Int, padding: Int, seed: UInt64) -> String {
        return "{\"type\":3,\"timestamp\":\(timestamp),\"data\":{\"source\":0,\"texts\":[{\"id\":1,\"value\":\"\(incompressibleText(padding, seed: seed))\"}]}}"
    }

    private func persistedURL(attributes: String) throws -> URL {
        var components = try XCTUnwrap(URLComponents(string: "https://mobile-collector.newrelic.com/mobile/blobs"))
        components.queryItems = [URLQueryItem(name: "type", value: "SessionReplay"),
                                 URLQueryItem(name: "app_id", value: "42"),
                                 URLQueryItem(name: "attributes", value: attributes)]
        return try XCTUnwrap(components.url)
    }

    func testPersistedSessionIsSplitBetweenFramesFromTheFirstFullSnapshot() throws {
        let manager = makeManager()
        try writeFrame(0, "[\(incremental(at: 900, padding: 10, seed: 1))]")
        try writeFrame(1, """
            [{"type":4,"timestamp":1000,"data":{"href":"http://newrelic.com","width":390,"height":844}},
             {"type":2,"timestamp":1000,"data":{"node":{"type":0,"id":1},"initialOffset":{"top":0,"left":0}}},
             \(incremental(at: 999, padding: 1500, seed: 2))]
            """)
        try writeFrame(2, "[\(incremental(at: 2000, padding: 1500, seed: 3)),\(incremental(at: 2001, padding: 10, seed: 4))]")
        try writeFrame(3, #"[{"type":3,"timest"#)  // cut short by the crash
        try writeFrame(10, " [\(incremental(at: 3000, padding: 1500, seed: 5))] \n")

        let pieces = try manager.persistedReplayPieces(sessionDirectory: directory)

        XCTAssertEqual(pieces.map { $0.firstTimestamp }, [1000, 2000, 3000],
                       "Frames before the first full snapshot and unreadable frames are skipped; frame_10 sorts after frame_2")
        XCTAssertEqual(pieces.map { $0.lastTimestamp }, [999, 2001, 3000])

        let url = try persistedURL(attributes: "entityGuid=abc&isFirstChunk=true&decompressedBytes=1&replay.firstTimestamp=1&replay.lastTimestamp=2&content_encoding=gzip&custom=a=b")
        let unsplit = manager.persistedReplayUploads(pieces: pieces, persistedURL: url, limit: Int.max)
        XCTAssertEqual(unsplit.count, 1)
        let limit = unsplit[0].sessionReplayFramesData.count * 2 / 3

        let uploads = manager.persistedReplayUploads(pieces: pieces, persistedURL: url, limit: limit)

        XCTAssertGreaterThan(uploads.count, 1)
        var timestamps = [Int]()
        for (index, upload) in uploads.enumerated() {
            XCTAssertLessThanOrEqual(upload.sessionReplayFramesData.count, limit)
            let json = try gunzip(upload.sessionReplayFramesData)
            let events = try jsonArray(json)
            timestamps.append(contentsOf: events.map { $0["timestamp"] as? Int ?? -1 })

            XCTAssertEqual(SessionReplayReporter.replayAttribute("isFirstChunk", of: upload.url), String(index == 0))
            XCTAssertEqual(SessionReplayReporter.replayAttribute("decompressedBytes", of: upload.url), String(json.count))
            XCTAssertEqual(SessionReplayReporter.replayAttribute("replay.firstTimestamp", of: upload.url), String(events.first?["timestamp"] as? Int ?? -1))
            XCTAssertEqual(SessionReplayReporter.replayAttribute("replay.lastTimestamp", of: upload.url), String(events.last?["timestamp"] as? Int ?? -1))
            XCTAssertEqual(SessionReplayReporter.replayAttribute("content_encoding", of: upload.url), "gzip")
            XCTAssertEqual(SessionReplayReporter.replayAttribute("entityGuid", of: upload.url), "abc")
            XCTAssertEqual(SessionReplayReporter.replayAttribute("custom", of: upload.url), "a=b")
            XCTAssertEqual(URLComponents(url: upload.url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "app_id" }?.value, "42")
        }
        XCTAssertEqual(timestamps, [1000, 1000, 999, 2000, 2001, 3000], "Every persisted event is uploaded exactly once, in order")
    }

    func testPersistedSessionThatWasNotTheFirstChunkStaysThatWay() throws {
        let manager = makeManager()
        try writeFrame(0, #"[{"type":4,"timestamp":1000,"data":{"href":"http://newrelic.com","width":1,"height":1}},{"type":2,"timestamp":1000,"data":{"node":{"type":0,"id":1},"initialOffset":{"top":0,"left":0}}}]"#)
        let url = try persistedURL(attributes: "isFirstChunk=false&decompressedBytes=1")

        let uploads = manager.persistedReplayUploads(pieces: try manager.persistedReplayPieces(sessionDirectory: directory), persistedURL: url)

        XCTAssertEqual(uploads.count, 1)
        XCTAssertEqual(SessionReplayReporter.replayAttribute("isFirstChunk", of: uploads[0].url), "false")
    }

    func testRewritingReplayAttributes() throws {
        let url = try persistedURL(attributes: "a=1&content_encoding=gzip&b=x=y")

        let rewritten = try XCTUnwrap(SessionReplayReporter.rewritingReplayAttributes(of: url, setting: ["a": "2", "c": "3"], removing: ["content_encoding"]))

        let attributes = URLComponents(url: rewritten, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "attributes" }?.value
        XCTAssertEqual(attributes, "a=2&b=x=y&c=3")
        XCTAssertNil(SessionReplayReporter.replayAttribute("content_encoding", of: rewritten))
        XCTAssertNil(SessionReplayReporter.replayAttribute("missing", of: rewritten))
    }
}
