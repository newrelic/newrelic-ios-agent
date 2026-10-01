//
//  WebViewReplayTests.swift
//  NewRelicAgent
//
//  Copyright © 2026 New Relic. All rights reserved.
//

import XCTest
@testable import NewRelic

class WebViewReplayTests: XCTestCase {

    private let iframeId = 7

    private func json(_ data: Data) throws -> [String: Any] {
        return try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func parse(_ text: String) throws -> [[String: Any]] {
        return try XCTUnwrap(WebViewReplayPayloadParser.extractEvents(from: text))
    }

    // MARK: - Parser

    func testParserAcceptsBareArrayBodyMemberAndStringifiedBody() throws {
        XCTAssertEqual(try parse(#"[{"type":4},{"type":2}]"#).count, 2)
        XCTAssertEqual(try parse(#"{"body":[{"type":3}]}"#).count, 1)
        XCTAssertEqual(try parse(#"{"body":"[{\"type\":3}]"}"#).count, 1)
        XCTAssertEqual(try parse(#"{"meta":{"x":1},"events":[{"type":3}]}"#).count, 1)
    }

    func testParserRejectsGarbage() {
        XCTAssertNil(WebViewReplayPayloadParser.extractEvents(from: ""))
        XCTAssertNil(WebViewReplayPayloadParser.extractEvents(from: "not json"))
        XCTAssertNil(WebViewReplayPayloadParser.extractEvents(from: #"{"a":1}"#))
    }

    // MARK: - Remapper

    private let pageSnapshot = #"""
    {"type":2,"timestamp":1000,"__serialized":"{huge}","data":{"node":{"type":0,"id":1,"childNodes":[
      {"type":2,"id":2,"tagName":"html","attributes":{"id":"css-id","lang":"en"},"childNodes":[
        {"type":2,"id":3,"tagName":"body","attributes":{},"childNodes":[{"type":3,"id":4,"textContent":"hi"}]}]}]},
      "initialOffset":{"top":0,"left":0}}}
    """#

    func testDocumentIsRemappedIntoItsOwnBlock() throws {
        let remapper = WebViewReplayRemapper(channelId: iframeId)
        let event = try XCTUnwrap(remapper.translate(try parse("[\(pageSnapshot)]"), receivedAt: 0).first)

        guard case .document(let rootId) = event.kind else { return XCTFail("expected a document") }
        let base = rootId - 1
        XCTAssertGreaterThanOrEqual(base, WebViewReplayRemapper.idOffset)
        XCTAssertEqual(event.timestamp, 1000)

        let node = try json(event.json)
        XCTAssertEqual(node["type"] as? Int, 0, "The event carries the document node itself")
        XCTAssertEqual(node["id"] as? Int, base + 1)
        let html = try XCTUnwrap((node["childNodes"] as? [[String: Any]])?.first)
        XCTAssertEqual(html["id"] as? Int, base + 2)
        let attributes = try XCTUnwrap(html["attributes"] as? [String: Any])
        XCTAssertEqual(attributes["id"] as? String, "css-id", "An HTML id attribute is not a node ID")
        XCTAssertNil(node["__serialized"])
    }

    func testIncrementalIdsFollowTheirDocument() throws {
        let remapper = WebViewReplayRemapper(channelId: iframeId)
        let mutation = #"{"type":3,"timestamp":1100,"data":{"source":0,"texts":[{"id":4,"value":"x"}],"attributes":[{"id":2,"attributes":{"id":"new-css-id"}}],"removes":[{"parentId":3,"id":4}],"adds":[{"parentId":3,"nextId":null,"node":{"type":3,"id":5,"textContent":"y"}}]}}"#
        let translated = remapper.translate(try parse("[\(pageSnapshot),\(mutation)]"), receivedAt: 0)
        XCTAssertEqual(translated.count, 2)
        guard case .document(let rootId) = translated[0].kind else { return XCTFail() }
        let base = rootId - 1

        XCTAssertEqual(translated[1].kind, .incremental(changesState: true))
        let data = try json(translated[1].json)
        XCTAssertEqual((data["texts"] as? [[String: Any]])?.first?["id"] as? Int, base + 4)
        let attributeRecord = try XCTUnwrap((data["attributes"] as? [[String: Any]])?.first)
        XCTAssertEqual(attributeRecord["id"] as? Int, base + 2, "A mutation's attribute record id IS a node ID")
        XCTAssertEqual((attributeRecord["attributes"] as? [String: Any])?["id"] as? String, "new-css-id")
        let remove = try XCTUnwrap((data["removes"] as? [[String: Any]])?.first)
        XCTAssertEqual(remove["parentId"] as? Int, base + 3)
        let add = try XCTUnwrap((data["adds"] as? [[String: Any]])?.first)
        XCTAssertTrue(add["nextId"] is NSNull)
        XCTAssertEqual((add["node"] as? [String: Any])?["id"] as? Int, base + 5)
    }

    func testEachDocumentGetsANewBlock() throws {
        let remapper = WebViewReplayRemapper(channelId: iframeId)
        let events = remapper.translate(try parse("[\(pageSnapshot),\(pageSnapshot)]"), receivedAt: 0)
        guard case .document(let first) = events[0].kind, case .document(let second) = events[1].kind else { return XCTFail() }
        XCTAssertEqual(second - first, WebViewReplayRemapper.idsPerDocument)
    }

    func testDropsWhatCannotBelongToTheNativeStream() throws {
        let remapper = WebViewReplayRemapper(channelId: iframeId)
        let orphan = #"{"type":3,"timestamp":1,"data":{"source":0,"adds":[],"removes":[],"texts":[],"attributes":[]}}"#
        XCTAssertTrue(remapper.translate(try parse("[\(orphan)]"), receivedAt: 0).isEmpty, "No document yet")

        let meta = #"{"type":4,"timestamp":1,"data":{"href":"https://x","width":1,"height":1}}"#
        let resize = #"{"type":3,"timestamp":2,"data":{"source":4,"width":1,"height":1}}"#
        let mouse = #"{"type":3,"timestamp":3,"data":{"source":2,"type":1,"id":3,"x":1,"y":2}}"#
        let translated = remapper.translate(try parse("[\(meta),\(pageSnapshot),\(resize),\(mouse)]"), receivedAt: 0)
        XCTAssertEqual(translated.count, 2, "Meta and viewport resize would resize the whole player")
        XCTAssertEqual(translated[1].kind, .incremental(changesState: false))

        remapper.reset()
        XCTAssertTrue(remapper.translate(try parse("[\(mouse)]"), receivedAt: 0).isEmpty, "Reset forgets the document")
    }

    func testIdPastTheBlockIsDropped() throws {
        let remapper = WebViewReplayRemapper(channelId: iframeId)
        let huge = #"{"type":3,"timestamp":1,"data":{"source":2,"type":1,"id":\#(WebViewReplayRemapper.idsPerDocument),"x":1,"y":2}}"#
        XCTAssertEqual(remapper.translate(try parse("[\(pageSnapshot),\(huge)]"), receivedAt: 0).count, 1)
    }

    // MARK: - Chunk builder

    private func document(at timestamp: TimeInterval, root: Int = 1_000_000_001, tag: String = "doc") -> WebViewReplayEvent {
        return WebViewReplayEvent(channelId: iframeId, timestamp: timestamp, kind: .document(rootId: root),
                                  json: Data(#"{"type":0,"id":\#(root),"tag":"\#(tag)","childNodes":[]}"#.utf8))
    }

    private func mutation(at timestamp: TimeInterval, tag: String = "m") -> WebViewReplayEvent {
        return WebViewReplayEvent(channelId: iframeId, timestamp: timestamp, kind: .incremental(changesState: true),
                                  json: Data(#"{"source":0,"tag":"\#(tag)","adds":[],"removes":[],"texts":[],"attributes":[]}"#.utf8))
    }

    private func mouse(at timestamp: TimeInterval) -> WebViewReplayEvent {
        return WebViewReplayEvent(channelId: iframeId, timestamp: timestamp, kind: .incremental(changesState: false),
                                  json: Data(#"{"source":2,"type":1,"id":1000000002,"x":1,"y":1}"#.utf8))
    }

    private func mount(_ timestamp: TimeInterval, _ mounted: Bool = true) -> WebViewMountTransition {
        return WebViewMountTransition(timestamp: timestamp, channelId: iframeId, mounted: mounted)
    }

    /// "graft(tag)" ("graft(blank)" for the empty document a navigation leaves), "remove", or the
    /// incremental's tag, each "@timestamp".
    private func describe(_ events: [WebViewReplayOutputEvent]) throws -> [String] {
        return try events.map { event in
            let object = try json(event.json)
            XCTAssertEqual(object["type"] as? Int, 3, "Everything is an ordinary incremental event")
            let data = try XCTUnwrap(object["data"] as? [String: Any])
            let at = Int(event.timestamp)
            XCTAssertEqual(object["timestamp"] as? Int, at)
            if let add = (data["adds"] as? [[String: Any]])?.first, let node = add["node"] as? [String: Any], node["type"] as? Int == 0 {
                XCTAssertEqual(add["parentId"] as? Int, iframeId, "Attached under the WebView's iframe")
                return "graft(\(node["tag"] as? String ?? "blank"))@\(at)"
            }
            if let remove = (data["removes"] as? [[String: Any]])?.first, remove["parentId"] as? Int == iframeId {
                return "remove@\(at)"
            }
            return "\(data["tag"] as? String ?? "mouse")@\(at)"
        }
    }

    func testDocumentIsAttachedOnceTheIframeExists() throws {
        var states = [Int: WebViewReplayChannelState]()
        let out = WebViewReplayChunkBuilder.build(pending: [document(at: 1100), mutation(at: 1200, tag: "a")],
                                                  mountTransitions: [mount(1000)],
                                                  chunkStart: 1000,
                                                  states: &states)
        XCTAssertEqual(try describe(out), ["graft(doc)@1100", "a@1200"])
        XCTAssertEqual(states[iframeId]?.backlog.count, 1)
    }

    func testCarriedDocumentAndBacklogReattachAtChunkStart() throws {
        var states = [Int: WebViewReplayChannelState]()
        var carried = WebViewReplayChannelState()
        carried.startDocument(document(at: 10))
        carried.record(mutation(at: 20, tag: "a"))
        carried.record(mouse(at: 25))
        states[iframeId] = carried

        // Captured during the previous chunk, arrived in this one.
        let late = mutation(at: 50, tag: "late")
        let out = WebViewReplayChunkBuilder.build(pending: [late],
                                                  mountTransitions: [mount(1000)],
                                                  chunkStart: 1000,
                                                  states: &states)

        XCTAssertEqual(try describe(out), ["graft(doc)@1000", "a@1000", "late@1000"],
                       "The document, then the state-changing history since it, then late events -- cursor moves are not replayed")
        XCTAssertEqual(out[0].graftGroup, out[1].graftGroup)
        XCTAssertNil(out[2].graftGroup)
    }

    func testIframeRebuiltMidChunkGetsDocumentReattached() throws {
        var states = [Int: WebViewReplayChannelState]()
        let out = WebViewReplayChunkBuilder.build(pending: [document(at: 1100), mutation(at: 1200, tag: "a"), mutation(at: 1600, tag: "b")],
                                                  mountTransitions: [mount(1000), mount(1500)],
                                                  chunkStart: 1000,
                                                  states: &states)
        XCTAssertEqual(try describe(out), ["graft(doc)@1100", "a@1200", "graft(doc)@1500", "a@1500", "b@1600"])
    }

    func testNewDocumentReplacesTheAttachedOne() throws {
        var states = [Int: WebViewReplayChannelState]()
        let out = WebViewReplayChunkBuilder.build(pending: [document(at: 1100, tag: "old"), mutation(at: 1200, tag: "a"),
                                                            document(at: 1300, root: 1_010_000_001, tag: "new")],
                                                  mountTransitions: [mount(1000)],
                                                  chunkStart: 1000,
                                                  states: &states)
        XCTAssertEqual(try describe(out), ["graft(old)@1100", "a@1200", "graft(new)@1300"],
                       "The graft replaces the old document; an iframe's document can't be removed from it")
        XCTAssertTrue(states[iframeId]?.backlog.isEmpty ?? false, "A new document starts a new history")
    }

    func testDocumentAtTheSameMomentAsARebuildIsAttachedOnce() throws {
        var states = [Int: WebViewReplayChannelState]()
        var carried = WebViewReplayChannelState()
        carried.startDocument(document(at: 10, tag: "old"))
        states[iframeId] = carried

        let out = WebViewReplayChunkBuilder.build(pending: [document(at: 1000, root: 1_010_000_001, tag: "new")],
                                                  mountTransitions: [mount(1000)],
                                                  chunkStart: 1000,
                                                  states: &states)
        XCTAssertEqual(try describe(out), ["graft(new)@1000"])
    }

    func testNothingIsEmittedWhileTheIframeIsOffScreen() throws {
        var states = [Int: WebViewReplayChannelState]()
        let out = WebViewReplayChunkBuilder.build(pending: [document(at: 1100), mutation(at: 1200, tag: "a"), mutation(at: 1700, tag: "b")],
                                                  mountTransitions: [mount(1000, false), mount(1500)],
                                                  chunkStart: 1000,
                                                  states: &states)
        XCTAssertEqual(try describe(out), ["graft(doc)@1500", "a@1500", "b@1700"],
                       "Held while unmounted, then attached with its history when the iframe comes back")
    }

    private func navigation(at timestamp: TimeInterval) -> WebViewReplayEvent {
        return WebViewReplayEvent(channelId: iframeId, timestamp: timestamp, kind: .navigation,
                                  json: WebViewReplayEvents.blankDocument(base: 1_020_000_000))
    }

    func testNavigationTakesTheOldPageOffImmediately() throws {
        var states = [Int: WebViewReplayChannelState]()
        let out = WebViewReplayChunkBuilder.build(pending: [document(at: 1100, tag: "old"), mutation(at: 1200, tag: "a"),
                                                            navigation(at: 1300),
                                                            mutation(at: 1350, tag: "orphan"),
                                                            document(at: 1500, root: 1_010_000_001, tag: "new")],
                                                  mountTransitions: [mount(1000), mount(1400)],
                                                  chunkStart: 1000,
                                                  states: &states)
        XCTAssertEqual(try describe(out), ["graft(old)@1100", "a@1200", "graft(blank)@1300", "graft(new)@1500"],
                       "Replaced by a blank page at the navigation; not re-attached by the rebuild at 1400; the new page attaches when it arrives")
    }

    func testNavigationForgetsTheCarriedDocument() {
        var states = [Int: WebViewReplayChannelState]()
        var carried = WebViewReplayChannelState()
        carried.startDocument(document(at: 10))
        states[iframeId] = carried

        let out = WebViewReplayChunkBuilder.build(pending: [navigation(at: 1000)],
                                                  mountTransitions: [mount(1000)],
                                                  chunkStart: 1000,
                                                  states: &states)
        XCTAssertTrue(out.isEmpty, "The old page is never attached to a chunk that starts after it left")
        XCTAssertNil(states[iframeId])
    }

    func testNavigationCarriesABlankDocumentInItsOwnBlock() throws {
        let remapper = WebViewReplayRemapper(channelId: iframeId)
        guard case .document(let oldRoot) = try XCTUnwrap(remapper.translate(try parse("[\(pageSnapshot)]"), receivedAt: 0).first).kind else {
            return XCTFail("expected a document")
        }
        let navigation = remapper.navigation(at: 2000)
        guard case .document(let newRoot) = try XCTUnwrap(remapper.translate(try parse("[\(pageSnapshot)]"), receivedAt: 0).first).kind else {
            return XCTFail("expected a document")
        }

        let blank = try json(navigation.json)
        XCTAssertEqual(blank["type"] as? Int, 0, "A document node, grafted in the old page's place")
        let blankRoot = try XCTUnwrap(blank["id"] as? Int)
        XCTAssertEqual(blankRoot / WebViewReplayRemapper.idsPerDocument, oldRoot / WebViewReplayRemapper.idsPerDocument + 1,
                       "Its own block, after the old page's")
        XCTAssertEqual(newRoot / WebViewReplayRemapper.idsPerDocument, blankRoot / WebViewReplayRemapper.idsPerDocument + 1,
                       "and before the new page's")
        let html = try XCTUnwrap((blank["childNodes"] as? [[String: Any]])?.last)
        XCTAssertEqual((html["childNodes"] as? [[String: Any]])?.map { $0["tagName"] as? String }, ["head", "body"])
    }

    func testCaptureLatencyIsReportedOncePerNavigation() throws {
        let remapper = WebViewReplayRemapper(channelId: iframeId)
        _ = remapper.navigation(at: 400)
        let document = try XCTUnwrap(remapper.translate(try parse("[\(pageSnapshot)]"), receivedAt: 0).first)
        XCTAssertEqual(remapper.takeCaptureLatency(for: document), 600)
        XCTAssertNil(remapper.takeCaptureLatency(for: document))
    }

    func testBacklogOverflowFallsBackToTheBareDocument() {
        var state = WebViewReplayChannelState()
        state.startDocument(document(at: 1))
        let big = WebViewReplayEvent(channelId: iframeId, timestamp: 2, kind: .incremental(changesState: true),
                                     json: Data(repeating: 0x20, count: WebViewReplayChannelState.maxBacklogBytes + 1))
        state.record(big)
        XCTAssertTrue(state.backlogOverflowed)
        XCTAssertTrue(state.backlog.isEmpty)
        state.record(mutation(at: 3))
        XCTAssertTrue(state.backlog.isEmpty, "Nothing more is recorded until the next document")
        state.startDocument(document(at: 4))
        XCTAssertFalse(state.backlogOverflowed)
    }

    // MARK: - Payload budget

    private func pieces(_ events: [WebViewReplayOutputEvent], native: Int = 0) -> [WebViewReplayPayloadBudget.Piece] {
        var result = [WebViewReplayPayloadBudget.Piece]()
        for index in 0..<native {
            result.append(.init(event: .native(makeMetaAnyRRWebEvent(timestamp: TimeInterval(index))), json: Data(repeating: 0x20, count: 10)))
        }
        for event in events {
            result.append(.init(event: .webView(event), json: event.json))
        }
        return result
    }

    private func output(group: Int?, size: Int, at timestamp: TimeInterval = 1) -> WebViewReplayOutputEvent {
        return WebViewReplayOutputEvent(channelId: iframeId, timestamp: timestamp, json: Data(repeating: 0x20, count: size), graftGroup: group)
    }

    func testBudgetLeavesChunkUnderLimitAlone() {
        let input = pieces([output(group: 1, size: 50)], native: 2)
        let result = WebViewReplayPayloadBudget.enforce(input, limit: 1_000_000) { $0.count }
        XCTAssertEqual(result.shedCount, 0)
        XCTAssertEqual(result.pieces.count, input.count)
    }

    func testBudgetShedsWholeSupersededAttachmentFirst() {
        let input = pieces([output(group: 1, size: 400), output(group: 1, size: 100), output(group: nil, size: 5),
                            output(group: 2, size: 50)], native: 2)
        let total = WebViewReplayPayloadBudget.joinedJSON(input).count

        let result = WebViewReplayPayloadBudget.enforce(input, limit: total - 1) { $0.count }

        XCTAssertEqual(result.shedCount, 1)
        XCTAssertEqual(result.pieces.compactMap { $0.event.webViewEvent?.graftGroup }, [2],
                       "Group 1's graft and backlog go together; the final attachment survives")
        XCTAssertEqual(result.pieces.count, 4, "Native events and ungrouped WebView events are never shed")
    }

    func testBudgetWithNothingToShedReturnsInput() {
        let input = pieces([output(group: nil, size: 50)], native: 1)
        let result = WebViewReplayPayloadBudget.enforce(input, limit: 1) { $0.count }
        XCTAssertEqual(result.shedCount, 0)
        XCTAssertEqual(result.pieces.count, input.count)
    }

    // MARK: - Standalone recorder (pages with their own browser agent)

    func testRecorderSourceMustMatchItsPinnedHash() {
        XCTAssertNil(WebViewReplayRecorder.verifiedSource(Data("var rrwebRecord=function(){}();".utf8)),
                     "Anything but the reviewed build is refused")
    }

    func testBootstrapKeepsTheRecorderOffThePageAndMasksByDefault() {
        let script = WebViewReplayRecorder.bootstrapScript(source: "var rrwebRecord=function(o){}", handlerName: "nrWebViewReplay")
        XCTAssertTrue(script.hasPrefix("(function(){"), "The recorder's var is scoped to our function, not window")
        XCTAssertTrue(script.contains("var module={exports:{}};var exports=module.exports;var define=undefined;"),
                      "The UMD bundle hands its export back to us, not to window or a page's AMD loader")
        XCTAssertTrue(script.contains("return module.exports.record;"))
        XCTAssertTrue(script.contains("window.__nrWvRecording"), "Guarded against starting twice in one document")
        XCTAssertTrue(script.contains("maskAllInputs:true"))
        XCTAssertTrue(script.contains("maskTextSelector:'*'"))
        XCTAssertTrue(script.contains("blockSelector:'[data-nr-block],img,picture'"), "Images masked, as native images are by default")
        XCTAssertFalse(script.contains("NREUM"), "The page's own agent is left alone")
        XCTAssertTrue(script.contains("kind:'events'"), "Same bridge message as the observation agent")
    }

    func testBootstrapFollowsTheMaskingConfiguration() {
        let unmasked = WebViewReplayRecorder.bootstrapScript(source: "", handlerName: "nrWebViewReplay",
                                                             masking: .init(maskText: false, maskInputs: false, maskImages: false))
        XCTAssertTrue(unmasked.contains("maskAllInputs:false"))
        XCTAssertTrue(unmasked.contains("maskTextSelector:null"), "No text masked")
        XCTAssertTrue(unmasked.contains("blockSelector:'[data-nr-block]'"), "Images recorded; explicitly blocked elements still are not")
        XCTAssertTrue(unmasked.contains("blockClass:'nr-block'"))
        XCTAssertTrue(unmasked.contains("maskTextClass:'nr-mask'"), "A page's own mask class is still honored")

        let imagesOnly = WebViewReplayRecorder.bootstrapScript(source: "", handlerName: "nrWebViewReplay",
                                                               masking: .init(maskText: false, maskInputs: false, maskImages: true))
        XCTAssertTrue(imagesOnly.contains("blockSelector:'[data-nr-block],img,picture'"), "Masked images replay as placeholders")
        XCTAssertTrue(imagesOnly.contains("maskTextSelector:null"))
    }

    func testMaskingResolvesLikeNativeViews() {
        XCTAssertEqual(WebViewReplayMasking(isMasked: nil, maskApplicationText: false, maskUserInputText: false, maskAllImages: false),
                       .init(maskText: false, maskInputs: false, maskImages: false), "Custom mode with nothing masked")
        XCTAssertEqual(WebViewReplayMasking(isMasked: nil, maskApplicationText: nil, maskUserInputText: nil, maskAllImages: nil),
                       .all, "Masked until there is a configuration")
        XCTAssertEqual(WebViewReplayMasking(isMasked: nil, maskApplicationText: false, maskUserInputText: true, maskAllImages: false),
                       .init(maskText: false, maskInputs: true, maskImages: false))
        XCTAssertEqual(WebViewReplayMasking(isMasked: true, maskApplicationText: false, maskUserInputText: false, maskAllImages: false),
                       .all, "A mask rule on the WebView wins")
        XCTAssertEqual(WebViewReplayMasking(isMasked: false, maskApplicationText: true, maskUserInputText: true, maskAllImages: true),
                       .init(maskText: false, maskInputs: false, maskImages: false), "So does an unmask rule")
    }

    func testRecorderFlushesDocumentsImmediatelyAndTakesSnapshotsOnRequest() {
        let script = WebViewReplayRecorder.bootstrapScript(source: "var rrwebRecord=function(o){}", handlerName: "nrWebViewReplay")
        XCTAssertTrue(script.contains("if(event.type===2){setTimeout(flush,0);}"))
        XCTAssertTrue(script.contains("setInterval(flush,1000)"))
        XCTAssertTrue(script.contains("window.__nrWvTakeFullSnapshot=function(){try{rrwebRecord.takeFullSnapshot(true);}catch(e){}}"))
        XCTAssertTrue(WebViewReplayRecorder.takeFullSnapshotScript.contains("window.__nrWvTakeFullSnapshot&&"),
                      "A no-op on pages without the recorder")
    }

    func testInjectionDecidesImmediatelyUnlessAnAgentMayBeLoading() {
        let script = NRMAWebViewReplayBridge.injectionScript
        XCTAssertTrue(script.contains("if(window.NREUM||window.newrelic||document.readyState==='complete'||!agentMayBeLoading()){start();}"))
        XCTAssertTrue(script.contains("js-agent[.]newrelic[.]com"))
        XCTAssertTrue(script.contains("indexOf('NREUM')"))
    }

    func testPagesAreRecordedByTheStandaloneRecorderByDefault() {
        XCTAssertEqual(NRMAWebViewReplayBridge.captureStrategy, .standaloneRecorder,
                       "The recorder snapshots immediately and on request; the observation agent can do neither")
    }

    func testObservationAgentYieldsWhenNoSnapshotArrives() {
        let script = NRMAWebViewReplayBridge.injectionScript
        XCTAssertTrue(script.contains("setTimeout(function(){if(!documentSeen){yieldTo('\(NRMAWebViewReplayBridge.noSnapshotReason)');}},\(NRMAWebViewReplayBridge.snapshotWatchdogMs))"),
                      "A resumed agent session harvests mutations only; the page must not wait on it")
        XCTAssertTrue(script.contains("if(yielded){return passThrough(h);}"),
                      "Once the recorder takes over, the agent's payloads are not forwarded as well")
    }

    func testInjectionWaitsForThePageToSettleAndYieldsToALateAgent() {
        let script = NRMAWebViewReplayBridge.injectionScript
        XCTAssertTrue(script.contains("addEventListener('load'"),
                      "The agent check waits for load: async and tag-manager snippets arrive after document end")
        XCTAssertTrue(script.contains("setTimeout(start,\(NRMAWebViewReplayBridge.agentLoadBackstopMs))"),
                      "A page whose load never fires still starts")
        XCTAssertTrue(script.contains("licenseKey!=='\(NRMAWebViewReplayBridge.observationLicenseKey)'"),
                      "A page agent that arrives after ours is detected by its real license key")
        XCTAssertTrue(script.contains("reason:'\(NRMAWebViewReplayBridge.existingAgentReason)'"))
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
        let webView = [output(group: 1, size: 1, at: 1000), output(group: nil, size: 1, at: 1500), output(group: 2, size: 1, at: 2000)]

        let chunk = manager.mergeReplayChunk(frames: frames, touches: touches, webViewEvents: webView)

        let kinds: [String] = chunk.map { event in
            switch event {
            case .native(let native): return "n\(native.base.type.rawValue)@\(Int(native.base.timestamp))"
            case .webView(let webViewEvent): return "w@\(Int(webViewEvent.timestamp))"
            }
        }
        XCTAssertEqual(kinds, ["n4@1000", "n2@1000", "w@1000", "n3@1500", "w@1500", "n2@2000", "w@2000"])
    }

    func testEncodedChunkIsValidJSONWithTimestampsFromEnds() throws {
        let manager = makeManager()
        let graft = WebViewReplayOutputEvent(channelId: iframeId, timestamp: 3000,
                                             json: WebViewReplayEvents.graft(iframeId: iframeId, document: document(at: 3000).json, timestamp: 3000),
                                             graftGroup: 1)
        let chunk = manager.mergeReplayChunk(frames: [makeMetaAnyRRWebEvent(timestamp: 1000), makeFullSnapshotAnyRRWebEvent(timestamp: 1000)],
                                             touches: [],
                                             webViewEvents: [graft])

        let encoded = try XCTUnwrap(manager.encodeReplayChunk(chunk))
        XCTAssertEqual(encoded.firstTimestamp, 1000)
        XCTAssertEqual(encoded.lastTimestamp, 3000)

        let pieces = chunk.map { event -> WebViewReplayPayloadBudget.Piece in
            switch event {
            case .native(let native): return .init(event: event, json: try! JSONEncoder().encode(native))
            case .webView(let webViewEvent): return .init(event: event, json: webViewEvent.json)
            }
        }
        let array = try XCTUnwrap(try JSONSerialization.jsonObject(with: WebViewReplayPayloadBudget.joinedJSON(pieces)) as? [[String: Any]])
        XCTAssertEqual(array.map { $0["type"] as? Int }, [4, 2, 3])
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
