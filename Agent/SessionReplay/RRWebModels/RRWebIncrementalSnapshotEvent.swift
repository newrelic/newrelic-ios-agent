//
//  RRWebIncrementalSource.swift
//  Agent
//
//  Created by Steve Malsam on 4/4/25.
//  Copyright © 2025 New Relic. All rights reserved.
//


enum RRWebIncrementalSource: Int, Codable {
    case mutation = 0
    case mouseInteraction = 2
    case touchMove = 6
}

typealias IncrementalEvent = RRWebEvent<RRWebIncrementalData>
enum RRWebIncrementalData: RRWebEventData {
    static let eventType: RRWebEventType = .incrementalSnapshot
    
    case mutation(RRWebMutationData)
    case mouseInteraction(RRWebMouseInteractionData)
    case touchMove(RRWebTouchMoveData)
    
//    enum CodingKeys: CodingKey {
//        case source
//    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .mutation(let value):
            try container.encode(value)
        case .mouseInteraction(let value):
            try container.encode(value)
        case .touchMove(let value):
            try container.encode(value)
        }
    }
}

protocol MutationRecord {
    
}

struct RRWebMutationData: Codable {
    struct AddRecord: Codable, MutationRecord {
        let parentId: Int
        let nextId: Int
        let node: SerializedNode
    }
    
    struct RemoveRecord: Codable, MutationRecord {
        let parentId: Int
        let id: Int
    }
    
    struct TextRecord: Codable, MutationRecord {
        let id: Int
        let value: String
    }
    
    struct AttributeRecord: Codable, MutationRecord {
        let id: Int
        let attributes: RRWebAttributes
    }
    let source: RRWebIncrementalSource = .mutation
    
    let adds: [AddRecord]?
    let removes: [RemoveRecord]?
    let texts: [TextRecord]?
    let attributes: [AttributeRecord]?
    
    enum CodingKeys: CodingKey {
        case adds, removes, texts, attributes, source
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
