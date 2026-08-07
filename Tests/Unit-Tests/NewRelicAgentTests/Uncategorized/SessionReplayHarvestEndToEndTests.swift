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
/// through the REAL production path: SessionReplayManager.mergeAndSortReplayEvents()
/// + encodeReplayPayload() -- the merge+sort+encode+gzip logic extracted from
/// the private harvestSessionReplayFramesAndTouches()/createReplayUpload(),
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

        let container = manager.mergeAndSortReplayEvents(frames: [meta], touches: [touch])

        guard let (payload, _) = manager.encodeReplayPayload(container: container) else {
            XCTFail("encodeReplayPayload returned nil -- expected real encoded+gzipped bytes to inspect")
            return
        }

        let decompressed = try gunzip(payload)
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

    private func gunzip(_ data: Data) throws -> Data {
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
}
