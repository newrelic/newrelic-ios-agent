//
//  PathGenerator.swift
//  Agent
//
//  Created by Chris Dillard on 9/16/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation
import SwiftUI

@available(iOS 14.0, *)
@MainActor
public class PathGenerator {
    public static let shared = PathGenerator()
    private init() {}

    private var pathCounters: [String: Int] = [:]
    private var parentChildMap: [String: String] = [:] // child -> parent
    private var childrenMap: [String: [String]] = [:] // parent -> [children]

    public func reset() {
        pathCounters.removeAll()
        parentChildMap.removeAll()
        childrenMap.removeAll()
    }

    public func generateUniquePath(basePath: String, classification: ClassifiedKind, parentPath: String?) -> String {
        let baseIdentifier = classification.description
        let candidatePath = "\(basePath)/\(baseIdentifier)"

        // Check if this exact path already exists
        let counter = pathCounters[candidatePath, default: 0]
        pathCounters[candidatePath] = counter + 1

        let uniquePath: String
        if counter == 0 {
            uniquePath = candidatePath
        } else {
            uniquePath = "\(candidatePath)[\(counter)]"
        }

        // Track parent-child relationships
        if let parentPath = parentPath {
            parentChildMap[uniquePath] = parentPath
            childrenMap[parentPath, default: []].append(uniquePath)
        }

        print("[PathGenerator] Generated path: \(uniquePath) (parent: \(parentPath ?? "ROOT"))")
        return uniquePath
    }

    public func getParent(for path: String) -> String? {
        return parentChildMap[path]
    }

    public func getChildren(for path: String) -> [String] {
        return childrenMap[path] ?? []
    }

    public func getAllPaths() -> [String] {
        return Array(pathCounters.keys)
    }
}

@available(iOS 14.0, *)
public struct EnhancedDecompiledView: Identifiable, Equatable {
    public var id: String { path }
    public let path: String
    public let parentPath: String?
    public let kind: ClassifiedKind
    public let frame: CGRect
    public let siblingIndex: Int

    public init(path: String, parentPath: String? = nil, kind: ClassifiedKind, frame: CGRect, siblingIndex: Int = 0) {
        self.path = path
        self.parentPath = parentPath
        self.kind = kind
        self.frame = frame
        self.siblingIndex = siblingIndex
    }
}