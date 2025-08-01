//
//  SerializedNode.swift
//  Agent_iOS
//
//  Created by Steve Malsam on 4/2/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation

typealias RRWebAttributes = [String: String]

protocol SerializedNodeData: Codable {
    var id: Int { get }
    var childNodes: [SerializedNode] { get set }
}

enum SerializedNodeType: Int, Codable {
    case document
    case documentType
    case element
    case text
//    case cdata
//    case comment
}

enum SerializedNode: Codable {
    case document(DocumentNodeData)
    case documentType(DocumentTypeNodeData)
    case element(ElementNodeData)
    case text(TextNodeData)
//    case cdata
//    case comment
    
    enum CodingKeys: CodingKey {
        case type
    }
    
    var type: SerializedNodeType {
        switch self {
        case .document: return .document
        case .documentType: return .documentType
        case .element: return .element
        case .text: return .text
        }
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let nodeType: SerializedNodeType = try container.decode(SerializedNodeType.self, forKey: .type)
        switch nodeType {
            
        case .document: self = .document(try DocumentNodeData(from: decoder))
        case .documentType: self = .documentType(try DocumentTypeNodeData(from: decoder))
        case .element: self = .element(try ElementNodeData(from: decoder))
        case .text: self = .text(try TextNodeData(from: decoder))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .document(let documentNode): try container.encode(documentNode)
        case .documentType(let documentTypeNode): try container.encode(documentTypeNode)
        case .element(let elementNode): try container.encode(elementNode)
        case .text(let textNode): try container.encode(textNode)
        }
    }
}

class DocumentNodeData: SerializedNodeData {
    let type: SerializedNodeType = .document
    let id: Int
    var childNodes: [SerializedNode]
    
    enum CodingKeys: CodingKey {
        case type, id, childNodes
    }
    
    init(id: Int, childNodes: [SerializedNode]) {
        self.id = id
        self.childNodes = childNodes
    }
    
    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        childNodes = try container.decodeIfPresent([SerializedNode].self, forKey: .childNodes) ?? []
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(id, forKey: .id)
        if !childNodes.isEmpty {
            try container.encode(childNodes, forKey: .childNodes)
        }
    }
}

class DocumentTypeNodeData: SerializedNodeData {
    let type: SerializedNodeType = .documentType
    let id: Int
    let name: TagType
    var childNodes: [SerializedNode] = []
    let publicId: String
    let systemId: String
    
    enum CodingKeys: String, CodingKey {
        case type, id, name, publicId, systemId
    }
    
    init(id: Int, name: TagType, publicId: String = "", systemId: String = "") {
        self.id = id
        self.name = name
        self.publicId = publicId
        self.systemId = systemId
    }
    
    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(TagType.self, forKey: .name)
        publicId = try container.decodeIfPresent(String.self, forKey: .publicId) ?? ""
        systemId = try container.decodeIfPresent(String.self, forKey: .systemId) ?? ""
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type.rawValue, forKey: .type)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(publicId, forKey: .publicId)
        try container.encode(systemId, forKey: .systemId)
    }
}

enum TagType: String, Codable {
    case style = "style"
    case div = "div"
    case span = "span"
    case head = "head"
    case body = "body"
    case html = "html"
    case image = "img"
}

class ElementNodeData: SerializedNodeData {
    let type: SerializedNodeType = .element
    let id: Int
    let tagName: TagType
    var attributes: RRWebAttributes
    var childNodes: [SerializedNode] = []
    
    enum CodingKeys: CodingKey {
        case type, id, tagName, attributes, childNodes
    }
    
    init(id: Int, tagName: TagType, attributes: RRWebAttributes, childNodes: [SerializedNode]) {
        self.id = id
        self.tagName = tagName
        self.attributes = attributes
        self.childNodes = childNodes
    }
    
    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.tagName = try container.decode(TagType.self, forKey: .tagName)
        self.attributes = try container.decode(RRWebAttributes.self, forKey: .attributes)
        self.childNodes = try container.decode([SerializedNode].self, forKey: .childNodes)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(id, forKey: .id)
        try container.encode(tagName, forKey: .tagName)
        try container.encode(attributes, forKey: .attributes)
        try container.encode(childNodes, forKey: .childNodes)
    }
}

class TextNodeData: SerializedNodeData {
    let type: SerializedNodeType = .text
    let id: Int
    let isStyle: Bool
    let textContent: String
    var childNodes: [SerializedNode] = []
    
    init(id: Int, isStyle: Bool, textContent: String, childNodes: [SerializedNode]) {
        self.id = id
        self.isStyle = isStyle
        self.textContent = textContent
        self.childNodes = childNodes
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(id, forKey: .id)
        try container.encode(isStyle, forKey: .isStyle)
        try container.encode(textContent, forKey: .textContent)
        if !childNodes.isEmpty {
            try container.encode(childNodes, forKey: .childNodes)
        }
    }
}
