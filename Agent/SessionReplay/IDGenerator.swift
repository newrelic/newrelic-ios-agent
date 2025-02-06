//
//  NodeIDGenerator.swift
//  Agent_iOS
//
//  Created by Steve Malsam on 2/5/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation

class IDGenerator {
    private let maxID: Int64
    private let initialID: Int64
    private var currentID: Int64 = 0
    
    init(initialID: Int64 = 0, maxID: Int64 = Int64.max) {
        self.maxID = maxID
        self.initialID = initialID
        self.currentID = initialID
    }
    
    func getId()-> Int64 {
        let nextID = currentID
        currentID = (currentID < maxID) ? currentID + 1 : self.initialID
        return nextID
    }
}
