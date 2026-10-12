// Minimal stand-ins for the agent types the WebView replay sources reference.
// RRWebEventType mirrors Agent/SessionReplay/RRWebModels/RRWebEvent.swift exactly.

import Foundation

enum RRWebEventType: Int, Codable {
    case fullSnapshot = 2
    case incrementalSnapshot = 3
    case meta = 4
}

protocol RRWebEventCommon {
    var type: RRWebEventType { get }
    var timestamp: TimeInterval { get }
}

struct StubNativeEvent: RRWebEventCommon {
    let type: RRWebEventType
    let timestamp: TimeInterval
}

struct AnyRRWebEvent {
    let base: RRWebEventCommon
    init(_ base: RRWebEventCommon) { self.base = base }
}
