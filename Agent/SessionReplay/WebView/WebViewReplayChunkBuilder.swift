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
    /// Events that attach one copy of a document: the graft and the backlog replayed onto it. Shed
    /// together, since the backlog means nothing without its document.
    let graftGroup: Int?
}

/// Lays out one harvest chunk's WebView events against the native stream.
///
/// iOS rebuilds the native events from raw frames at harvest time, so every point where a WebView's
/// iframe is (re)built is known exactly, and the document can be attached right after each one --
/// no ordering gates or wait buffers needed.
enum WebViewReplayChunkBuilder {

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
                if pendingAttachAt != nil {
                    pendingAttachAt = nil       // the fresh iframe gets the new document directly
                } else if let previousRoot = attachedRootId {
                    // Navigation or checkout: tear the previous document off first, so two generations
                    // of a page never coexist under one iframe.
                    output.append(.init(channelId: channelId, timestamp: event.timestamp,
                                        json: WebViewReplayEvents.removal(iframeId: channelId, rootId: previousRoot, timestamp: event.timestamp),
                                        graftGroup: nil))
                }
                attach(event, at: event.timestamp, withBacklog: false)

            case .navigation:
                state.endDocument()
                pendingAttachAt = nil
                if isMounted, let previousRoot = attachedRootId {
                    // The old page leaves the replay when it left the screen, rather than lingering
                    // until the new page's snapshot replaces it.
                    output.append(.init(channelId: channelId, timestamp: event.timestamp,
                                        json: WebViewReplayEvents.removal(iframeId: channelId, rootId: previousRoot, timestamp: event.timestamp),
                                        graftGroup: nil))
                }
                attachedRootId = nil

            case .incremental:
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
    /// for an iframe's content.
    static func graft(iframeId: Int, document: Data, timestamp: TimeInterval) -> Data {
        return mutation(timestamp: timestamp,
                        removes: "",
                        addsPrefix: "{\"parentId\":\(iframeId),\"nextId\":null,\"node\":",
                        node: document,
                        addsSuffix: "}")
    }

    static func removal(iframeId: Int, rootId: Int, timestamp: TimeInterval) -> Data {
        return mutation(timestamp: timestamp,
                        removes: "{\"parentId\":\(iframeId),\"id\":\(rootId)}",
                        addsPrefix: "", node: nil, addsSuffix: "")
    }

    /// An IncrementalSnapshot around an already-remapped `data` member, stamped `timestamp`.
    static func incremental(data: Data, timestamp: TimeInterval) -> Data {
        var json = Data("{\"type\":\(RRWebEventType.incrementalSnapshot.rawValue),\"timestamp\":\(Int64(timestamp.rounded())),\"data\":".utf8)
        json.append(data)
        json.append(UInt8(ascii: "}"))
        return json
    }

    /// Every list present, even when empty: replayers index into all four.
    private static func mutation(timestamp: TimeInterval, removes: String, addsPrefix: String, node: Data?, addsSuffix: String) -> Data {
        var json = Data(("{\"type\":\(RRWebEventType.incrementalSnapshot.rawValue),\"timestamp\":\(Int64(timestamp.rounded()))," +
                         "\"data\":{\"source\":0,\"texts\":[],\"attributes\":[],\"removes\":[\(removes)],\"adds\":[\(addsPrefix)").utf8)
        if let node = node {
            json.append(node)
        }
        json.append(contentsOf: "\(addsSuffix)]}}".utf8)
        return json
    }
}

/// One event in a harvest chunk that carries WebView events alongside native ones.
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

/// Keeps a chunk under the upload size cap by dropping attached WebView documents.
///
/// Without this the reporter rejects an oversized chunk *whole*, native events included, so a single
/// heavy page would cost a full harvest of native replay. Shedding a document instead leaves that
/// WebView's iframe empty until the next attachment while the native replay survives.
enum WebViewReplayPayloadBudget {

    struct Piece {
        let event: ReplayChunkEvent
        let json: Data
    }

    /// - Parameters:
    ///   - limit: the compressed-size cap the reporter enforces
    ///   - compressedLength: returns the compressed size of a payload, or nil if it can't be measured
    /// - Returns: the pieces to send, and how many document attachments were shed
    static func enforce(_ pieces: [Piece], limit: Int, compressedLength: (Data) -> Int?) -> (pieces: [Piece], shedCount: Int) {
        let json = joinedJSON(pieces)
        guard let compressed = compressedLength(json), compressed > limit, json.count > 0 else {
            return (pieces, 0)
        }

        // Derive an uncompressed budget from this chunk's own measured ratio: replay payloads compress
        // anywhere from 10% to 41%, so a fixed assumption would shed too eagerly or not enough. 5%
        // headroom absorbs the ratio drifting as content is removed.
        let ratio = Double(compressed) / Double(json.count)
        let budget = Int((Double(limit) / ratio) * 0.95)

        var groupIndices = [Int: [Int]]()
        var groupBytes = [Int: Int]()
        var lastGroupByChannel = [Int: Int]()
        for (index, piece) in pieces.enumerated() {
            guard let event = piece.event.webViewEvent, let group = event.graftGroup else { continue }
            groupIndices[group, default: []].append(index)
            groupBytes[group, default: 0] += piece.json.count + 1   // + its separating comma
            lastGroupByChannel[event.channelId] = group
        }
        guard !groupIndices.isEmpty else {
            return (pieces, 0)
        }
        let finalGroups = Set(lastGroupByChannel.values)

        // Superseded attachments go first: each channel's last one is what the end of the chunk
        // actually shows. Within each class, largest first, so the fewest are lost.
        let candidates = groupIndices.keys.sorted { lhs, rhs in
            let lhsFinal = finalGroups.contains(lhs)
            let rhsFinal = finalGroups.contains(rhs)
            if lhsFinal != rhsFinal {
                return !lhsFinal
            }
            if groupBytes[lhs] != groupBytes[rhs] {
                return groupBytes[lhs, default: 0] > groupBytes[rhs, default: 0]
            }
            return lhs < rhs
        }

        var total = json.count
        var shed = Set<Int>()
        var shedGroups = 0
        for group in candidates {
            if total <= budget {
                break
            }
            total -= groupBytes[group, default: 0]
            shed.formUnion(groupIndices[group] ?? [])
            shedGroups += 1
        }

        let kept = pieces.enumerated().filter { !shed.contains($0.offset) }.map { $0.element }
        return (kept, shedGroups)
    }

    static func joinedJSON(_ pieces: [Piece]) -> Data {
        var data = Data()
        data.reserveCapacity(pieces.reduce(2) { $0 + $1.json.count + 1 })
        data.append(UInt8(ascii: "["))
        for (index, piece) in pieces.enumerated() {
            if index > 0 {
                data.append(UInt8(ascii: ","))
            }
            data.append(piece.json)
        }
        data.append(UInt8(ascii: "]"))
        return data
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
