//
//  SwiftUIAlignment.swift
//  Agent
//
//  Created by Chris Dillard on 10/1/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

public struct SwiftUIAlignment: Hashable {
    
    public let horizontal: Horizontal?
    public let vertical: Vertical?
    
    public init(horizontal: Horizontal? = nil,
                vertical: Vertical? = nil) {
        self.horizontal = horizontal
        self.vertical = vertical
    }
    
    public enum Horizontal: String {
        case left
        case right
        case center
    }
    
    public enum Vertical: String {
        case top
        case bottom
        case center
    }
}
