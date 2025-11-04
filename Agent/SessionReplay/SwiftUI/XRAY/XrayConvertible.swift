//
//  XrayConvertible.swift
//  Agent
//
//  Created by Chris Dillard on 9/26/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

public protocol XrayConvertible {
    init(xray: XrayDecoder) throws
}

extension XrayConvertible {
    public typealias Lazy = XrayDecoder.Lazy<Self>
}

extension XrayDecoder.Lazy: XrayConvertible {
    public init(xray: XrayDecoder) throws {
        lazyXRAY = { try T(xray: xray) }
    }
}

extension XrayDecoder.Lazy {
    public init(_ xray: T) {
        lazyXRAY = { xray }
    }
}
