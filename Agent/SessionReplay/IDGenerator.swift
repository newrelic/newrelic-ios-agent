//
//  NodeIDGenerator.swift
//  Agent_iOS
//
//  Created by Steve Malsam on 2/5/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation

class IDGenerator {
    private let maxID: Int
    private let initialID: Int
    private var currentID: Int = 0
    
    static let shared = IDGenerator()
    
    private init(initialID: Int = 0, maxID: Int = Int.max) {
        self.maxID = maxID
        self.initialID = initialID
        self.currentID = initialID
    }
    
    func getId()-> Int {
        let nextID = currentID
        currentID = (currentID < maxID) ? currentID + 1 : self.initialID
        return nextID
    }
}
