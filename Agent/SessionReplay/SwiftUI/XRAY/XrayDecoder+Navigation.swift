//
//  XrayDecoder+Navigation.swift
//  Agent
//
//  Created by Chris Dillard on 10/1/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

// MARK: - Helpers

import Foundation

extension XrayDecoder {
    
    func pathsXRAY(_ first: RunTimeTypeInspector.Path,
                   _ rest: [RunTimeTypeInspector.Path]) -> [RunTimeTypeInspector.Path] {
        var arr = [first]
        arr.append(contentsOf: rest)
        return arr
    }
    
    func rawChildXRAY(_ paths: [RunTimeTypeInspector.Path]) -> Any? {
        child(paths)
    }
    
    func requireChildXRAY(_ paths: [RunTimeTypeInspector.Path]) throws -> Any {
        guard let value = rawChildXRAY(paths) else {
            let context = XRayDecoderError.XrayDecoderContext.init(typeOfSubject: runTimeTypeInspector.typeOfSubject, pathsXRAY: paths)
            throw XRayDecoderError.notFound(context)
        }
        return value
    }
}
