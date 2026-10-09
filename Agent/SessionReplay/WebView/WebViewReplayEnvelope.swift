//
//  WebViewReplayEnvelope.swift
//  Agent_iOS
//
//  Copyright © 2026 New Relic. All rights reserved.
//

import Foundation

#if os(iOS) || os(tvOS)

/// Must match the replay plugin's `PLUGIN_NAME`.
let WebViewReplayPluginName = "nr-webview-replay"

/// rrweb `EventType.Plugin`.
let WebViewReplayPluginEventType = 6

/// One of a WebView's own rrweb events, wrapped as an `EventType.Plugin` event for the native stream:
///
///     {"type":6,"timestamp":<ts>,"data":{"plugin":"nr-webview-replay",
///      "payload":{"channelId":"<id>","innerEvent":{...}}}}
///
/// The inner event crosses into the native stream untouched -- same node IDs, same timestamps. The
/// replay plugin hosts a nested `Replayer` with its own `Mirror` per channel, so the WebView's ID space
/// never has to mean anything in the native one.
///
/// The inner event is held as serialized JSON rather than as a Codable tree. A real page's document
/// runs to hundreds of kilobytes, and it is re-emitted into every chunk (see
/// `WebViewReplayChunkBuilder`), so keeping the bytes and splicing them is far cheaper than
/// re-encoding a tree each time.
struct WebViewReplayEnvelope {
    /// Identifies which WebView this belongs to; matches the mount point's `data-nr-webview-channel`.
    let channelId: Int
    /// The envelope's timestamp, in ms. Normally the inner event's own; re-stamped on re-emission.
    var timestamp: TimeInterval
    let innerType: Int
    let innerJSON: Data
    /// True for a copy of an earlier document placed after a native full snapshot.
    var isReemit: Bool = false

    var isDocument: Bool { innerType == RRWebEventType.fullSnapshot.rawValue }
    var isMeta: Bool { innerType == RRWebEventType.meta.rawValue }

    /// A copy placed at `timestamp`. The inner event keeps its original timestamp -- it is a true
    /// statement about when that document was captured. Only the envelope moves, so the harvest sort
    /// places it where the chunk needs it.
    func reemitted(at timestamp: TimeInterval) -> WebViewReplayEnvelope {
        var copy = self
        copy.timestamp = timestamp
        copy.isReemit = true
        return copy
    }

    func encoded() -> Data {
        let prefix = "{\"type\":\(WebViewReplayPluginEventType),\"timestamp\":\(Int64(timestamp.rounded()))," +
            "\"data\":{\"plugin\":\"\(WebViewReplayPluginName)\",\"payload\":{\"channelId\":\"\(channelId)\",\"innerEvent\":"
        var data = Data()
        data.reserveCapacity(prefix.utf8.count + innerJSON.count + 3)
        data.append(contentsOf: prefix.utf8)
        data.append(innerJSON)
        data.append(contentsOf: "}}}".utf8)
        return data
    }
}

/// Pulls a WebView's rrweb events out of a browser agent replay payload and wraps each one.
enum WebViewReplayPayloadParser {

    /// - Parameters:
    ///   - body: plain-text JSON from the bridge
    ///   - channelId: the WebView the payload came from
    ///   - receivedAt: ms timestamp used for any event that carries no readable timestamp
    static func envelopes(fromBridgeBody body: String, channelId: Int, receivedAt: TimeInterval) -> [WebViewReplayEnvelope] {
        guard let events = extractEvents(from: body) else {
            return []
        }
        return events.compactMap { envelope(for: $0, channelId: channelId, receivedAt: receivedAt) }
    }

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

    static func envelope(for event: [String: Any], channelId: Int, receivedAt: TimeInterval) -> WebViewReplayEnvelope? {
        var event = event
        stripInternalMembers(&event)

        guard let type = (event["type"] as? NSNumber)?.intValue,
              JSONSerialization.isValidJSONObject(event),
              let innerJSON = try? JSONSerialization.data(withJSONObject: event, options: [.withoutEscapingSlashes]) else {
            return nil
        }

        // Both sides stamp from the same wall clock in ms (Date.now() in the page), so the inner
        // event's own timestamp is meaningful. Using delivery time instead would collapse a whole
        // browser harvest interval of activity onto a single instant.
        var timestamp = (event["timestamp"] as? NSNumber)?.doubleValue ?? 0
        if timestamp <= 0 {
            timestamp = receivedAt
        }

        return WebViewReplayEnvelope(channelId: channelId, timestamp: timestamp, innerType: type, innerJSON: innerJSON)
    }

    /// Removes the browser agent's internal bookkeeping members, chiefly `__serialized`: a string
    /// holding the agent's own pre-serialized copy of the entire event. Forwarding it roughly doubles
    /// every WebView event (measured ~47% of the payload) and no replayer reads it.
    static func stripInternalMembers(_ event: inout [String: Any]) {
        for key in event.keys where key.hasPrefix("__") {
            event.removeValue(forKey: key)
        }
    }
}

#endif
