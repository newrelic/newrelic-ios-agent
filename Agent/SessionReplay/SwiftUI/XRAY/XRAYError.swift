//
//  XRayDecoderError.swift
//  Agent
//
//  Created by Chris Dillard on 10/1/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

// MARK: - Error
public enum XRayDecoderError: Swift.Error {
    public struct XrayDecoderContext {
        public let typeOfSubject: Any.Type
        public let pathsXRAY: [RunTimeTypeInspector.Path]
        public init(typeOfSubject: Any.Type, pathsXRAY: [RunTimeTypeInspector.Path]) {
            self.typeOfSubject = typeOfSubject
            self.pathsXRAY = pathsXRAY
        }
    }
    case notFound(XRAYContext)
    case typeMismatch(XRAYContext, expectedType: Any.Type, gotType: Any.Type)
}
