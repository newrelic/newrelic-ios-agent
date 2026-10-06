// Deterministic synthetic rrweb workload shaped like the browser agent's session_replay harvests:
// a Meta + FullSnapshot document, then batches of incremental events, every event carrying the
// agent's `__serialized` pre-serialized copy of itself.

import Foundation

struct RNG: RandomNumberGenerator {
    var s: UInt64
    init(seed: UInt64) { s = seed &* 0x9E3779B97F4A7C15 | 1 }
    mutating func next() -> UInt64 { s ^= s << 13; s ^= s >> 7; s ^= s << 17; return s }
    mutating func int(_ n: Int) -> Int { Int(next() % UInt64(max(n, 1))) }
    mutating func range(_ lo: Int, _ hi: Int) -> Int { lo + int(hi - lo + 1) }
    mutating func chance(_ p: Double) -> Bool { Double(next() % 10_000) / 10_000 < p }
}

enum PageSize: String, CaseIterable {
    case small, medium, large
    var nodes: Int {
        switch self {
        case .small: return 400
        case .medium: return 4_000
        case .large: return 16_000
        }
    }
}

private let words: [String] = {
    var rng = RNG(seed: 7)
    let syll = ["ka", "lo", "mi", "ne", "ru", "sa", "to", "vi", "be", "da", "fo", "gu", "ha", "je", "pi", "qu", "ze", "xo"]
    return (0..<400).map { _ in (0..<rng.range(1, 4)).map { _ in syll[rng.int(syll.count)] }.joined() }
}()

final class PageGenerator {
    var rng: RNG
    var nextId = 1
    var elementIds = [Int]()
    var textIds = [Int]()

    init(seed: UInt64) { rng = RNG(seed: seed) }

    func id() -> Int { defer { nextId += 1 }; return nextId }

    func sentence(_ lo: Int, _ hi: Int) -> String {
        (0..<rng.range(lo, hi)).map { _ in words[rng.int(words.count)] }.joined(separator: " ")
    }

    func hex(_ n: Int) -> String { String((0..<n).map { _ in "0123456789abcdef".randomElement(using: &rng)! }) }

    func className() -> String {
        let utilities = ["flex", "items-center", "p-2", "mt-4", "text-sm", "grid", "rounded", "shadow", "hidden", "md:block"]
        var parts = ["css-\(hex(6))"]
        for _ in 0..<rng.range(0, 3) { parts.append(utilities[rng.int(utilities.count)]) }
        return parts.joined(separator: " ")
    }

    func textNode() -> [String: Any] {
        let nodeId = id()
        textIds.append(nodeId)
        return ["type": 3, "textContent": sentence(2, 12), "id": nodeId]
    }

    func element(depth: Int, remaining: inout Int) -> [String: Any] {
        let tags = ["div", "div", "div", "span", "a", "p", "li", "ul", "section", "img", "button"]
        let tag = tags[rng.int(tags.count)]
        let nodeId = id()
        elementIds.append(nodeId)
        remaining -= 1
        var attributes: [String: Any] = ["class": className()]
        if tag == "a" { attributes["href"] = "https://example.com/\(words[rng.int(words.count)])/\(hex(8))" }
        if tag == "img" { attributes["src"] = "https://cdn.example.com/img/\(hex(16)).webp"; attributes["alt"] = sentence(1, 4) }
        if rng.chance(0.2) { attributes["style"] = "display:flex;margin:0 \(rng.range(0, 24))px;color:#\(hex(6))" }
        if rng.chance(0.1) { attributes["data-testid"] = "\(words[rng.int(words.count)])-\(rng.int(100))" }

        var children = [[String: Any]]()
        if tag != "img", depth < 9, remaining > 0 {
            for _ in 0..<rng.range(1, 5) where remaining > 0 {
                if depth > 2 && rng.chance(0.45) {
                    children.append(textNode())
                    remaining -= 1
                } else {
                    children.append(element(depth: depth + 1, remaining: &remaining))
                }
            }
        }
        return ["type": 2, "tagName": tag, "attributes": attributes, "childNodes": children, "id": nodeId]
    }

    func stylesheet(bytes: Int) -> String {
        var css = ""
        while css.utf8.count < bytes {
            css += ".css-\(hex(6)){display:flex;padding:\(rng.range(0, 16))px \(rng.range(0, 16))px;color:#\(hex(6));font-size:\(rng.range(10, 24))px}"
        }
        return css
    }

    /// rrweb document node with `nodes` nodes in the body plus a head with inlined stylesheets.
    func document(nodes: Int) -> [String: Any] {
        let docId = id()
        let doctype: [String: Any] = ["type": 1, "name": "html", "publicId": "", "systemId": "", "id": id()]
        let htmlId = id()
        let headId = id()
        var head = [[String: Any]]()
        head.append(["type": 2, "tagName": "meta", "attributes": ["charset": "utf-8"], "childNodes": [], "id": id()])
        for _ in 0..<3 {
            head.append(["type": 2, "tagName": "style", "attributes": ["_cssText": stylesheet(bytes: nodes * 20)], "childNodes": [], "id": id()])
        }
        let bodyId = id()
        elementIds.append(bodyId)
        var remaining = nodes
        var bodyChildren = [[String: Any]]()
        while remaining > 0 { bodyChildren.append(element(depth: 0, remaining: &remaining)) }
        let html: [String: Any] = ["type": 2, "tagName": "html", "attributes": ["lang": "en"], "id": htmlId, "childNodes": [
            ["type": 2, "tagName": "head", "attributes": [:] as [String: Any], "childNodes": head, "id": headId],
            ["type": 2, "tagName": "body", "attributes": ["class": className()], "childNodes": bodyChildren, "id": bodyId],
        ]]
        return ["type": 0, "childNodes": [doctype, html], "id": docId]
    }

    func smallSubtree() -> [String: Any] {
        var remaining = rng.range(2, 8)
        return element(depth: 7, remaining: &remaining)
    }

    func liveElement() -> Int { elementIds[rng.int(elementIds.count)] }
    func liveText() -> Int { textIds.isEmpty ? liveElement() : textIds[rng.int(textIds.count)] }

    /// The incremental events of `seconds` of an interactive page, starting at `start` ms.
    func incrementals(start: TimeInterval, seconds: Double) -> [[String: Any]] {
        let perSecond = 14.0
        let count = Int(perSecond * seconds)
        var events = [[String: Any]]()
        for i in 0..<count {
            let ts = start + Double(i) * (seconds * 1000 / Double(count))
            let roll = rng.int(100)
            let data: [String: Any]
            switch roll {
            case 0..<43:   // MouseMove / TouchMove
                let positions = (0..<5).map { k -> [String: Any] in
                    ["x": rng.range(0, 390), "y": rng.range(0, 844), "id": liveElement(), "timeOffset": -k * 50]
                }
                data = ["source": rng.chance(0.5) ? 1 : 6, "positions": positions]
            case 43..<64:  // Scroll
                data = ["source": 3, "id": liveElement(), "x": 0, "y": rng.range(0, 6000)]
            case 64..<86:  // Mutation
                var adds = [[String: Any]]()
                for _ in 0..<rng.range(1, 3) {
                    adds.append(["parentId": liveElement(), "nextId": NSNull(), "node": smallSubtree()])
                }
                let removes = (0..<rng.range(0, 2)).map { _ in ["parentId": liveElement(), "id": liveElement()] }
                let texts = (0..<rng.range(0, 3)).map { _ in ["id": liveText(), "value": sentence(1, 6)] as [String: Any] }
                let attributes = (0..<rng.range(0, 3)).map { _ in ["id": liveElement(), "attributes": ["class": className()]] as [String: Any] }
                data = ["source": 0, "adds": adds, "removes": removes, "texts": texts, "attributes": attributes]
            case 86..<93:  // Input
                data = ["source": 5, "id": liveElement(), "text": "********", "isChecked": false, "userTriggered": true]
            default:       // MouseInteraction
                data = ["source": 2, "type": rng.range(0, 9), "id": liveElement(), "x": rng.range(0, 390), "y": rng.range(0, 844)]
            }
            events.append(["type": 3, "timestamp": Int64(ts), "data": data])
        }
        return events
    }
}

/// Adds the browser agent's `__serialized` member: its own JSON copy of the event.
func withAgentSerialized(_ event: [String: Any]) -> [String: Any] {
    var out = event
    if let data = try? JSONSerialization.data(withJSONObject: event, options: [.sortedKeys]), let text = String(data: data, encoding: .utf8) {
        out["__serialized"] = text
    }
    return out
}

/// A bridge message body. `agentShape` adds the browser agent's `__serialized` copy to every event,
/// as the observation agent sends them; the standalone rrweb recorder sends bare events.
/// Keys are sorted: Swift randomizes dictionary order per process, which would make every `gen` differ.
func bridgeBody(_ events: [[String: Any]], agentShape: Bool = true) -> String {
    let data = try! JSONSerialization.data(withJSONObject: agentShape ? events.map(withAgentSerialized) : events, options: [.sortedKeys])
    return String(data: data, encoding: .utf8)!
}

func metaEvent(at ts: TimeInterval) -> [String: Any] {
    ["type": 4, "timestamp": Int64(ts), "data": ["href": "https://example.com/app", "width": 390, "height": 844]]
}

func fullSnapshotEvent(_ document: [String: Any], at ts: TimeInterval) -> [String: Any] {
    ["type": 2, "timestamp": Int64(ts), "data": ["node": document, "initialOffset": ["left": 0, "top": 0]]]
}

/// One chunk's worth of native replay events, pre-encoded: identical for every variant.
struct NativeChunk {
    let events: [AnyRRWebEvent]
    let json: [Data]
}

func nativeChunk(start: TimeInterval, seconds: Int, extraFullSnapshots: [TimeInterval]) -> NativeChunk {
    var rng = RNG(seed: UInt64(start) & 0xFFFF)
    func filler(_ bytes: Int) -> String { String((0..<bytes).map { _ in "abcdefghijklmnopqrstuvwxyz0123456789 ".randomElement(using: &rng)! }) }
    var items = [(StubNativeEvent, Data)]()
    items.append((StubNativeEvent(type: .meta, timestamp: start), Data("{\"type\":4,\"timestamp\":\(Int64(start)),\"data\":{\"href\":\"\",\"width\":390,\"height\":844}}".utf8)))
    items.append((StubNativeEvent(type: .fullSnapshot, timestamp: start), Data("{\"type\":2,\"timestamp\":\(Int64(start)),\"data\":{\"node\":\"\(filler(40_000))\"}}".utf8)))
    for s in 1..<seconds {
        let ts = start + Double(s) * 1000
        items.append((StubNativeEvent(type: .incrementalSnapshot, timestamp: ts), Data("{\"type\":3,\"timestamp\":\(Int64(ts)),\"data\":\"\(filler(1_000))\"}".utf8)))
    }
    for ts in extraFullSnapshots {
        items.append((StubNativeEvent(type: .meta, timestamp: ts), Data("{\"type\":4,\"timestamp\":\(Int64(ts)),\"data\":{\"href\":\"\",\"width\":390,\"height\":844}}".utf8)))
        items.append((StubNativeEvent(type: .fullSnapshot, timestamp: ts), Data("{\"type\":2,\"timestamp\":\(Int64(ts)),\"data\":{\"node\":\"\(filler(40_000))\"}}".utf8)))
    }
    let head = items.prefix(2)
    let rest = items.dropFirst(2).sorted { $0.0.timestamp < $1.0.timestamp }
    let all = Array(head) + rest
    return NativeChunk(events: all.map { AnyRRWebEvent($0.0) }, json: all.map { $0.1 })
}
