//
//  WebViewReplayTests.swift
//  NewRelicAgent
//
//  Copyright © 2026 New Relic. All rights reserved.
//

import XCTest
@testable import NewRelic

class WebViewReplayTests: XCTestCase {

    private let meta = RRWebEventType.meta.rawValue
    private let full = RRWebEventType.fullSnapshot.rawValue
    private let incremental = RRWebEventType.incrementalSnapshot.rawValue

    private func envelope(_ type: Int, at timestamp: TimeInterval, channel: Int = 7, tag: String = "") -> WebViewReplayEnvelope {
        let json = "{\"type\":\(type),\"timestamp\":\(Int64(timestamp)),\"tag\":\"\(tag)\"}"
        return WebViewReplayEnvelope(channelId: channel, timestamp: timestamp, innerType: type, innerJSON: Data(json.utf8))
    }

    private func jsonObject(_ data: Data) throws -> [String: Any] {
        return try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    // MARK: - Parser

    func testParserAcceptsBareArray() {
        let body = #"[{"type":4,"timestamp":100,"data":{}},{"type":2,"timestamp":101,"data":{}}]"#
        let envelopes = WebViewReplayPayloadParser.envelopes(fromBridgeBody: body, channelId: 3, receivedAt: 999)
        XCTAssertEqual(envelopes.map { $0.innerType }, [meta, full])
        XCTAssertEqual(envelopes.map { $0.timestamp }, [100, 101])
        XCTAssertTrue(envelopes.allSatisfy { $0.channelId == 3 })
    }

    func testParserAcceptsBodyMemberAndStringifiedBody() {
        let wrapped = #"{"body":[{"type":3,"timestamp":5}]}"#
        XCTAssertEqual(WebViewReplayPayloadParser.envelopes(fromBridgeBody: wrapped, channelId: 1, receivedAt: 0).count, 1)

        let stringified = #"{"body":"[{\"type\":3,\"timestamp\":5}]"}"#
        XCTAssertEqual(WebViewReplayPayloadParser.envelopes(fromBridgeBody: stringified, channelId: 1, receivedAt: 0).count, 1)
    }

    func testParserFindsEventArrayUnderUnknownKey() {
        let body = #"{"meta":{"x":1},"events":[{"type":3,"timestamp":5}]}"#
        XCTAssertEqual(WebViewReplayPayloadParser.envelopes(fromBridgeBody: body, channelId: 1, receivedAt: 0).count, 1)
    }

    func testParserRejectsGarbage() {
        XCTAssertTrue(WebViewReplayPayloadParser.envelopes(fromBridgeBody: "", channelId: 1, receivedAt: 0).isEmpty)
        XCTAssertTrue(WebViewReplayPayloadParser.envelopes(fromBridgeBody: "not json", channelId: 1, receivedAt: 0).isEmpty)
        XCTAssertTrue(WebViewReplayPayloadParser.envelopes(fromBridgeBody: #"{"a":1}"#, channelId: 1, receivedAt: 0).isEmpty)
    }

    func testParserStripsInternalMembers() throws {
        let body = #"[{"type":2,"timestamp":10,"data":{"node":{}},"__serialized":"{huge}","__other":1}]"#
        let envelopes = WebViewReplayPayloadParser.envelopes(fromBridgeBody: body, channelId: 1, receivedAt: 0)
        let inner = try jsonObject(try XCTUnwrap(envelopes.first).innerJSON)
        XCTAssertNil(inner["__serialized"])
        XCTAssertNil(inner["__other"])
        XCTAssertNotNil(inner["data"])
    }

    func testParserFallsBackToReceivedTimeWithoutTimestamp() {
        let envelopes = WebViewReplayPayloadParser.envelopes(fromBridgeBody: #"[{"type":3}]"#, channelId: 1, receivedAt: 4242)
        XCTAssertEqual(envelopes.first?.timestamp, 4242)
    }

    // MARK: - Envelope

    func testEnvelopeEncodesPluginEvent() throws {
        let encoded = try jsonObject(envelope(full, at: 1234, channel: 42, tag: "doc").encoded())
        XCTAssertEqual(encoded["type"] as? Int, 6)
        XCTAssertEqual(encoded["timestamp"] as? Int, 1234)

        let data = try XCTUnwrap(encoded["data"] as? [String: Any])
        XCTAssertEqual(data["plugin"] as? String, "nr-webview-replay")
        let payload = try XCTUnwrap(data["payload"] as? [String: Any])
        XCTAssertEqual(payload["channelId"] as? String, "42")
        let inner = try XCTUnwrap(payload["innerEvent"] as? [String: Any])
        XCTAssertEqual(inner["type"] as? Int, full)
        XCTAssertEqual(inner["tag"] as? String, "doc")
    }

    func testReemitKeepsInnerEventAndMovesEnvelope() throws {
        let original = envelope(full, at: 100, tag: "doc")
        let copy = original.reemitted(at: 500)
        XCTAssertTrue(copy.isReemit)
        XCTAssertEqual(copy.timestamp, 500)
        XCTAssertEqual(copy.innerJSON, original.innerJSON)
    }

    // MARK: - Chunk builder

    func testCarriedDocumentLeadsChunkAheadOfLateEvents() {
        var documents: [Int: WebViewReplayDocument] = [7: WebViewReplayDocument(meta: envelope(meta, at: 10, tag: "m"),
                                                                                full: envelope(full, at: 10, tag: "d"))]
        // Captured during the previous chunk, arrived in this one.
        let late = envelope(incremental, at: 50, tag: "late")

        let out = WebViewReplayChunkBuilder.build(pending: [late],
                                                  nativeFullSnapshotTimestamps: [1000],
                                                  chunkStart: 1000,
                                                  reemitChannels: [7],
                                                  documents: &documents)

        XCTAssertEqual(out.map { $0.innerType }, [meta, full, incremental])
        XCTAssertTrue(out.allSatisfy { $0.timestamp == 1000 }, "Everything is clamped to the chunk start")
        XCTAssertTrue(out[0].isReemit && out[1].isReemit)
        XCTAssertFalse(out[2].isReemit)
    }

    func testDocumentReemittedAfterLaterNativeFullSnapshot() {
        var documents = [Int: WebViewReplayDocument]()
        let pending = [envelope(meta, at: 1100), envelope(full, at: 1100), envelope(incremental, at: 1200)]

        let out = WebViewReplayChunkBuilder.build(pending: pending,
                                                  nativeFullSnapshotTimestamps: [1000, 1500],
                                                  chunkStart: 1000,
                                                  reemitChannels: nil,
                                                  documents: &documents)

        XCTAssertEqual(out.map { $0.timestamp }, [1100, 1100, 1200, 1500, 1500])
        XCTAssertEqual(out.map { $0.innerType }, [meta, full, incremental, meta, full])
        XCTAssertEqual(out.filter { $0.isReemit }.count, 2)
        XCTAssertNotNil(documents[7], "The last document is carried into the next chunk")
    }

    func testNoReemitWhenDocumentAlreadyFollowsSnapshot() {
        var documents = [Int: WebViewReplayDocument]()
        // Same ms as the native snapshot: it sorts after it, so it already covers it.
        let pending = [envelope(meta, at: 1500), envelope(full, at: 1500)]

        let out = WebViewReplayChunkBuilder.build(pending: pending,
                                                  nativeFullSnapshotTimestamps: [1000, 1500],
                                                  chunkStart: 1000,
                                                  reemitChannels: nil,
                                                  documents: &documents)

        XCTAssertFalse(out.contains { $0.isReemit })
        XCTAssertEqual(out.count, 2)
    }

    func testOffscreenChannelIsNotReemittedButKeepsItsDocument() {
        var documents: [Int: WebViewReplayDocument] = [7: WebViewReplayDocument(meta: nil, full: envelope(full, at: 10))]

        let out = WebViewReplayChunkBuilder.build(pending: [],
                                                  nativeFullSnapshotTimestamps: [1000],
                                                  chunkStart: 1000,
                                                  reemitChannels: [],
                                                  documents: &documents)

        XCTAssertTrue(out.isEmpty)
        XCTAssertNotNil(documents[7])
    }

    func testFreshDocumentLeadingChunkReplacesCarriedCopy() {
        var documents: [Int: WebViewReplayDocument] = [7: WebViewReplayDocument(meta: envelope(meta, at: 10, tag: "old-m"),
                                                                                full: envelope(full, at: 10, tag: "old-d"))]
        // Requested at the last harvest, landing just after this chunk starts.
        let pending = [envelope(meta, at: 1001, tag: "new-m"), envelope(full, at: 1001, tag: "new-d"), envelope(incremental, at: 1200)]

        let out = WebViewReplayChunkBuilder.build(pending: pending,
                                                  nativeFullSnapshotTimestamps: [1000],
                                                  chunkStart: 1000,
                                                  reemitChannels: [7],
                                                  documents: &documents)

        XCTAssertFalse(out.contains { $0.isReemit }, "The carried copy would be replaced at once")
        XCTAssertEqual(out.map { $0.innerType }, [meta, full, incremental])
        XCTAssertEqual(documents[7]?.full.timestamp, 1001)
    }

    func testCarriedCopyStillLeadsWhenChunkStartsWithChanges() {
        var documents: [Int: WebViewReplayDocument] = [7: WebViewReplayDocument(meta: nil, full: envelope(full, at: 10))]
        let pending = [envelope(incremental, at: 1100), envelope(meta, at: 1300), envelope(full, at: 1300)]

        let out = WebViewReplayChunkBuilder.build(pending: pending,
                                                  nativeFullSnapshotTimestamps: [1000],
                                                  chunkStart: 1000,
                                                  reemitChannels: [7],
                                                  documents: &documents)

        XCTAssertEqual(out.map { $0.innerType }, [full, incremental, meta, full])
        XCTAssertTrue(out[0].isReemit, "Changes ahead of the fresh document need the carried one to apply to")
    }

    func testNoReemitAtFullSnapshotThatDoesNotShowWebView() {
        var documents = [Int: WebViewReplayDocument]()
        let pending = [envelope(meta, at: 1100), envelope(full, at: 1100), envelope(incremental, at: 1200)]

        let out = WebViewReplayChunkBuilder.build(pending: pending,
                                                  nativeFullSnapshotTimestamps: [1000, 1500, 1800],
                                                  chunkStart: 1000,
                                                  reemitChannels: [7],
                                                  fullSnapshotChannels: [1000: [7], 1500: [], 1800: [7]],
                                                  documents: &documents)

        XCTAssertEqual(out.filter { $0.isReemit }.map { $0.timestamp }, [1800, 1800],
                       "Off screen at 1500, so only the snapshot that shows it gets a copy")
    }

    func testChannelsInterleaveWithoutReordering() {
        var documents = [Int: WebViewReplayDocument]()
        let pending = [envelope(full, at: 1100, channel: 1, tag: "a1"),
                       envelope(full, at: 1050, channel: 2, tag: "b1"),
                       envelope(incremental, at: 1100, channel: 1, tag: "a2")]

        let out = WebViewReplayChunkBuilder.build(pending: pending,
                                                  nativeFullSnapshotTimestamps: [1000],
                                                  chunkStart: 1000,
                                                  reemitChannels: nil,
                                                  documents: &documents)

        XCTAssertEqual(out.map { $0.channelId }, [2, 1, 1])
        XCTAssertEqual(out.map { $0.innerType }, [full, full, incremental])
    }

    // MARK: - Payload budget

    private func pieces(_ envelopes: [WebViewReplayEnvelope], native: Int = 0) -> [WebViewReplayPayloadBudget.Piece] {
        var result = [WebViewReplayPayloadBudget.Piece]()
        for index in 0..<native {
            result.append(.init(event: .native(makeMetaAnyRRWebEvent(timestamp: TimeInterval(index))), json: Data(repeating: 0x20, count: 10)))
        }
        for envelope in envelopes {
            result.append(.init(event: .webView(envelope), json: envelope.encoded()))
        }
        return result
    }

    func testBudgetLeavesChunkUnderLimitAlone() {
        let input = pieces([envelope(full, at: 1)], native: 2)
        let result = WebViewReplayPayloadBudget.enforce(input, limit: 1_000_000) { $0.count }
        XCTAssertEqual(result.shedCount, 0)
        XCTAssertEqual(result.pieces.count, input.count)
    }

    func testBudgetShedsSupersededDocumentBeforeFinalOne() {
        let superseded = envelope(full, at: 1, tag: String(repeating: "x", count: 400))
        let final = envelope(full, at: 2, tag: "y")
        let input = pieces([superseded, final], native: 2)
        let total = WebViewReplayPayloadBudget.joinedJSON(input).count

        // Just over the cap, with the identity as "compression".
        let result = WebViewReplayPayloadBudget.enforce(input, limit: total - 1) { $0.count }

        XCTAssertEqual(result.shedCount, 1)
        let keptDocuments = result.pieces.compactMap { $0.event.webViewEnvelope }
        XCTAssertEqual(keptDocuments.map { $0.timestamp }, [2], "The final document outlives a larger superseded one")
        XCTAssertEqual(result.pieces.filter { $0.event.webViewEnvelope == nil }.count, 2, "Native events are never shed")
    }

    func testBudgetWithNoDocumentsReturnsInput() {
        let input = pieces([envelope(incremental, at: 1)], native: 1)
        let result = WebViewReplayPayloadBudget.enforce(input, limit: 1) { $0.count }
        XCTAssertEqual(result.shedCount, 0)
        XCTAssertEqual(result.pieces.count, input.count)
    }

    func testJoinedJSONIsAValidArray() throws {
        let joined = WebViewReplayPayloadBudget.joinedJSON(pieces([envelope(full, at: 1), envelope(incremental, at: 2)]))
        let array = try XCTUnwrap(try JSONSerialization.jsonObject(with: joined) as? [[String: Any]])
        XCTAssertEqual(array.count, 2)
    }

    // MARK: - Harvest merge

    private func makeManager() -> SessionReplayManager {
        let reporter = SessionReplayReporter(applicationToken: "test-token", url: "mobile-collector.newrelic.com" as NSString)
        return SessionReplayManager(reporter: reporter, url: "mobile-collector.newrelic.com" as NSString)
    }

    func testMergeKeepsNativeAnchorsFirstAndWebViewAfterNativeAtTies() {
        let manager = makeManager()
        let frames = [makeMetaAnyRRWebEvent(timestamp: 1000),
                      makeFullSnapshotAnyRRWebEvent(timestamp: 1000),
                      makeFullSnapshotAnyRRWebEvent(timestamp: 2000)]
        let touches = [makeTouchAnyRRWebEvent(timestamp: 1500)]
        let webView = [envelope(full, at: 1000), envelope(incremental, at: 1500), envelope(full, at: 2000)]

        let chunk = manager.mergeReplayChunk(frames: frames, touches: touches, webViewEvents: webView)

        let kinds: [String] = chunk.map { event in
            switch event {
            case .native(let native): return "n\(native.base.type.rawValue)@\(Int(native.base.timestamp))"
            case .webView(let envelope): return "w\(envelope.innerType)@\(Int(envelope.timestamp))"
            }
        }
        XCTAssertEqual(kinds, ["n4@1000", "n2@1000", "w2@1000", "n3@1500", "w3@1500", "n2@2000", "w2@2000"])
    }

    func testEncodeChunkProducesTimestampsFromEnds() throws {
        let manager = makeManager()
        let chunk = manager.mergeReplayChunk(frames: [makeMetaAnyRRWebEvent(timestamp: 1000), makeFullSnapshotAnyRRWebEvent(timestamp: 1000)],
                                             touches: [],
                                             webViewEvents: [envelope(incremental, at: 3000)])

        let encoded = try XCTUnwrap(manager.encodeReplayChunk(chunk))
        XCTAssertEqual(encoded.firstTimestamp, 1000)
        XCTAssertEqual(encoded.lastTimestamp, 3000)
        XCTAssertGreaterThan(encoded.uncompressedSize, 0)
    }

    func testMergeWithoutWebViewEventsMatchesNativeMerge() {
        let manager = makeManager()
        let frames = [makeMetaAnyRRWebEvent(timestamp: 1000), makeFullSnapshotAnyRRWebEvent(timestamp: 1000)]
        let touches = [makeTouchAnyRRWebEvent(timestamp: 999)]

        let chunk = manager.mergeReplayChunk(frames: frames, touches: touches, webViewEvents: [])
        let native = manager.mergeAndSortReplayEvents(frames: frames, touches: touches)

        XCTAssertEqual(chunk.map { $0.timestamp }, native.map { $0.base.timestamp })
    }
}
