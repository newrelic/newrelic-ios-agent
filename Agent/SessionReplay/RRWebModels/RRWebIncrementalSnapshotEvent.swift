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
        let nextId: Int?
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
        
        init(id: Int, attributes: RRWebAttributes) {
            self.id = id
            self.attributes = attributes
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            
            if !attributes.isEmpty {
                // Create nested container for attributes
                var attributesContainer = container.nestedContainer(keyedBy: AttributeKeys.self, forKey: .attributes)
                
                // Build style string from attributes dictionary
                let styleString = attributes.map { "\($0.key): \($0.value);" }.joined(separator: " ")
                try attributesContainer.encode(styleString, forKey: .style)
            }
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(Int.self, forKey: .id)
            
            // Decode nested attributes container
            let attributesContainer = try container.nestedContainer(keyedBy: AttributeKeys.self, forKey: .attributes)
            let styleString = try attributesContainer.decode(String.self, forKey: .style)
            
            // Parse style string into attributes dictionary
            let pairs = styleString
                .split(separator: ";")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            
            var attributes: RRWebAttributes = [:]
            for pair in pairs {
                let parts = pair.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                if parts.count == 2 {
                    attributes[String(parts[0])] = String(parts[1])
                }
            }
            self.attributes = attributes
        }
        
        enum CodingKeys: String, CodingKey {
            case id
            case attributes
        }
        
        enum AttributeKeys: String, CodingKey {
            case style
        }
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
