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

    func testFreshDocumentLandingRightAfterChunkStartReplacesCarriedCopy() throws {
        var states = [Int: WebViewReplayChannelState]()
        var carried = WebViewReplayChannelState()
        carried.startDocument(document(at: 10, tag: "old"))
        carried.record(mutation(at: 20, tag: "a"))
        states[iframeId] = carried

        // Late changes clamped to the chunk start, then the snapshot requested at the last harvest.
        let out = WebViewReplayChunkBuilder.build(pending: [mutation(at: 50, tag: "late"),
                                                            document(at: 1100, root: 1_010_000_001, tag: "fresh"),
                                                            mutation(at: 1200, tag: "b")],
                                                  mountTransitions: [mount(1000)],
                                                  chunkStart: 1000,
                                                  states: &states)

        XCTAssertEqual(try describe(out), ["graft(fresh)@1100", "b@1200"], "The page is sent once")
    }

    func testCarriedCopyStaysWhenTheNextDocumentIsFarOff() throws {
        var states = [Int: WebViewReplayChannelState]()
        var carried = WebViewReplayChannelState()
        carried.startDocument(document(at: 10, tag: "old"))
        states[iframeId] = carried

        let out = WebViewReplayChunkBuilder.build(pending: [mutation(at: 1100, tag: "a"),
                                                            document(at: 9000, root: 1_010_000_001, tag: "later")],
                                                  mountTransitions: [mount(1000)],
                                                  chunkStart: 1000,
                                                  states: &states)

        XCTAssertEqual(try describe(out), ["graft(old)@1000", "a@1100", "graft(later)@9000"])
    }

    func testCarriedCopyStaysWhenTheIframeIsRebuiltBeforeTheFreshDocument() throws {
        var states = [Int: WebViewReplayChannelState]()
        var carried = WebViewReplayChannelState()
        carried.startDocument(document(at: 10, tag: "old"))
        states[iframeId] = carried

        // Unmounted before the fresh document lands: it would attach to nothing.
        let out = WebViewReplayChunkBuilder.build(pending: [mutation(at: 1050, tag: "a"),
                                                            document(at: 1500, root: 1_010_000_001, tag: "fresh")],
                                                  mountTransitions: [mount(1000), mount(1200, false)],
                                                  chunkStart: 1000,
                                                  states: &states)

        XCTAssertEqual(try describe(out), ["graft(old)@1000", "a@1050"])
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

    // MARK: - Chunk output

    private func output(group: Int?, size: Int, at timestamp: TimeInterval = 1) -> WebViewReplayOutputEvent {
        return WebViewReplayOutputEvent(channelId: iframeId, timestamp: timestamp, json: Data(repeating: 0x20, count: size), graftGroup: group)
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

        let payloads = try XCTUnwrap(manager.encodeReplayChunk(chunk))
        XCTAssertEqual(payloads.count, 1)
        let encoded = try XCTUnwrap(payloads.first)
        XCTAssertEqual(encoded.firstTimestamp, 1000)
        XCTAssertEqual(encoded.lastTimestamp, 3000)

        let pieces = chunk.map { event -> ReplayPayloadSplitter.Piece in
            switch event {
            case .native(let native): return .init(json: try! JSONEncoder().encode(native), timestamp: event.timestamp)
            case .webView(let webViewEvent): return .init(json: webViewEvent.json, timestamp: event.timestamp)
            }
        }
        let array = try XCTUnwrap(try JSONSerialization.jsonObject(with: ReplayPayloadSplitter.joinedJSON(pieces)) as? [[String: Any]])
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

/// Moves in the native diff: a WebView's `<iframe>` re-added by a mutation loses the page document
/// attached to it in the replay, so the diff must not re-add it when it did not actually move.
class NativeDiffMoveTests: XCTestCase {

    private func node(_ id: Int, parent: Int, webView: Bool = false) -> DiffNode {
        return DiffNode(id: id, parentId: parent, isWebView: webView)
    }

    /// What Heckel's matching yields for unique IDs: each new element's index in `old`, if present.
    private func matches(_ old: [DiffNode], _ new: [DiffNode]) -> [Int?] {
        var indexById = [Int: Int]()
        for (index, element) in old.enumerated() { indexById[element.id] = index }
        return new.map { indexById[$0.id] }
    }

    private func movedIds(_ old: [DiffNode], _ new: [DiffNode]) -> Set<Int> {
        return Set(movedElements(old: old, new: new, matches: matches(old, new)).map { new[$0].id })
    }

    func testViewMovingAcrossWebViewDoesNotReaddIt() {
        // Root 1 with children A(2), W(3), B(4); B moves to the front.
        let old = [node(1, parent: 0), node(2, parent: 1), node(3, parent: 1, webView: true), node(4, parent: 1)]
        let new = [old[0], old[3], old[1], old[2]]

        XCTAssertEqual(movedIds(old, new), [4], "Only the view that moved is re-added")
        XCTAssertEqual(Set(legacyMovedElements(oldCount: old.count, matches: matches(old, new)).map { new[$0].id }), [4, 2, 3],
                       "The position check re-added everything it passed, the WebView included")
    }

    func testWebViewStaysWhenItTradesPlacesWithASibling() {
        let old = [node(1, parent: 0), node(2, parent: 1), node(3, parent: 1, webView: true)]
        let new = [old[0], old[2], old[1]]

        XCTAssertEqual(movedIds(old, new), [2])
    }

    func testReparentedViewIsReaddedWithItsSubtree() {
        // B(3) with child B1(4) moves under A(2).
        let old = [node(1, parent: 0), node(2, parent: 1), node(3, parent: 1), node(4, parent: 3)]
        let new = [node(1, parent: 0), node(2, parent: 1), node(3, parent: 2), node(4, parent: 3)]

        XCTAssertEqual(movedIds(old, new), [3, 4], "B1 kept its parent but comes back only if re-added")
    }

    func testWebViewUnderAMovedParentIsReadded() {
        let old = [node(1, parent: 0), node(2, parent: 1), node(3, parent: 1), node(4, parent: 3, webView: true)]
        let new = [node(1, parent: 0), node(2, parent: 1), node(3, parent: 2), node(4, parent: 3, webView: true)]

        XCTAssertEqual(movedIds(old, new), [3, 4])
    }

    func testInsertionsAndRemovalsAloneProduceNoMoves() {
        let old = [node(1, parent: 0), node(2, parent: 1), node(3, parent: 1, webView: true), node(4, parent: 1)]
        // A new sibling ahead of the WebView, one removed after it: positions shift, order does not.
        let new = [old[0], node(5, parent: 1), old[1], old[2]]

        XCTAssertTrue(movedIds(old, new).isEmpty)
    }

    func testHeaviestIncreasingSubsequenceKeepsTheExpensiveElement() {
        // Old positions in new order: [2, 0, 1]. The longest run is {0, 1}, but position 0 is heavy.
        XCTAssertEqual(heaviestIncreasingSubsequence([2, 0, 1], weights: [100, 1, 1]), [0])
        XCTAssertEqual(heaviestIncreasingSubsequence([2, 0, 1], weights: [1, 1, 1]), [1, 2])
        XCTAssertEqual(longestIncreasingSubsequence([3, 1, 2, 0, 4]).count, 3)
        XCTAssertEqual(heaviestIncreasingSubsequence([2, 0, 1], weights: [100, 1, 1], exactLimit: 2), [1, 2],
                       "Past the limit, the longest run")
    }

    /// Replays a session of random sibling reorders, insertions and removals on a ~300-view screen
    /// with one WebView through both move rules, and reports how often each re-adds the WebView.
    func testReorderSessionReaddsWebViewLessOften() {
        var seed: UInt64 = 0x5EED
        func random(_ n: Int) -> Int {
            seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17
            return Int(seed % UInt64(max(n, 1)))
        }

        var nextId = 1
        var children = [Int: [Int]]()
        var parentOf = [Int: Int]()
        func make(parent: Int?) -> Int {
            let id = nextId; nextId += 1
            children[id] = []
            if let parent = parent { children[parent]!.append(id); parentOf[id] = parent }
            return id
        }
        let root = make(parent: nil)
        let containers = (0..<3).map { _ in make(parent: root) }
        for container in containers {
            for _ in 0..<30 {
                let child = make(parent: container)
                for _ in 0..<random(5) { _ = make(parent: child) }
            }
        }
        let webViewId = make(parent: containers[1])
        children[containers[1]]!.removeLast()
        children[containers[1]]!.insert(webViewId, at: 15)

        // Same traversal as SessionReplayFrameProcessor.flattenTree: a stack, so the last subview first.
        func flatten() -> [DiffNode] {
            var out = [DiffNode]()
            var stack = [root]
            while let id = stack.popLast() {
                out.append(node(id, parent: parentOf[id] ?? 0, webView: id == webViewId))
                stack.append(contentsOf: children[id]!)
            }
            return out
        }

        var legacyWebView = 0, fixedWebView = 0, legacyViews = 0, fixedViews = 0
        var legacyTime = 0.0, fixedTime = 0.0
        let frames = 600
        var previous = flatten()
        for _ in 0..<frames {
            // One change per frame: a reorder within a container (bring to front, reshuffle) twice as
            // often as a view added or removed. Reorders never pick the WebView itself.
            let container = containers[random(containers.count)]
            var siblings = children[container]!
            if random(3) < 2 {
                let candidates = siblings.indices.filter { siblings[$0] != webViewId }
                let moving = siblings.remove(at: candidates[random(candidates.count)])
                siblings.insert(moving, at: random(siblings.count + 1))
            } else if random(2) == 0 {
                let id = nextId; nextId += 1
                children[id] = []; parentOf[id] = container
                siblings.insert(id, at: random(siblings.count + 1))
            } else {
                let leaves = siblings.filter { $0 != webViewId && children[$0]!.isEmpty }
                if !leaves.isEmpty {
                    let gone = leaves[random(leaves.count)]
                    siblings.removeAll { $0 == gone }
                }
            }
            children[container] = siblings
            let current = flatten()
            let matched = matches(previous, current)

            var start = Date()
            let legacy = legacyMovedElements(oldCount: previous.count, matches: matched)
            legacyTime += Date().timeIntervalSince(start)
            start = Date()
            let fixed = movedElements(old: previous, new: current, matches: matched)
            fixedTime += Date().timeIntervalSince(start)

            legacyViews += legacy.count
            fixedViews += fixed.count
            if legacy.contains(where: { current[$0].id == webViewId }) { legacyWebView += 1 }
            if fixed.contains(where: { current[$0].id == webViewId }) { fixedWebView += 1 }
            previous = current
        }

        print("[NR-DIFF] \(frames) frames, \(previous.count) views: frames re-adding the WebView legacy=\(legacyWebView) fixed=\(fixedWebView); " +
              "views re-added legacy=\(legacyViews) fixed=\(fixedViews); " +
              String(format: "move rule ms/frame legacy=%.3f fixed=%.3f", legacyTime * 1000 / Double(frames), fixedTime * 1000 / Double(frames)))
        XCTAssertEqual(fixedWebView, 0, "Reorders around the WebView never move it")
        XCTAssertLessThan(fixedViews, legacyViews)
    }
}

/// The move rule as it was: an element moved if its position in the flattened tree, corrected for
/// insertions and removals ahead of it, changed. Verbatim from the pre-fix generateDiff.
private func legacyMovedElements(oldCount: Int, matches: [Int?]) -> Set<Int> {
    var oldMatched = Array(repeating: false, count: oldCount)
    for case let indexInOld? in matches { oldMatched[indexInOld] = true }
    var deleteOffsets = Array(repeating: 0, count: oldCount)
    var runningOffset = 0
    for index in 0..<oldCount {
        deleteOffsets[index] = runningOffset
        if !oldMatched[index] { runningOffset += 1 }
    }
    runningOffset = 0
    var moved = Set<Int>()
    for (index, match) in matches.enumerated() {
        guard let indexInOld = match else {
            runningOffset += 1
            continue
        }
        if (indexInOld - deleteOffsets[indexInOld] + runningOffset) != index {
            moved.insert(index)
        }
    }
    return moved
}
