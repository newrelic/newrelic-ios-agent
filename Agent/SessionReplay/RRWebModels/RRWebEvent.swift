//
//  RRWebEvent.swift
//  Agent_iOS
//
//  Created by Steve Malsam on 3/25/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation

enum RRWebEventType: Int, Codable {
    case fullSnapshot = 2
    case incrementalSnapshot = 3
    case meta = 4
}

protocol RRWebEventCommon: Codable {
    var type: RRWebEventType { get }
    var timestamp: TimeInterval { get }
}

protocol RRWebEventData: Codable {
    static var eventType: RRWebEventType { get }
}

struct RRWebEvent<T: RRWebEventData>: RRWebEventCommon {
    var timestamp: TimeInterval
    let data: T
    
    var type: RRWebEventType {
        return T.eventType
    }
    
    enum CodingKeys: CodingKey {
        case timestamp, type, data
    }
    
    init(timestamp: TimeInterval, data: T) {
        self.timestamp = timestamp
        self.data = data
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.timestamp = try container.decode(TimeInterval.self, forKey: .timestamp)
        self.data = try container.decode(T.self, forKey: .data)
        let decodedType = try container.decode(RRWebEventType.self, forKey: .type)
        guard decodedType == T.eventType else {
            throw RRWebDecodingError.eventTypeMismatch(
                actual: decodedType,
                expected: T.eventType,
                dataType: T.self,
                codingPath: container.codingPath)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(T.eventType, forKey: .type)
        try container.encode(self.timestamp, forKey: .timestamp)
        try container.encode(self.data, forKey: .data)
    }
}

enum RRWebDecodingError: Error {
    case eventTypeMismatch(actual: RRWebEventType, expected: RRWebEventType, dataType: Any.Type, codingPath: [CodingKey])
}

extension RRWebDecodingError: CustomDebugStringConvertible {
    var debugDescription: String {
        switch self {
        case .eventTypeMismatch(let actual, let expected, let dataType, let codingPath):
            let pathString = codingPath.map { key in
                if let index = key.intValue {
                    return "[\(index)]"
                }
                return "." + key.stringValue
            }.joined().dropFirst()
            
            return """
            RRWebDecodingError: Event Type Mismatch
                Path: \(pathString)
                FoundType: \(actual) (\(actual.rawValue))
                ExpectedType: \(expected) (\(expected.rawValue))
                For data structure: \(String(describing: dataType))
            """
        }
    }
}

extension RRWebDecodingError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .eventTypeMismatch(let actual, let expected, let dataType, let codingPath):
            return "RRWebDecoding Error: The event type code (\(actual.rawValue)) found in the JSON does not match the expected type code (\(expected.rawValue)) for the event data structure '\(String(describing: dataType))'."
        }
    }
}

typealias MetaEvent = RRWebEvent<RRWebMetaData>
struct RRWebMetaData: RRWebEventData {
    static let eventType: RRWebEventType = .meta
    let href: String
    let width: Int
    let height: Int
}
