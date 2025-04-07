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
    
//    enum CodingKeys: CodingKey {
//        case source
//    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
            case .mouseInteraction(let value):
            try container.encode(value)
        case .touchMove(let value):
            try container.encode(value)
        }
    }
}

enum RRWebMouseInteractionType: Int, Codable {
    case touchStart = 7
    case touchEnd = 9
}

struct RRWebMouseInteractionData: Codable {
    let type: RRWebMouseInteractionType
    let source: RRWebIncrementalSource = .mouseInteraction
    let id: Int
    let x: CGFloat
    let y: CGFloat
}

struct RRWebTouchPosition: Codable {
    let x: CGFloat
    let y: CGFloat
    let id: Int
    let timeOffset: TimeInterval
}

struct RRWebTouchMoveData: Codable {
    let source: RRWebIncrementalSource = .touchMove
    let positions: [RRWebTouchPosition]
}
