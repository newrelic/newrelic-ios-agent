//
//  WebViewReplayChunkBuilder.swift
//  Agent_iOS
//
//  Copyright © 2026 New Relic. All rights reserved.
//

import Foundation

#if os(iOS) || os(tvOS)

/// A moment at which a WebView's `<iframe>` node was built into, or taken out of, the native replay.
///
/// The iframe is rebuilt empty by every native full snapshot (the replayer resets its mirror) and by
/// every mutation that re-adds it, so each of these is a point where the page's document has to be
/// attached again.
struct WebViewMountTransition: Equatable {
    let timestamp: TimeInterval
    let channelId: Int
    let mounted: Bool
}

/// What a WebView needs carried from one chunk to the next: chunks are uploaded and replayed
/// independently, so each one has to attach the page's document afresh.
struct WebViewReplayChannelState {
    /// The page's most recent document.
    var document: WebViewReplayEvent?
    /// State-changing events since `document`, replayed after every re-attachment. Without them a
    /// re-attached page shows the DOM as it was at its snapshot, and later mutations reference nodes
    /// that were added since and no longer exist.
    var backlog: [WebViewReplayEvent] = []
    var backlogBytes = 0
    /// Set when the backlog outgrew its bound. Re-attachments then show the document as snapshotted
    /// until the page's next FullSnapshot.
    var backlogOverflowed = false

    /// Bounds the replayed history per page.
    static let maxBacklogBytes = 2 * 1024 * 1024

    mutating func startDocument(_ event: WebViewReplayEvent) {
        document = event
        backlog.removeAll()
        backlogBytes = 0
        backlogOverflowed = false
    }

    /// The page navigated away: its document is gone and must not be attached again.
    mutating func endDocument() {
        document = nil
        backlog.removeAll()
        backlogBytes = 0
        backlogOverflowed = false
    }

    mutating func record(_ event: WebViewReplayEvent) {
        guard document != nil, !backlogOverflowed,
              case .incremental(let changesState) = event.kind, changesState else {
            return
        }
        backlog.append(event)
        backlogBytes += event.json.count
        if backlogBytes > Self.maxBacklogBytes {
            backlog.removeAll()
            backlogBytes = 0
            backlogOverflowed = true
        }
    }
}

/// One event of the chunk, ready to serialize. All of them are ordinary rrweb IncrementalSnapshot
/// mutations and interactions in native IDs; the replayer needs nothing beyond stock iframe support.
struct WebViewReplayOutputEvent {
    let channelId: Int
    let timestamp: TimeInterval
    let json: Data
    /// Events that attach one copy of a document: the graft and the backlog replayed onto it. Kept in
    /// the same upload when a chunk is split, since the backlog means nothing without its document.
    let graftGroup: Int?
}

/// Lays out one harvest chunk's WebView events against the native stream.
///
/// iOS rebuilds the native events from raw frames at harvest time, so every point where a WebView's
/// iframe is (re)built is known exactly, and the document can be attached right after each one --
/// no ordering gates or wait buffers needed.
enum WebViewReplayChunkBuilder {
    
    /// How soon after the iframe is (re)built a new document must land for the carried one to be
    /// skipped. The snapshot requested after every harvest typically lands within a second of the
    /// next chunk's start; until it does, the WebView shows empty rather than costing a second copy.
    static let freshDocumentWindowMs: TimeInterval = 2000

    /// - Parameters:
    ///   - pending: translated WebView events received since the last harvest, in arrival order
    ///   - mountTransitions: when each WebView's iframe was built or removed in this chunk's native events
    ///   - chunkStart: the chunk's leading Meta timestamp. Events are clamped to it: browser batches
    ///     lag, so events captured during the previous chunk arrive in this one, and must not sort
    ///     ahead of the Meta the player needs first.
    ///   - states: per-WebView state carried between chunks; updated here
    /// - Returns: the chunk's WebView events, sorted by timestamp
    static func build(pending: [WebViewReplayEvent],
                      mountTransitions: [WebViewMountTransition],
                      chunkStart: TimeInterval,
                      states: inout [Int: WebViewReplayChannelState]) -> [WebViewReplayOutputEvent] {
        var eventsByChannel = [Int: [WebViewReplayEvent]]()
        for var event in pending {
            event.timestamp = max(event.timestamp, chunkStart)
            eventsByChannel[event.channelId, default: []].append(event)
        }
        var transitionsByChannel = [Int: [WebViewMountTransition]]()
        for transition in mountTransitions {
            transitionsByChannel[transition.channelId, default: []].append(transition)
        }

        let channels = Set(eventsByChannel.keys).union(transitionsByChannel.keys).union(states.keys).sorted()
        var graftGroup = 0
        var output = [WebViewReplayOutputEvent]()
        for channelId in channels {
            var state = states[channelId] ?? WebViewReplayChannelState()
            output.append(contentsOf: buildChannel(
                channelId: channelId,
                events: (eventsByChannel[channelId] ?? []).nrStableSorted { $0.timestamp < $1.timestamp },
                transitions: (transitionsByChannel[channelId] ?? []).nrStableSorted { $0.timestamp < $1.timestamp },
                state: &state,
                graftGroup: &graftGroup))
            states[channelId] = state.document == nil ? nil : state
        }

        // Each channel's run is already in timestamp order, so a stable sort interleaves channels
        // without disturbing any channel's internal order.
        return output.nrStableSorted { $0.timestamp < $1.timestamp }
    }

    private static func buildChannel(channelId: Int,
                                     events: [WebViewReplayEvent],
                                     transitions: [WebViewMountTransition],
                                     state: inout WebViewReplayChannelState,
                                     graftGroup: inout Int) -> [WebViewReplayOutputEvent] {
        var output = [WebViewReplayOutputEvent]()
        var isMounted = false
        /// The native ID of the document currently attached to the iframe in the replay, if any.
        var attachedRootId: Int?
        /// The iframe was just (re)built empty and needs the document attached.
        var pendingAttachAt: TimeInterval?

        func attach(_ document: WebViewReplayEvent, at timestamp: TimeInterval, withBacklog: Bool) {
            guard case .document(let rootId) = document.kind else { return }
            graftGroup += 1
            output.append(.init(channelId: channelId, timestamp: timestamp,
                                json: WebViewReplayEvents.graft(iframeId: channelId, document: document.json, timestamp: timestamp),
                                graftGroup: graftGroup))
            if withBacklog {
                for event in state.backlog {
                    output.append(.init(channelId: channelId, timestamp: timestamp,
                                        json: WebViewReplayEvents.incremental(data: event.json, timestamp: timestamp),
                                        graftGroup: graftGroup))
                }
            }
            attachedRootId = rootId
        }

        /// Attaches lazily, so a new document arriving at the same moment the iframe is rebuilt is
        /// attached once rather than twice.
        func flushPendingAttach() {
            guard let at = pendingAttachAt else { return }
            pendingAttachAt = nil
            if isMounted, let document = state.document {
                attach(document, at: at, withBacklog: true)
            }
        }
        
        // For each event, when the next document arrives, if one does before the page navigates away.
        var nextDocumentAt = [TimeInterval?](repeating: nil, count: events.count)
        var upcoming: TimeInterval?
        for index in events.indices.reversed() {
            switch events[index].kind {
            case .document: upcoming = events[index].timestamp
            case .navigation: upcoming = nil
            case .incremental: break
            }
            nextDocumentAt[index] = upcoming
        }

        var eventIndex = 0
        var transitionIndex = 0
        while eventIndex < events.count || transitionIndex < transitions.count {
            // At equal timestamps the native change goes first: it sorts ahead of WebView events in
            // the final chunk, so an iframe built at T is in place for a graft stamped T.
            let takeTransition = transitionIndex < transitions.count &&
                (eventIndex >= events.count || transitions[transitionIndex].timestamp <= events[eventIndex].timestamp)

            if takeTransition {
                let transition = transitions[transitionIndex]
                transitionIndex += 1
                flushPendingAttach()
                isMounted = transition.mounted
                attachedRootId = nil        // rebuilt empty, or gone
                pendingAttachAt = transition.mounted ? transition.timestamp : nil
                continue
            }

            let event = events[eventIndex]
            eventIndex += 1

            switch event.kind {
            case .document:
                state.startDocument(event)
                guard isMounted else { continue }
                // The fresh iframe gets the new document directly. On a navigation or checkout the
                // graft itself replaces the previous document: an iframe's document is not a DOM child
                // of the iframe, so it cannot be removed, only replaced.
                pendingAttachAt = nil
                attach(event, at: event.timestamp, withBacklog: false)

            case .navigation:
                state.endDocument()
                pendingAttachAt = nil
                if isMounted, attachedRootId != nil {
                    // The old page leaves the replay when it left the screen, rather than lingering
                    // until the new page's snapshot replaces it: an empty document takes its place.
                    output.append(.init(channelId: channelId, timestamp: event.timestamp,
                                        json: WebViewReplayEvents.graft(iframeId: channelId, document: event.json, timestamp: event.timestamp),
                                        graftGroup: nil))
                }
                attachedRootId = nil

            case .incremental:
                // A new document lands moments after the iframe was rebuilt -- typically the one
                  // requested at the last harvest. It already reflects this change, so attaching the
                  // carried copy just to apply it would send the page twice.
                  if isMounted, let rebuiltAt = pendingAttachAt, let documentAt = nextDocumentAt[eventIndex - 1],
                     documentAt - rebuiltAt <= Self.freshDocumentWindowMs,
                     transitionIndex >= transitions.count || transitions[transitionIndex].timestamp > documentAt {
                      continue
                  }
                // Attach first: the backlog replayed onto the document must not already contain this
                // event, which is emitted right after it.
                if isMounted {
                    flushPendingAttach()
                }
                state.record(event)
                guard isMounted else { continue }
                if attachedRootId != nil {
                    output.append(.init(channelId: channelId, timestamp: event.timestamp,
                                        json: WebViewReplayEvents.incremental(data: event.json, timestamp: event.timestamp),
                                        graftGroup: nil))
                }
            }
        }
        flushPendingAttach()

        return output
    }
}

/// The rrweb events the merge emits, spliced from already-serialized parts: a page's document runs to
/// hundreds of kilobytes and is re-attached into every chunk, so it is kept as bytes rather than
/// re-encoded each time.
enum WebViewReplayEvents {

    /// Attaches a document node to the WebView's iframe: the same single-add mutation rrweb records
    /// for an iframe's content. It replaces whatever document the iframe had. Every list is present,
    /// even when empty: replayers index into all four.
    static func graft(iframeId: Int, document: Data, timestamp: TimeInterval) -> Data {
        var json = Data(("{\"type\":\(RRWebEventType.incrementalSnapshot.rawValue),\"timestamp\":\(Int64(timestamp.rounded()))," +
                         "\"data\":{\"source\":0,\"texts\":[],\"attributes\":[],\"removes\":[]," +
                         "\"adds\":[{\"parentId\":\(iframeId),\"nextId\":null,\"node\":").utf8)
        json.append(document)
        json.append(contentsOf: "}]}}".utf8)
        return json
    }

    /// A document with an empty body, grafted in place of a page that navigated away. Its IDs are the
    /// first of `base`'s block, laid out as rrweb numbers a page (document, doctype, html, head, body).
    static func blankDocument(base: Int) -> Data {
        return Data(("{\"type\":0,\"id\":\(base + 1),\"childNodes\":[" +
                     "{\"type\":1,\"id\":\(base + 2),\"name\":\"html\",\"publicId\":\"\",\"systemId\":\"\"}," +
                     "{\"type\":2,\"id\":\(base + 3),\"tagName\":\"html\",\"attributes\":{},\"childNodes\":[" +
                     "{\"type\":2,\"id\":\(base + 4),\"tagName\":\"head\",\"attributes\":{},\"childNodes\":[]}," +
                     "{\"type\":2,\"id\":\(base + 5),\"tagName\":\"body\",\"attributes\":{},\"childNodes\":[]}]}]}").utf8)
    }

    /// An IncrementalSnapshot around an already-remapped `data` member, stamped `timestamp`.
    static func incremental(data: Data, timestamp: TimeInterval) -> Data {
        var json = Data("{\"type\":\(RRWebEventType.incrementalSnapshot.rawValue),\"timestamp\":\(Int64(timestamp.rounded())),\"data\":".utf8)
        json.append(data)
        json.append(UInt8(ascii: "}"))
        return json
    }
}

/// One event in a harvest chunk: a native event, or a WebView event carried alongside them.
enum ReplayChunkEvent {
    case native(AnyRRWebEvent)
    case webView(WebViewReplayOutputEvent)

    var timestamp: TimeInterval {
        switch self {
        case .native(let event): return event.base.timestamp
        case .webView(let event): return event.timestamp
        }
    }

    var webViewEvent: WebViewReplayOutputEvent? {
        if case .webView(let event) = self {
            return event
        }
        return nil
    }
}

extension Array {
    /// A sort that keeps equal elements in their original order. `sort` makes no stability guarantee,
    /// and the chunk relies on it: a document must stay ahead of same-timestamp events that depend on it.
    func nrStableSorted(by areInIncreasingOrder: (Element, Element) -> Bool) -> [Element] {
        return enumerated()
            .sorted { lhs, rhs in
                if areInIncreasingOrder(lhs.element, rhs.element) { return true }
                if areInIncreasingOrder(rhs.element, lhs.element) { return false }
                return lhs.offset < rhs.offset
            }
            .map { $0.element }
    }
}

#endif
