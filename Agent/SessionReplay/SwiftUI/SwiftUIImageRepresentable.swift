//
//  SwiftUIImageRepresentable.swift
//  Agent
//
//  Created by Chris Dillard on 9/25/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import UIKit

@available(iOS 13.0, tvOS 13.0, *)
internal protocol SwiftUIImageRepresentable: Hashable {
    func makeSwiftUIImage() -> UIImage?
}

@available(iOS 13.0, tvOS 13.0, *)
internal struct ErasedSwiftUIImageRepresentable: SwiftUIImageRepresentable {
    private let rootClass: any SwiftUIImageRepresentable
    
    init(_ rootClass: some SwiftUIImageRepresentable) {
        if let rootClass = rootClass as? ErasedSwiftUIImageRepresentable {
            self = rootClass
        }
        else {
            self.rootClass = rootClass
        }
    }
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        AnyHashable(lhs.rootClass) == AnyHashable(rhs.rootClass)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(rootClass)
    }
    
    func makeSwiftUIImage() -> UIImage? {
        rootClass.makeSwiftUIImage()
    }
}
