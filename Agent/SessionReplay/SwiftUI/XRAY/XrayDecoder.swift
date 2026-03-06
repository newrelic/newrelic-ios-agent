//
//  XrayDecoder.swift
//  Agent
//
//  Created by Chris Dillard on 9/25/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation

public struct XrayDecoder {


    // MARK: - Storage
    let runTimeTypeInspector: RunTimeTypeInspector

    // MARK: - Computed
    public var displayStyle: RunTimeTypeInspector.DisplayStyle {
        runTimeTypeInspector.displayStyle
    }

    // MARK: - Init
    public init(runTimeTypeInspector: RunTimeTypeInspector) {
        self.runTimeTypeInspector = runTimeTypeInspector
    }

    @inlinable
    public init(subject: Any?) {
        let runTimeTypeInspector = RunTimeTypeInspector(subject: subject as Any)
        self.init(runTimeTypeInspector: runTimeTypeInspector)
    }

    // MARK: - Child lookup
    public func child(_ paths: [RunTimeTypeInspector.Path]) -> Any? {
        runTimeTypeInspector.child(paths)
    }

    public func childIfPresent(_ first: RunTimeTypeInspector.Path, _ rest: RunTimeTypeInspector.Path...) -> Any? {
        runTimeTypeInspector.child([first] + rest)
    }
    
    // MARK: - Lazy wrapper
    public struct Lazy<T> where T:XrayConvertible {
        public let lazyXRAY: () throws -> T
    }
}

