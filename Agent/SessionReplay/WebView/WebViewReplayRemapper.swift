//
//  WebViewReplayRemapper.swift
//  Agent_iOS
//
//  Copyright © 2026 New Relic. All rights reserved.
//

import Foundation

#if os(iOS) || os(tvOS)

/// One of a WebView's rrweb events, already translated into the native replay's ID space.
///
/// The WebView's DOM is merged into the native replay as a single tree on the stock rrweb replayer,
/// the same way rrweb itself records an iframe: the WebView is an `<iframe>` node in the native
/// snapshot, and the page's document is attached to it through a mutation `adds` entry whose
/// `parentId` is that iframe (see `WebViewReplayChunkBuilder`). For that to work the page's node IDs
/// must not collide with native ones, so every ID is moved into a block reserved for that document.
struct WebViewReplayEvent {
    enum Kind: Equatable {
        /// A FullSnapshot. `json` is the remapped `type: 0` document node; `rootId` is its native ID.
        case document(rootId: Int)
        /// An IncrementalSnapshot. `json` is the remapped `data` member.
        /// `changesState` is false for events that only animate the cursor (mouse, touch, selection),
        /// which never need replaying onto a re-attached document.
        case incremental(changesState: Bool)
        /// The WebView committed a new document: the previous one is gone from the screen. Lets the
        /// replay drop it at that moment instead of showing a stale page until the new one's
        /// FullSnapshot arrives. `json` is empty.
        case navigation
    }

    let channelId: Int
    /// ms. The page's own clock: Date.now() and the native Date() read the same wall clock.
    var timestamp: TimeInterval
    let kind: Kind
    let json: Data

    var isDocument: Bool {
        if case .document = kind { return true }
        return false
    }
}

/// Translates a WebView's rrweb events into native-ID `WebViewReplayEvent`s. One per WebView, used
/// only on the bridge's serial parse queue: IDs depend on which document each event belongs to, so
/// events must be translated in arrival order.
final class WebViewReplayRemapper {

    /// Page IDs start here. Native IDs come from `IDGenerator`, a counter from 0 that never gets near
    /// this.
    static let idOffset = 1_000_000_000

    /// IDs reserved per document. rrweb assigns a page's IDs from a counter starting at 1, so a page
    /// would need ten million nodes over its lifetime to overflow its block. An event carrying an ID
    /// past that is dropped rather than allowed to alias the next document's nodes.
    static let idsPerDocument = 10_000_000

    private static let generationLock = NSLock()
    private static var nextGeneration = 0

    /// Every WebView document gets its own block, globally, so two WebViews -- or two generations of
    /// one page -- can never collide. Resolved as `idOffset + generation * idsPerDocument + pageId`.
    static func allocateBase() -> Int {
        generationLock.lock()
        defer { generationLock.unlock() }
        let base = idOffset + nextGeneration * idsPerDocument
        nextGeneration += 1
        return base
    }

    /// Every rrweb field that holds a node ID, across every incremental source. Generic over key
    /// names because enumerating each source's layout is a maintenance trap.
    private static let idKeys: Set<String> = ["id", "parentId", "nextId", "previousId", "rootId", "start", "end"]

    /// rrweb `IncrementalSource` values that only move the cursor or selection.
    private static let cursorSources: Set<Int> = [1, 2, 6, 11, 12, 14]

    /// `IncrementalSource.ViewportResize`. Carries no node IDs, but a replayer applies its width and
    /// height to the *main* viewport, which would rescale the whole native replay to the WebView.
    private static let viewportResizeSource = 4

    let channelId: Int

    /// The current document's ID block, or nil before its first FullSnapshot.
    private var base: Int?

    /// When the current document was committed, until its first FullSnapshot arrives. Diagnostics:
    /// how long a page takes to reach the replay is what capture speed means to a user.
    private(set) var navigationAt: TimeInterval?

    init(channelId: Int) {
        self.channelId = channelId
    }

    /// A new document is loading. Events until its FullSnapshot have nothing to apply to.
    func reset() {
        base = nil
    }

    /// A new document was committed at `timestamp` (ms).
    func navigation(at timestamp: TimeInterval) -> WebViewReplayEvent {
        reset()
        navigationAt = timestamp
        return WebViewReplayEvent(channelId: channelId, timestamp: timestamp, kind: .navigation, json: Data())
    }

    /// ms from the last navigation to `document`, reported once per navigation.
    func takeCaptureLatency(for document: WebViewReplayEvent) -> TimeInterval? {
        guard document.isDocument, let at = navigationAt else { return nil }
        navigationAt = nil
        return document.timestamp - at
    }

    /// - Parameter receivedAt: ms timestamp for any event that carries no readable timestamp
    func translate(_ events: [[String: Any]], receivedAt: TimeInterval) -> [WebViewReplayEvent] {
        return events.compactMap { translate($0, receivedAt: receivedAt) }
    }

    func translate(_ event: [String: Any], receivedAt: TimeInterval) -> WebViewReplayEvent? {
        guard let type = (event["type"] as? NSNumber)?.intValue,
              let data = event["data"] as? [String: Any] else {
            return nil
        }
        var timestamp = (event["timestamp"] as? NSNumber)?.doubleValue ?? 0
        if timestamp <= 0 {
            timestamp = receivedAt
        }

        switch type {
        case RRWebEventType.fullSnapshot.rawValue:
            guard let node = data["node"] as? [String: Any] else { return nil }
            // A FullSnapshot starts a new ID generation: rrweb may renumber on a checkout, and a new
            // page certainly does.
            let base = Self.allocateBase()
            self.base = base
            guard let remapped = Self.remap(node, base: base) as? [String: Any],
                  let rootId = (remapped["id"] as? NSNumber)?.intValue,
                  let json = Self.serialize(remapped) else {
                self.base = nil
                return nil
            }
            return WebViewReplayEvent(channelId: channelId, timestamp: timestamp, kind: .document(rootId: rootId), json: json)

        case RRWebEventType.incrementalSnapshot.rawValue:
            guard let base = base else { return nil }
            let source = (data["source"] as? NSNumber)?.intValue ?? -1
            if source == Self.viewportResizeSource {
                return nil
            }
            guard let remapped = Self.remap(data, base: base),
                  let json = Self.serialize(remapped) else {
                return nil
            }
            return WebViewReplayEvent(channelId: channelId,
                                      timestamp: timestamp,
                                      kind: .incremental(changesState: !Self.cursorSources.contains(source)),
                                      json: json)

        default:
            // Meta would resize the whole player to the WebView's viewport; the WebView's size comes
            // from its native frame instead, and its URL from the iframe's data-nr-src. Custom, plugin
            // and load events have no meaning in the native stream.
            return nil
        }
    }

    // MARK: - Remapping

    private struct UnmappableID: Error {}

    /// Returns `value` with every node ID moved into `base`'s block, or nil if some ID does not fit.
    static func remap(_ value: Any, base: Int) -> Any? {
        return try? remapValue(value, base: base)
    }

    private static func remapValue(_ value: Any, base: Int) throws -> Any {
        if let dictionary = value as? [String: Any] {
            var out = [String: Any](minimumCapacity: dictionary.count)
            for (key, child) in dictionary {
                // The browser agent's pre-serialized copy of the whole event; nothing reads it.
                if key.hasPrefix("__") {
                    continue
                }
                if key == "attributes", child is [String: Any] {
                    // LOAD-BEARING EXCLUSION. An element node's `attributes` is a map of HTML
                    // attributes, where `id` is a CSS id string, not a node ID. A mutation's
                    // `attributes` is instead an ARRAY of {id, attributes} records whose `id` IS a node
                    // ID -- that shape is walked, and its inner maps land back here.
                    out[key] = child
                } else if key == "styleIds", let ids = child as? [Any] {
                    out[key] = try ids.map { try mapId($0, base: base) }
                } else if idKeys.contains(key) {
                    out[key] = try mapId(child, base: base)
                } else {
                    out[key] = try remapValue(child, base: base)
                }
            }
            return out
        }
        if let array = value as? [Any] {
            return try array.map { try remapValue($0, base: base) }
        }
        return value
    }

    private static func mapId(_ value: Any, base: Int) throws -> Any {
        // `nextId` is legitimately null, and a non-numeric value under an ID key is not an ID.
        guard let number = value as? NSNumber, !isBoolean(number) else {
            return value
        }
        let raw = number.doubleValue
        guard raw == raw.rounded(), raw >= 0 else {
            // Fractional values are not IDs; negative ones are rrweb sentinels (-1 none, -2 ignored).
            return value
        }
        let pageId = Int(raw)
        guard pageId < idsPerDocument else {
            throw UnmappableID()
        }
        return base + pageId
    }

    private static func isBoolean(_ number: NSNumber) -> Bool {
        return CFGetTypeID(number) == CFBooleanGetTypeID()
    }

    private static func serialize(_ object: Any) -> Data? {
        guard JSONSerialization.isValidJSONObject(object) else { return nil }
        return try? JSONSerialization.data(withJSONObject: object, options: [.withoutEscapingSlashes])
    }
}

/// Pulls the rrweb event array out of a browser agent replay payload.
enum WebViewReplayPayloadParser {

    /// Tolerates the shapes the payload has been observed to take, because which one arrives depends
    /// on the agent build: the events array itself, a payload object with a `body` member holding that
    /// array, or either of those as JSON *text*.
    static func extractEvents(from text: String) -> [[String: Any]]? {
        guard !text.isEmpty, let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
            return nil
        }
        return extractEvents(fromObject: object)
    }

    private static func extractEvents(fromObject object: Any) -> [[String: Any]]? {
        if let array = object as? [Any] {
            return array.compactMap { $0 as? [String: Any] }
        }
        if let dictionary = object as? [String: Any] {
            if let body = dictionary["body"] {
                return extractEvents(fromObject: body)
            }
            // `body` is the harvester's convention and the only shape observed so far, but it is the
            // agent's choice rather than ours. Look for the one member that is an array of
            // rrweb-shaped events. Top level only, on purpose.
            for value in dictionary.values where looksLikeEventArray(value) {
                return extractEvents(fromObject: value)
            }
            return nil
        }
        if let string = object as? String {
            // A stringified array or payload. Parsing a string's contents cannot yield that same
            // string, so this cannot recurse forever.
            return extractEvents(from: string)
        }
        return nil
    }

    private static func looksLikeEventArray(_ value: Any) -> Bool {
        guard let array = value as? [Any], let first = array.first as? [String: Any] else {
            return false
        }
        return first["type"] is NSNumber
    }
}

#endif
