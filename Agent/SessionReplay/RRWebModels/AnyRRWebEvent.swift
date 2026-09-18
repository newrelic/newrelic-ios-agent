//
//  AnyRRWebEvent.swift
//  Agent_iOS
//
//  Created by Steve Malsam on 4/3/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation

struct AnyRRWebEvent: Codable {
    let base: RRWebEventCommon
    
    enum CodingKeys: CodingKey {
        case type, timestamp, data
    }
    
    init(_ base: RRWebEventCommon) {
        self.base = base
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type: RRWebEventType = try container.decode(RRWebEventType.self, forKey: .type)
        
        switch type {

        case .fullSnapshot:
            self.base = try FullSnapshotEvent(from: decoder)
        case.incrementalSnapshot:
            self.base = try IncrementalEvent(from: decoder)
        case .meta:
            self.base = try MetaEvent(from: decoder)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        try (base as Encodable).encode(to: encoder)
    }
}

/// Test-only seams. This module builds with BUILD_LIBRARY_FOR_DISTRIBUTION
/// (Library Evolution) enabled, under which `@testable import` cannot resolve
/// `RRWebEvent<T>`'s conformance to `RRWebEventCommon` (a Codable-refining
/// protocol) for a caller outside the module -- not even via a generic
/// constraint. So these take only plain values and do the construction (and
/// the existential boxing) entirely inside this file, where the conformance
/// is directly visible, returning a concrete AnyRRWebEvent a test can freely
/// inspect.
func makeMetaAnyRRWebEvent(timestamp: TimeInterval) -> AnyRRWebEvent {
    AnyRRWebEvent(MetaEvent(timestamp: timestamp,
                            data: RRWebMetaData(href: "http://newrelic.com", width: 100, height: 100)))
}

func makeTouchAnyRRWebEvent(timestamp: TimeInterval) -> AnyRRWebEvent {
    let data = RRWebIncrementalData.mouseInteraction(
        RRWebMouseInteractionData(type: .touchStart, id: 1, x: 10, y: 10))
    return AnyRRWebEvent(IncrementalEvent(timestamp: timestamp, data: data))
}

func makeFullSnapshotAnyRRWebEvent(timestamp: TimeInterval) -> AnyRRWebEvent {
    let documentNode = DocumentNodeData(id: 1, childNodes: [])
    let snapshotData = RRWebFullSnapshotData(node: .document(documentNode),
                                              initialOffset: RRWebFullSnapshotData.InitialOffset(top: 0, left: 0))
    return AnyRRWebEvent(FullSnapshotEvent(timestamp: timestamp, data: snapshotData))
}
