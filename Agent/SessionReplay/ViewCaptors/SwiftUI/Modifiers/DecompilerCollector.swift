//
//  DecompilerCollector.swift
//  Agent
//
//  Created by Chris Dillard on 9/16/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import SwiftUI

// Import the LeafPathPreferenceKey from Modifiers.swift

@available(iOS 14.0, *)
struct DecompilerCollector: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onPreferenceChange(EnhancedDecompilerPreferenceKey.self) { allInfo in
                // print("[DecompilerCollector] Received \(allInfo.count) enhanced decompiled views")
                var processedInfos: [DecompiledView] = []

                // Group by parent path to calculate sibling indices
                let groupedByParent = Dictionary(grouping: allInfo, by: { $0.parentPath ?? "ROOT" })

                for (_, siblingInfos) in groupedByParent {
                    let sortedSiblings = siblingInfos.sorted { $0.path < $1.path }

                    for (_, info) in sortedSiblings.enumerated() {
                        processedInfos.append(DecompiledView(
                            path: info.path,
                            kind: info.kind,
                            frame: info.frame
                        ))

                        //print("[DecompilerCollector] Processed: \(info.path) (parent: \(parentPath), sibling: \(index))")
                    }
                }

                Task { @MainActor in
                    DecompilerDataManager.shared.update(views: processedInfos)
                }
            }
            .onPreferenceChange(DecompilerPreferenceKey.self) { allInfo in
                // Fallback for legacy DecompilerPreferenceKey
               // print("[DecompilerCollector] Received \(allInfo.count) legacy decompiled views")
                Task { @MainActor in
                    DecompilerDataManager.shared.update(views: allInfo)
                }
            }
            .onPreferenceChange(LeafPathPreferenceKey.self) { leafPaths in
                // Handle introspected leaf views
                let introspectedViews = leafPaths.compactMap { leafPath -> DecompiledView? in
                    // Try to find matching introspected UIKit data
                    let introspectedDataManager = IntrospectedDataManager.shared

                    // Look for introspected data that might match this leaf path
                    for (_, introspectedData) in introspectedDataManager.introspectedData {
                        if introspectedData.kind.description.contains(leafPath.classification.description.prefix(6)) {
                            // Create enhanced DecompiledView with introspected properties
                            return DecompiledView(
                                path: leafPath.fullPath,
                                kind: introspectedData.kind,
                                frame: leafPath.frame.isEmpty ? introspectedData.frame : leafPath.frame
                            )
                        }
                    }

                    // Fallback to basic leaf path data
                    return DecompiledView(
                        path: leafPath.fullPath,
                        kind: leafPath.classification,
                        frame: leafPath.frame
                    )
                }
                Task { @MainActor in
                    let currentViews = DecompilerDataManager.shared.decompiledViews.values.map { $0 }
                    let allViews = currentViews + introspectedViews
                    DecompilerDataManager.shared.update(views: allViews)
                }
            }
    }
}

@available(iOS 14.0, *)
struct DecompilerPreferenceKey: PreferenceKey {
    typealias Value = [DecompiledView]
    static var defaultValue: [DecompiledView] = []
    static func reduce(value: inout [DecompiledView], nextValue: () -> [DecompiledView]) {
        value.append(contentsOf: nextValue())
    }
}

@available(iOS 14.0, *)
struct EnhancedDecompilerPreferenceKey: PreferenceKey {
    typealias Value = [EnhancedDecompiledView]
    static var defaultValue: [EnhancedDecompiledView] = []
    static func reduce(value: inout [EnhancedDecompiledView], nextValue: () -> [EnhancedDecompiledView]) {
        value.append(contentsOf: nextValue())
    }
}

private struct DecompilerPathKey: EnvironmentKey {
    static let defaultValue: String = "ROOT"
}

@available(iOS 14.0, *)
extension EnvironmentValues {
    var decompilerPath: String {
        get { self[DecompilerPathKey.self] }
        set { self[DecompilerPathKey.self] = newValue }
    }
}

