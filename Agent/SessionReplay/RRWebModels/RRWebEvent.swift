//
//  RRWebEvent.swift
//  Agent_iOS
//
//  Created by Steve Malsam on 3/25/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation

protocol RRWebEvent: Encodable {
    var type: EventType { get }
    var timestamp: TimeInterval { get }
}

enum RRWebRecordedEvent: Encodable {
    case fullSnapshot
    case incrementalSnapshot
    case meta
}

enum EventType: Int, Codable {
    case fullSnapshot = 2
    case incrementalSnapshot = 3
    case meta = 4
}

struct MetaEvent: RRWebEvent {
    let type: EventType = .meta
    let timestamp: TimeInterval
    let data: MetaEventData
    
    struct MetaEventData: Codable {
        let href: String
        let width: Int
        let height: Int
    }
}

struct FullSnapshotEvent: RRWebEvent {
    let type: EventType = .fullSnapshot
    let timestamp: TimeInterval
    let data: FullSnapshotData
    
    struct InitialOffset: Encodable {
        let top: Int
        let left: Double
    }
    
    struct FullSnapshotData: Encodable {
        let initialOffset: InitialOffset
        let node: RRWebNode
        
        enum CodingKeys: String, CodingKey {
            case initialOffset
            case node
        }
        
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(initialOffset, forKey: .initialOffset)
            // encode child node array
            switch node {
            case let elementNode as RRWebElementNode:
                try container.encode(elementNode, forKey: .node)
            case let textNode as RRWebElementNode:
                try container.encode(textNode, forKey: .node)
            case let documentNode as RRWebDocumentNode:
                try container.encode(documentNode, forKey: .node)
            default:
                try container.encodeNil(forKey: .node)
            }
        }
    }
}

enum NodeType: Int, Codable {
    case document
    case documentType
    case element
    case text
    case cdata
    case comment
}

enum TagType: String, Codable {
    case style = "style"
    case div = "div"
    case head = "head"
    case body = "body"
    case html = "html"
}

protocol RRWebNode: Encodable {
    var type: NodeType { get }
    var id: Int { get }
}

class RRWebDocumentNode: RRWebNode {
    var type: NodeType = .document
    var id: Int
    var childNodes: [RRWebNode]
    
    enum CodingKeys: CodingKey {
        case type
        case id
        case childNodes
    }
    
    init(id: Int, childNodes: [RRWebNode]) {
        self.id = id
        self.childNodes = childNodes
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(id, forKey: .id)
        var unkeyedContainer = container.nestedUnkeyedContainer(forKey: .childNodes)
        for node in childNodes {
            switch node {
            case let elementNode as RRWebElementNode:
                try unkeyedContainer.encode(elementNode)
            case let textNode as RRWebTextNode:
                try unkeyedContainer.encode(textNode)
            case let documentNode as RRWebDocumentNode:
                try unkeyedContainer.encode(documentNode)
            default:
                continue
            }
        }
    }
}


class RRWebElementNode: RRWebNode {
    let type: NodeType = .element
    let id: Int
    let tagName: TagType
    let attributes: [String: String]
    var childNodes: [RRWebNode]
    
    enum CodingKeys: CodingKey {
        case type
        case id
        case tagName
        case attributes
        case childNodes
    }
    
    init(id: Int, tagName: TagType, attributes: [String : String], childNodes: [RRWebNode]) {
        self.id = id
        self.tagName = tagName
        self.attributes = attributes
        self.childNodes = childNodes
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(id, forKey: .id)
        try container.encode(tagName, forKey: .tagName)
        try container.encode(attributes, forKey: .attributes)
        // encode child node array
        var unkeyedContainer = container.nestedUnkeyedContainer(forKey: .childNodes)
        for node in childNodes {
            switch node {
            case let elementNode as RRWebElementNode:
                try unkeyedContainer.encode(elementNode)
            case let textNode as RRWebTextNode:
                try unkeyedContainer.encode(textNode)
            case let documentNode as RRWebDocumentNode:
                try unkeyedContainer.encode(documentNode)
            default:
                continue
            }
        }
    }
}

class RRWebTextNode: RRWebNode {
    let type: NodeType = .text
    let id: Int
    let textContent: String
    let isStyle: Bool
    
    init(id: Int, textContent: String, isStyle: Bool) {
        self.id = id
        self.textContent = textContent
        self.isStyle = isStyle
    }
}
