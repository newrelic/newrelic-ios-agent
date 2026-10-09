//
//  WebViewReplayChunkBuilder.swift
//  Agent_iOS
//
//  Copyright © 2026 New Relic. All rights reserved.
//

import Foundation

#if os(iOS) || os(tvOS)

/// A WebView's most recent document: the Meta + FullSnapshot pair rrweb emits together.
///
/// The Meta is load-bearing for visibility, not just sizing. A nested `Replayer` is constructed with an
/// empty event array, and rrweb creates its iframe with `display: none`; only `handleResize`, fired by
/// a Meta event, ever sets it visible. A document re-emitted without its Meta builds the whole DOM and
/// renders nothing.
struct WebViewReplayDocument {
    var meta: WebViewReplayEnvelope?
    var full: WebViewReplayEnvelope
}

/// Decides where each WebView's document must be (re-)placed within one harvest chunk.
///
/// Two properties of the payload drive this:
/// - Chunks are uploaded and replayed independently, so the plugin's retained history cannot cross a
///   chunk boundary. A chunk that carries a WebView's mutations but not its document has nothing to
///   mount them onto and renders blank.
/// - A native full snapshot resets the replayer's mirror and rebuilds the tagged mount div, so the
///   player retires the nested replayer attached to the old node and builds a fresh, empty one. The
///   Android POC measured that a chunk replays the WebView only if a document sorts after the *last*
///   native full snapshot in it.
///
/// So the document is re-emitted at the start of each chunk and after every native full snapshot
/// that shows the WebView and that no document already follows -- except when the chunk's first event
/// for that WebView is a fresh document, which would replace a re-emitted copy at once. Unlike Android, which has to infer chunk boundaries from a
/// harvest clock, iOS rebuilds the native events from raw frames at harvest time, so every native full
/// snapshot in the chunk is known exactly.
enum WebViewReplayChunkBuilder {

    /// - Parameters:
    ///   - pending: WebView envelopes received since the last harvest, in arrival order
    ///   - nativeFullSnapshotTimestamps: every native full snapshot in this chunk
    ///   - chunkStart: the chunk's leading Meta timestamp. Envelopes are clamped to it: browser batches
    ///     lag, so events captured during the previous chunk arrive in this one, and must not sort
    ///     ahead of the Meta the player needs first.
    ///   - reemitChannels: channels whose mount point appears in this chunk. nil re-emits for every
    ///     channel with a document. A WebView that is alive but off screen has no mount point to
    ///     rebuild, so re-emitting its document would only cost payload.
    ///   - fullSnapshotChannels: the channels each native full snapshot shows, keyed by its timestamp.
    ///     A full snapshot rebuilds only the mount points it contains, so a WebView that was off screen
    ///     at that moment gets no copy there. nil, or a missing timestamp, treats every channel as shown.
    ///   - documents: each channel's last document, carried in from earlier chunks and updated here
    /// - Returns: the chunk's WebView envelopes, sorted by timestamp
    static func build(pending: [WebViewReplayEnvelope],
                      nativeFullSnapshotTimestamps: [TimeInterval],
                      chunkStart: TimeInterval,
                      reemitChannels: Set<Int>?,
                      fullSnapshotChannels: [TimeInterval: Set<Int>]? = nil,
                      documents: inout [Int: WebViewReplayDocument]) -> [WebViewReplayEnvelope] {
        let fullSnapshots = nativeFullSnapshotTimestamps.sorted()

        var byChannel = [Int: [WebViewReplayEnvelope]]()
        var channelOrder = [Int]()
        for var envelope in pending {
            envelope.timestamp = max(envelope.timestamp, chunkStart)
            if byChannel[envelope.channelId] == nil {
                channelOrder.append(envelope.channelId)
            }
            byChannel[envelope.channelId, default: []].append(envelope)
        }
        for channelId in documents.keys.sorted() where byChannel[channelId] == nil {
            channelOrder.append(channelId)
        }

        var output = [WebViewReplayEnvelope]()
        for channelId in channelOrder {
            let events = (byChannel[channelId] ?? []).nrStableSorted { $0.timestamp < $1.timestamp }
            let shouldReemit = reemitChannels?.contains(channelId) ?? true
            let shownAt = fullSnapshots.filter { fullSnapshotChannels?[$0]?.contains(channelId) ?? true }
            output.append(contentsOf: buildChannel(events: events,
                                                   fullSnapshots: shownAt,
                                                   chunkStart: chunkStart,
                                                   shouldReemit: shouldReemit,
                                                   document: &documents[channelId]))
        }

        // Each channel's run is already in timestamp order, so a stable sort interleaves channels
        // without disturbing any channel's internal order (a document stays ahead of the mutations
        // that depend on it).
        return output.nrStableSorted { $0.timestamp < $1.timestamp }
    }

    private static func buildChannel(events: [WebViewReplayEnvelope],
                                     fullSnapshots: [TimeInterval],
                                     chunkStart: TimeInterval,
                                     shouldReemit: Bool,
                                     document: inout WebViewReplayDocument?) -> [WebViewReplayEnvelope] {
        var output = [WebViewReplayEnvelope]()
        var currentMeta = document?.meta
        var currentFull = document?.full
        var lastDocumentAt: TimeInterval? = nil

        // A fresh document leads this chunk -- e.g. one requested at the last harvest. Anything
        // re-emitted ahead of it would be replaced at once, so the WebView instead stays empty for the
        // moment until it lands, rather than costing a second copy of the document.
        let freshDocumentLeads = events.first.map { $0.isMeta || $0.isDocument } ?? false
        var consumedEvents = 0

        func reemit(at timestamp: TimeInterval) {
            guard shouldReemit, !(freshDocumentLeads && consumedEvents == 0), let full = currentFull else { return }
            if let meta = currentMeta {
                output.append(meta.reemitted(at: timestamp))
            }
            output.append(full.reemitted(at: timestamp))
            lastDocumentAt = timestamp
        }

        // The carried document goes first, so events that arrived late from the previous chunk (now
        // clamped to chunkStart) apply on top of it rather than ahead of it.
        reemit(at: chunkStart)

        var eventIndex = 0
        var snapshotIndex = 0
        while eventIndex < events.count || snapshotIndex < fullSnapshots.count {
            // At equal timestamps WebView events are consumed first: a WebView document stamped at the
            // same ms as a native full snapshot sorts after it in the final chunk (plugin events rank
            // last), so it already satisfies that snapshot.
            let takeEvent = eventIndex < events.count &&
                (snapshotIndex >= fullSnapshots.count || events[eventIndex].timestamp <= fullSnapshots[snapshotIndex])
            if takeEvent {
                let event = events[eventIndex]
                eventIndex += 1
                consumedEvents += 1
                output.append(event)
                if event.isMeta {
                    currentMeta = event
                } else if event.isDocument {
                    currentFull = event
                    lastDocumentAt = event.timestamp
                }
            } else {
                let snapshotAt = fullSnapshots[snapshotIndex]
                snapshotIndex += 1
                if let placed = lastDocumentAt, placed >= snapshotAt {
                    continue
                }
                reemit(at: snapshotAt)
            }
        }

        document = currentFull.map { WebViewReplayDocument(meta: currentMeta, full: $0) }
        return output
    }
}

/// One event in a harvest chunk that carries WebView events alongside native ones.
enum ReplayChunkEvent {
    case native(AnyRRWebEvent)
    case webView(WebViewReplayEnvelope)

    var timestamp: TimeInterval {
        switch self {
        case .native(let event): return event.base.timestamp
        case .webView(let envelope): return envelope.timestamp
        }
    }

    var webViewEnvelope: WebViewReplayEnvelope? {
        if case .webView(let envelope) = self {
            return envelope
        }
        return nil
    }
}

/// Keeps a chunk under the upload size cap by dropping WebView documents.
///
/// Without this the reporter rejects an oversized chunk *whole*, native events included, so a single
/// heavy WebView document would cost a full harvest of native replay. Shedding documents instead
/// degrades the WebView to empty until its next document while the native replay survives.
enum WebViewReplayPayloadBudget {

    struct Piece {
        let event: ReplayChunkEvent
        let json: Data
    }

    /// - Parameters:
    ///   - limit: the compressed-size cap the reporter enforces
    ///   - compressedLength: returns the compressed size of a payload, or nil if it can't be measured
    /// - Returns: the pieces to send, and how many documents were shed
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

        var lastDocumentIndexByChannel = [Int: Int]()
        var candidates = [Int]()
        for (index, piece) in pieces.enumerated() {
            if let envelope = piece.event.webViewEnvelope, envelope.isDocument {
                candidates.append(index)
                lastDocumentIndexByChannel[envelope.channelId] = index
            }
        }
        guard !candidates.isEmpty else {
            return (pieces, 0)
        }
        let finalDocuments = Set(lastDocumentIndexByChannel.values)

        // Superseded documents go first: each channel's last document is the one the end of the chunk
        // actually renders. Within each group, largest first, so the fewest documents are lost.
        candidates.sort { lhs, rhs in
            let lhsFinal = finalDocuments.contains(lhs)
            let rhsFinal = finalDocuments.contains(rhs)
            if lhsFinal != rhsFinal {
                return !lhsFinal
            }
            if pieces[lhs].json.count != pieces[rhs].json.count {
                return pieces[lhs].json.count > pieces[rhs].json.count
            }
            return lhs < rhs
        }

        var total = json.count
        var shed = Set<Int>()
        for index in candidates {
            if total <= budget {
                break
            }
            total -= pieces[index].json.count + 1   // + its separating comma
            shed.insert(index)
        }

        let kept = pieces.enumerated().filter { !shed.contains($0.offset) }.map { $0.element }
        return (kept, shed.count)
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
