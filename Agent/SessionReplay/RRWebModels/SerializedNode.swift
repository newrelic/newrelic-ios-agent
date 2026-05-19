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
    case cdata
    case comment
}

enum SerializedNode: Codable {
    case document(DocumentNodeData)
    case documentType(DocumentTypeNodeData)
    case element(ElementNodeData)
    case text(TextNodeData)

    enum CodingKeys: CodingKey {
        case type, id
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
        // Accept rrweb's CDATA (4) and Comment (5) by tolerating an unknown raw type
        // and decoding the node as an empty text node — preserves tree shape and id
        // continuity for re-namespacing without trying to render unsupported content.
        let rawType = try container.decode(Int.self, forKey: .type)
        guard let nodeType = SerializedNodeType(rawValue: rawType) else {
            let id = (try? container.decode(Int.self, forKey: .id)) ?? 0
            self = .text(TextNodeData(id: id, isStyle: false, textContent: "", childNodes: []))
            return
        }
        switch nodeType {
        case .document: self = .document(try DocumentNodeData(from: decoder))
        case .documentType: self = .documentType(try DocumentTypeNodeData(from: decoder))
        case .element: self = .element(try ElementNodeData(from: decoder))
        case .text: self = .text(try TextNodeData(from: decoder))
        case .cdata, .comment:
            // CDATA / Comment nodes have no rendering meaning in our pipeline; collapse to empty text.
            let id = (try? container.decode(Int.self, forKey: .id)) ?? 0
            self = .text(TextNodeData(id: id, isStyle: false, textContent: "", childNodes: []))
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

/// HTML tag name. Native captors construct these with the named static constants
/// (`.div`, `.html`, …) — the dot syntax keeps working because the constants live
/// on the type. We use a struct (not an enum) so decoding can accept any tag string
/// rrweb emits inside a webview, not just the ones the native side produces.
struct TagType: Hashable, Codable, ExpressibleByStringLiteral {
    let rawValue: String

    init(_ rawValue: String) { self.rawValue = rawValue }
    init(stringLiteral value: String) { self.rawValue = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    // Tags emitted by the native captor pipeline.
    static let style: TagType = "style"
    static let div: TagType = "div"
    static let span: TagType = "span"
    static let label: TagType = "label"
    static let input: TagType = "input"
    static let head: TagType = "head"
    static let body: TagType = "body"
    static let html: TagType = "html"
    static let image: TagType = "img"
    static let svg: TagType = "svg"
    static let path: TagType = "path"
}

class ElementNodeData: SerializedNodeData {
    let type: SerializedNodeType = .element
    let id: Int
    let tagName: TagType
    var attributes: RRWebAttributes
    var childNodes: [SerializedNode] = []
    var isSVG: Bool?

    enum CodingKeys: CodingKey {
        case type, id, tagName, attributes, childNodes, isSVG
    }

    init(id: Int, tagName: TagType, attributes: RRWebAttributes, childNodes: [SerializedNode], isSVG: Bool? = nil) {
        self.id = id
        self.tagName = tagName
        self.attributes = attributes
        self.childNodes = childNodes
        self.isSVG = isSVG
    }
    
    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.tagName = try container.decode(TagType.self, forKey: .tagName)
        // rrweb sometimes emits numbers, bools, or null for HTML attributes
        // (e.g. `width=100`, `disabled=true`). Coerce to string so a single odd
        // attribute can't kill the whole snapshot decode.
        self.attributes = ElementNodeData.decodeAttributes(from: container) ?? [:]
        self.childNodes = try container.decodeIfPresent([SerializedNode].self, forKey: .childNodes) ?? []
        self.isSVG = try container.decodeIfPresent(Bool.self, forKey: .isSVG)
    }

    private static func decodeAttributes(from container: KeyedDecodingContainer<CodingKeys>) -> RRWebAttributes? {
        // Fast path — strict [String: String] (covers the vast majority of rrweb output).
        if let strict = try? container.decodeIfPresent(RRWebAttributes.self, forKey: .attributes) {
            return strict
        }
        // Fallback — treat each attribute value as JSON-any and stringify it.
        guard var nested = try? container.nestedContainer(keyedBy: AttributeKey.self, forKey: .attributes) else {
            return nil
        }
        var out: RRWebAttributes = [:]
        for key in nested.allKeys {
            if let s = try? nested.decode(String.self, forKey: key) {
                out[key.stringValue] = s
            } else if let i = try? nested.decode(Int.self, forKey: key) {
                out[key.stringValue] = String(i)
            } else if let d = try? nested.decode(Double.self, forKey: key) {
                out[key.stringValue] = String(d)
            } else if let b = try? nested.decode(Bool.self, forKey: key) {
                out[key.stringValue] = b ? "true" : "false"
            } else if (try? nested.decodeNil(forKey: key)) == true {
                out[key.stringValue] = ""
            }
            // Object/array values (e.g. style maps) — skip rather than fail.
        }
        return out
    }

    private struct AttributeKey: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(id, forKey: .id)
        try container.encode(tagName, forKey: .tagName)
        try container.encode(attributes, forKey: .attributes)
        try container.encode(childNodes, forKey: .childNodes)
        if let isSVG = isSVG {
            try container.encode(isSVG, forKey: .isSVG)
        }
    }
}

class TextNodeData: SerializedNodeData {
    let type: SerializedNodeType = .text
    let id: Int
    let isStyle: Bool
    let textContent: String
    var childNodes: [SerializedNode] = []

    enum CodingKeys: CodingKey {
        case type, id, isStyle, textContent, childNodes
    }

    init(id: Int, isStyle: Bool, textContent: String, childNodes: [SerializedNode]) {
        self.id = id
        self.isStyle = isStyle
        self.textContent = textContent
        self.childNodes = childNodes
    }

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // rrweb only emits `isStyle` for text nodes inside <style>; absent → false.
        // textContent is always present in practice but treat as empty if missing.
        id = try container.decode(Int.self, forKey: .id)
        isStyle = try container.decodeIfPresent(Bool.self, forKey: .isStyle) ?? false
        textContent = try container.decodeIfPresent(String.self, forKey: .textContent) ?? ""
        childNodes = try container.decodeIfPresent([SerializedNode].self, forKey: .childNodes) ?? []
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
