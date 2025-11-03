//
//  SwiftUIStyledTextRes.swift
//  Agent
//
//  Created by Chris Dillard on 10/1/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

internal struct SwiftUIStyledTextRes {
    internal struct StringDrawing: XrayConvertible {
        let storage: NSAttributedString
        
        init(xray: XrayDecoder) throws {
            storage =
            try xray.extract(SwiftUIConstants.storagePath)
        }
    }
}
