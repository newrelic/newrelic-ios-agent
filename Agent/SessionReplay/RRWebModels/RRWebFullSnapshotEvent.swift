//
//  RRWebFullSnapshotData.swift
//  Agent
//
//  Created by Steve Malsam on 4/4/25.
//  Copyright © 2025 New Relic. All rights reserved.
//


typealias FullSnapshotEvent = RRWebEvent<RRWebFullSnapshotData>
struct RRWebFullSnapshotData: RRWebEventData {
    static let eventType: RRWebEventType = .fullSnapshot
    
    struct InitialOffset: Codable {
        let top: Int
        let left: Int
    }
    
    let node: SerializedNode
    let initialOffset: InitialOffset
}