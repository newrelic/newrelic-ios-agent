//
//  SwiftUIViewHierarchyRecorder.swift
//  Agent
//
//  Created by Chris Dillard on 9/3/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation
import SwiftUI
import UIKit

@available(iOS 14.0, *)
@MainActor
public class DecompilerDataManager {
    public static let shared = DecompilerDataManager()
    private init() {}

    public private(set) var decompiledViews: [String: DecompiledView] = [:]

    func update(views: [DecompiledView]) {
        
        // print report of waht this update operation will do
        print("[DecompilerDataManager] Updating with \(views.count) views.")
        let newPaths = Set(views.map { $0.path })
        let existingPaths = Set(decompiledViews.keys)
//        let pathsToRemove = existingPaths.subtracting(newPaths)
//        if !pathsToRemove.isEmpty {
//            print("[DecompilerDataManager] Removing \(pathsToRemove.count) views: \(pathsToRemove)")
//        }
        let pathsToAdd = newPaths.subtracting(existingPaths)
        if !pathsToAdd.isEmpty {
           // print("[DecompilerDataManager] Adding \(pathsToAdd.count) new views: \(pathsToAdd)")
        }
        let pathsToUpdate = newPaths.intersection(existingPaths)
        if !pathsToUpdate.isEmpty {
            //print("[DecompilerDataManager] Updating \(pathsToUpdate.count) existing views: \(pathsToUpdate)")
        }
        
        // Build complete snapshot
       // decompiledViews.removeAll()
        
        for view in views {
            decompiledViews[view.path] = view
        }
        // Since we're @MainActor, no DispatchQueue needed
        print("[DecompilerDataManager] Updated with \(views.count) views. Now tracking \(self.decompiledViews.keys.count) views.")
    }
    
    func removeAllDecompiledViews() {
        decompiledViews.removeAll()
    }
}

public struct DecompiledView: Identifiable, Equatable {
    public var id: String { path }
    public let path: String
    public let kind: ClassifiedKind
    public let frame: CGRect
}

@available(iOS 14.0, *)
public final class SwiftUIViewHierarchyRecorder {
    /// A simple structure to hold the deconstructed view information, including its final frame.

    @MainActor public static func decompile(swiftUIRoot: any View) -> [String: DecompiledView] {
        print("[SwiftUIViewHierarchyRecorder] Starting decompilation")

        // Clear any existing data and reset path generation
//        DecompilerDataManager.shared.removeAllDecompiledViews()
//        IntrospectedDataManager.shared.clearAll()
//        PathGenerator.shared.reset()

        // Create a temporary hosting controller to force SwiftUI layout and collect introspection data
        let wrappedView = AnyView(swiftUIRoot.trackable().decompile())
        let hostingController = UIHostingController(rootView: wrappedView)

        // Force a layout pass to trigger preference collection
        hostingController.view.layoutIfNeeded()

        // Allow some time for preference propagation
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))

        let result = DecompilerDataManager.shared.decompiledViews
        print("[SwiftUIViewHierarchyRecorder] Decompilation complete with \(result.count) views")

        // Print parent-child relationships for debugging
        for path in PathGenerator.shared.getAllPaths() {
            if let parent = PathGenerator.shared.getParent(for: path) {
                let children = PathGenerator.shared.getChildren(for: path)
                print("[PathHierarchy] \(path) -> parent: \(parent), children: [\(children.joined(separator: ", "))]")
            }
        }

        return result
    }
}

@available(iOS 14.0, *)
private struct SwiftUIIntrospectionView: View {
    let contentInfo: EnhancedDecompiledView

    var body: some View {
        GeometryReader { geometry in
            Color.clear
                .preference(key: EnhancedDecompilerPreferenceKey.self,
                            value: [self.info(with: geometry)])
        }
    }

    private func info(with geometry: GeometryProxy) -> EnhancedDecompiledView {
        EnhancedDecompiledView(
            path: contentInfo.path,
            parentPath: contentInfo.parentPath,
            kind: contentInfo.kind,
            frame: geometry.frame(in: .global),
            siblingIndex: contentInfo.siblingIndex
        )
    }
}

@available(iOS 14.0, *)
struct TrackableWrapper<Content: View>: View {
    let content: Content
    @Environment(\.decompilerPath) private var parentPath

    @ViewBuilder
    var body: some View {
        // Perform a deep classification to unwrap all modifiers and find the core view.
        let deepClassification = classifyView(content)

        // Generate unique path with parent-child tracking
        let uniquePath = PathGenerator.shared.generateUniquePath(
            basePath: parentPath,
            classification: deepClassification,
            parentPath: parentPath == "ROOT" ? nil : parentPath
        )

        // The isContainer check is now based on the *unwrapped* view kind.
        if ContainerDetector.isContainer(deepClassification) {
            // For containers, we pass down the new path to their children.
            content
                .environment(\.decompilerPath, uniquePath)
                .onAppear {
                   // print("[TrackableWrapper] Container: \(uniquePath)")
                }

        } else {
            // For leaf views, we inject the introspection view alongside it.
            content
                .overlay(SwiftUIIntrospectionView(contentInfo: EnhancedDecompiledView(
                    path: uniquePath,
                    parentPath: parentPath == "ROOT" ? nil : parentPath,
                    kind: deepClassification,
                    frame: .zero, // This frame is temporary; GeometryReader will replace it.
                    siblingIndex: 0 // Will be calculated during collection
                )))
                .onAppear {
                   // print("[TrackableWrapper] Leaf: \(uniquePath)")
                }
        }
    }
}
