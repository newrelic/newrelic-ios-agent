//
//  XrayDecoder+Children.swift
//  Agent
//
//  Created by Chris Dillard on 9/26/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

// Swift
extension XrayDecoder {
    public func report(_ error: Swift.Error) {
        NRLOG_DEBUG("Xray error: \(error)")
    }
    
    // MARK: - Public API (Non-XRAY Generic)
    public func rawChildIfExists<T>(type: T.Type = T.self,
                                    _ first: RunTimeTypeInspector.Path,
                                    _ rest: RunTimeTypeInspector.Path...) -> T? {
        rawChildXRAY(pathsXRAY(first, rest)) as? T
    }
    
    public func extract<T>(type: T.Type = T.self,
                           _ first: RunTimeTypeInspector.Path,
                           _ rest: RunTimeTypeInspector.Path...) throws -> T {
        try extract(type: type, pathsXRAY(first, rest))
    }
    
    public func extract<T>(type: T.Type = T.self,
                           _ pathsXRAY: [RunTimeTypeInspector.Path]) throws -> T {
        let value = try requireChildXRAY(pathsXRAY)
        guard let cast = value as? T else {
            let context = XRayDecoderError.XrayDecoderContext.init(typeOfSubject: runTimeTypeInspector.typeOfSubject, pathsXRAY: pathsXRAY)
            throw XRayDecoderError.typeMismatch(context,
                                         expectedType: type,
                                         gotType: Swift.type(of: value))
        }
        return cast
    }
    
    // MARK: - XRAY-Conforming Types
    public func xray<T>(type: T.Type = T.self, _ subject: Any?) throws -> T where T: XrayConvertible {
        try T(xray: XrayDecoder(subject: subject))
    }
    
    public func childIfPresent<T>(type: T.Type = T.self,
                                  _ first: RunTimeTypeInspector.Path,
                                  _ rest: RunTimeTypeInspector.Path...) -> T? where T: XrayConvertible {
        do {
            return try extract(type: type, pathsXRAY(first, rest))
        }
        catch XRayDecoderError.notFound {
            return nil
        }
        catch {
            report(error)
            return nil
        }
    }
    
    public func extract<T>(type: T.Type = T.self, _ first: RunTimeTypeInspector.Path, _ rest: RunTimeTypeInspector.Path...) throws -> T where T: XrayConvertible {
        let pathsXRAY = pathsXRAY(first, rest)
        return try extract(type: type, pathsXRAY)
    }
    
    public func extract<T>(type: T.Type = T.self, _ pathsXRAY: [RunTimeTypeInspector.Path]) throws -> T where T: XrayConvertible {
        let value = try requireChildXRAY(pathsXRAY)
        return try xray(value)
    }
    
    public func extract<Element>(_ first: RunTimeTypeInspector.Path, _ rest: RunTimeTypeInspector.Path...) throws -> [Element] where Element: XrayConvertible {
        let anyArray = try requireChildXRAY(pathsXRAY(first, rest))
        guard let raw = anyArray as? [Any] else {
            let context = XRayDecoderError.XrayDecoderContext(typeOfSubject: runTimeTypeInspector.typeOfSubject, pathsXRAY: pathsXRAY(first, rest))
            throw XRayDecoderError.typeMismatch(context,
                                         expectedType: [Any].self,
                                         gotType: runTimeTypeInspector.typeOfSubject)
        }

        var resultElements: [Element] = []
        resultElements.reserveCapacity(raw.count)

        for item in raw {
            do {
                let converted = try xray(item) as Element
                resultElements.append(converted)
            } catch {
                report(error)
                continue
            }
        }

        return resultElements
    }
    
    public func extract<Key, Value>(_ first: RunTimeTypeInspector.Path,
                                    _ rest: RunTimeTypeInspector.Path...) throws -> [Key: Value] where Key: Hashable, Value: XrayConvertible {
        let anyDict = try requireChildXRAY(pathsXRAY(first, rest))
        guard let raw = anyDict as? [Key: Any] else {
            let context = XRayDecoderError.XrayDecoderContext.init(typeOfSubject: runTimeTypeInspector.typeOfSubject, pathsXRAY: pathsXRAY(first, rest))
            throw XRayDecoderError.typeMismatch(context,
                                         expectedType: [Key: Any].self,
                                         gotType: runTimeTypeInspector.typeOfSubject)
        }
        return raw.reduce(into: [:]) { acc, pair in
            do { try acc[pair.key] = xray(pair.value) }
            
            catch { report(error) }
        }
    }
    
    public func extract<Key, Value>(_ first: RunTimeTypeInspector.Path, _ rest: RunTimeTypeInspector.Path...) throws -> [Key: Value] where Key: XrayConvertible & Hashable, Value: XrayConvertible {
        
        let wholePath = pathsXRAY(first, rest)
        let theNode = try requireChildXRAY(wholePath)
        
        guard let dict = theNode as? [AnyHashable: Any] else {
            throw XRayDecoderError.typeMismatch(XRayDecoderError.XrayDecoderContext.init(typeOfSubject: runTimeTypeInspector.typeOfSubject, pathsXRAY: wholePath),
                                         expectedType: [AnyHashable: Any].self,
                                         gotType: runTimeTypeInspector.typeOfSubject)
        }
        
        var result: [Key: Value] = [:]
        for (rawKey, rawValue) in dict {
            do {
                let k = try xray(rawKey.base) as Key
                let v = try xray(rawValue) as Value
                result[k] = v
            }
            catch {
                report(error)
            }
        }
        return result
    }
}
