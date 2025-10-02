//
//  RunTimeTypeInspector.swift
//  Agent
//
//  Created by Chris Dillard on 9/25/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

public struct RunTimeTypeInspector {
    // MARK: - Typealiases
    public typealias Child = (label: String?, value: Any)
    public typealias Children = AnyCollection<Child>
    
    // MARK: - DisplayStyle
    public enum DisplayStyle: Equatable {
        case `struct`
        case `class`
        case `enum`(case: String)
        case tuple
        case `nil`
        case opaque
    }
    
    // MARK: - Path
    public enum Path {
        case index(Int)
        case key(String)
        init(_ text: String) { self = .key(text) }
    }
    
    // MARK: - LazyBox
    private final class LazyBox<T> {
        private let loader: () -> T
        lazy var lazy: T = loader()
        init(_ loader: @escaping () -> T) { self.loader = loader }
    }
    
    // MARK: - Stored Properties
    public let subject: Any
    public let typeOfSubject: Any.Type
    public let displayStyle: DisplayStyle
    public let children: Children
    
    // MARK: - Lazy Properties
    public var superclassMirror: RunTimeTypeInspector? { _superclassMirror.lazy }
    public var keyPaths: [String: Int]? { _keyPaths.lazy }
    
    private let _superclassMirror: LazyBox<RunTimeTypeInspector?>
    private let _keyPaths: LazyBox<[String: Int]?>
    
    // MARK: - Init
    init<C>(
        subject: Any,
        typeOfSubject: Any.Type,
        displayStyle: DisplayStyle,
        children: C = [],
        keyPaths: @autoclosure @escaping () -> [String: Int]? = nil,
        superclassMirror: @autoclosure @escaping () -> RunTimeTypeInspector? = nil ) where C: Collection, C.Element == Child {
            self.subject = subject
            self.typeOfSubject = typeOfSubject
            self.displayStyle = displayStyle
            self.children = Children(children)
            self._keyPaths = LazyBox(keyPaths)
            self._superclassMirror = LazyBox(superclassMirror)
        }
    
    // MARK: - Public Reflecting Init
    public init(subject: Any, typeOfSubject: Any.Type? = nil) {
        let typeOfSubject = typeOfSubject ?? _getNormalizedType(subject, type: type(of: subject))
        let mk = _MetadataKind(typeOfSubject)
        
        switch mk {
        case _MetadataKind.tuple:
            self.init(subject: subject,
                      typeOfSubject: typeOfSubject,
                      displayStyle: DisplayStyle.tuple,
                      children: _getChildren(of: subject, type: typeOfSubject, count: _getChildCount(subject, type: typeOfSubject)))
        case _MetadataKind.struct:
            let childCount = _getChildCount(subject, type: typeOfSubject)
            self.init(subject: subject,typeOfSubject: typeOfSubject,
                      displayStyle: DisplayStyle.struct,
                      children: _getChildren(of: subject, type: typeOfSubject, count: childCount),
                      keyPaths: _getKeyPaths(typeOfSubject, count: childCount))
            
        case _MetadataKind.enum:
            let childCount = _getChildCount(subject, type: typeOfSubject)
            let caseName = _getEnumCaseName(subject).map { String(cString: $0) } ?? ""
            self.init(subject: subject,
                      typeOfSubject: typeOfSubject,
                      displayStyle: DisplayStyle.enum(case: caseName),
                      children: _getChildren(of: subject, type: typeOfSubject, count: childCount)
            )
            
        case _MetadataKind.optional:
            if _getChildCount(subject, type: typeOfSubject) > 0 {
                self.init(subject: _getChild(of: subject, type: typeOfSubject, index: 0).value)
            }
            else {
                self.init(subject: subject, typeOfSubject: typeOfSubject, displayStyle: .nil)
            }
        case _MetadataKind.class, _MetadataKind.foreignClass, _MetadataKind.objcClassWrapper:
            let childCount = _getChildCount(subject, type: typeOfSubject)
            self.init(subject: subject,
                      typeOfSubject: typeOfSubject,
                      displayStyle: DisplayStyle.class,
                      children: _getChildren(of: subject, type: typeOfSubject, count: childCount),
                      keyPaths: _getKeyPaths(typeOfSubject, count: childCount, recursiveCount: _getRecursiveChildCount(typeOfSubject)),
                      superclassMirror: _getSuperclass(typeOfSubject).map { RunTimeTypeInspector(subject: subject, typeOfSubject: $0) })
            
            
        default:
            self.init(subject: subject, typeOfSubject: typeOfSubject,
                      displayStyle: DisplayStyle.opaque)
        }
    }
    
    
    // MARK: - Child Navigation
    func child(_ first: Path, _ rest: Path...) -> Any? {
        var paths = [first] + rest
        return child(paths: &paths)
    }
    
    public func child(_ paths: [Path]) -> Any? {
        var p = paths
        return child(paths: &p)
    }
    
    private func child(paths: inout [Path]) -> Any? {
        guard let value = child(path: paths.removeFirst()) else { return nil }
        
        return paths.isEmpty ? value : RunTimeTypeInspector(subject: value).child(paths: &paths)
    }
    
    private func child(path: Path) -> Any? {
        switch path {
        case .index(let i):
            if i < children.count { return children[AnyIndex(i)].value }
        case .key(let k):
            if let idx = keyPaths?[k] { return children[AnyIndex(idx)].value }
        }
        return superclassMirror?.child(path: path)
    }
}

// MARK: - Literal Conformances
extension RunTimeTypeInspector.Path: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) { self =
        RunTimeTypeInspector.Path.index(value) }
}

extension RunTimeTypeInspector.Path: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) { self =
        RunTimeTypeInspector.Path.key(value) }
}

// Internal Swift Reflection APIs
// Available at https://github.com/swiftlang/swift/blob/main/stdlib/public/core/ReflectionMirror.swift

private func _getChild<T>(of value: T, type: Any.Type, index: Int) -> RunTimeTypeInspector.Child {
    var nameC: UnsafePointer<CChar>? = nil
    var freeFunc: NameFreeFunc? = nil
    let value = _getChild(of: value, type: type, index: index, outName: &nameC, outFreeFunc: &freeFunc)
    let name = nameC.flatMap { String(cString: $0) }
    freeFunc?(nameC)
    return (name, value)
}

private func _getChildren<T>(of value: T, type: Any.Type, count: Int) -> any Collection<RunTimeTypeInspector.Child> {
    (0 ..< count).lazy.map { _getChild(of: value, type: type, index: $0) }
}

private func _getKeyPaths(_ type: Any.Type, count: Int, recursiveCount: Int) -> [String: Int] {
    let skip = recursiveCount - count
    return (skip..<recursiveCount).reduce(into: [:]) { result, index in
        var field = _FieldReflectionMetadata()
        _ = _getChildMetadata(type, index: index, fieldMetadata: &field)
        
        field.name
            .flatMap { String(cString: $0) }
            .map { result[$0] = index - skip }
        
        field.freeFunc?(field.name)
    }
}

private func _getKeyPaths(_ type: Any.Type, count: Int) -> [String: Int] {
    _getKeyPaths(type, count: count, recursiveCount: count)
}

import SwiftShims

@_silgen_name("swift_EnumCaseName")
private func _getEnumCaseName<T>(_ value: T) -> UnsafePointer<CChar>?

@_silgen_name("swift_getMetadataKind")
private func _metadataKind(_: Any.Type) -> UInt

@_silgen_name("swift_reflectionMirror_normalizedType")
private func _getNormalizedType<T>(_: T, type: Any.Type) -> Any.Type

@_silgen_name("swift_reflectionMirror_count")
private func _getChildCount<T>(_: T, type: Any.Type) -> Int

@_silgen_name("swift_reflectionMirror_recursiveCount")
private func _getRecursiveChildCount(_: Any.Type) -> Int

@_silgen_name("swift_reflectionMirror_recursiveChildMetadata")
private func _getChildMetadata(
    _: Any.Type,
    index: Int,
    fieldMetadata: UnsafeMutablePointer<_FieldReflectionMetadata>
) -> Any.Type

private typealias NameFreeFunc = @convention(c) (UnsafePointer<CChar>?) -> Void

@_silgen_name("swift_reflectionMirror_subscript")
private func _getChild<T>(
    of: T,
    type: Any.Type,
    index: Int,
    outName: UnsafeMutablePointer<UnsafePointer<CChar>?>,
    outFreeFunc: UnsafeMutablePointer<NameFreeFunc?>
) -> Any

// https://github.com/apple/swift/blob/main/include/swift/ABI/MetadataKind.def
private enum _MetadataKind: UInt {
    // With "flags":
    // runtimePrivate = 0x100
    // nonHeap = 0x200
    // nonType = 0x400
    
    case `class` = 0
    case `struct` = 0x200                   // 0 | nonHeap
    case `enum` = 0x201                     // 1 | nonHeap
    case optional = 0x202                   // 2 | nonHeap
    case foreignClass = 0x203               // 3 | nonHeap
    case foreignReferenceType = 0x204       // 4 | nonHeap
    case opaque = 0x300                     // 0 | runtimePrivate | nonHeap
    case tuple = 0x301                      // 1 | runtimePrivate | nonHeap
    case function = 0x302                   // 2 | runtimePrivate | nonHeap
    case existential = 0x303                // 3 | runtimePrivate | nonHeap
    case metatype = 0x304                   // 4 | runtimePrivate | nonHeap
    case objcClassWrapper = 0x305           // 5 | runtimePrivate | nonHeap
    case existentialMetatype = 0x306        // 6 | runtimePrivate | nonHeap
    case extendedExistential = 0x307        // 7 | runtimePrivate | nonHeap
    case heapLocalVariable = 0x400          // 0 | nonType
    case heapGenericLocalVariable = 0x500   // 0 | nonType | runtimePrivate
    case errorObject = 0x501                // 1 | nonType | runtimePrivate
    case task = 0x502                       // 2 | nonType | runtimePrivate
    case job = 0x503                        // 3 | nonType | runtimePrivate
    /// The largest possible non-isa-pointer metadata kind value.
    ///
    /// This is included in the enumeration to prevent against attempts to
    /// exhaustively match metadata kinds. Future Swift runtimes or compilers
    /// may introduce new metadata kinds, so for forward compatibility, the
    /// runtime must tolerate metadata with unknown kinds.
    /// This specific value is not mapped to a valid metadata kind at this time,
    /// however.
    case unknown = 0x7FF
    
    init(_ type: Any.Type) {
        let rawValue = _metadataKind(type)
        self = _MetadataKind(rawValue: rawValue) ?? .unknown
    }
}
