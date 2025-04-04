//
//  RRWebIncrementalSource.swift
//  Agent
//
//  Created by Steve Malsam on 4/4/25.
//  Copyright © 2025 New Relic. All rights reserved.
//


enum RRWebIncrementalSource: Int, Codable {
    case mouseInteraction = 2
    case touchMove = 6
}

typealias IncrementalEvent = RRWebEvent<RRWebIncrementalData>
enum RRWebIncrementalData: RRWebEventData {
    static let eventType: RRWebEventType = .incrementalSnapshot
    
    case mouseInteraction(RRWebMouseInteractionData)
    case touchMove(RRWebTouchMoveData)
}

enum RRWebMouseInteractionType: Int, Codable {
    case touchStart = 7
    case touchEnd = 9
}

struct RRWebMouseInteractionData: Codable {
    let type: RRWebMouseInteractionType
    let id: Int
    let x: Int
    let y: Int
}

struct RRWebTouchPosition: Codable {
    let x: Int
    let y: Int
    let id: Int
    let timeOffset: TimeInterval
}

struct RRWebTouchMoveData: Codable {
    let positions: [RRWebTouchPosition]
}