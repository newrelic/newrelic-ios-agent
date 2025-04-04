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
