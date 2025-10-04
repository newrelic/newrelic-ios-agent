//
//  NRMaskingExtractor.swift
//  Agent
//
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation
import SwiftUI

/// Extracts NRMaskingState from SwiftUI views using deep reflection
@available(iOS 13.0, tvOS 13.0, *)
public struct NRMaskingExtractor {

    /// Attempts to extract the masking state from a SwiftUI view's environment
    /// - Parameters:
    ///   - view: The SwiftUI view to inspect
    ///   - maxDepth: Maximum recursion depth to prevent infinite loops
    /// - Returns: The masking state if found, nil otherwise
    public static func extractMaskingState(from view: Any, maxDepth: Int = 25) -> NRMaskingState? {
        return _searchForMaskingState(in: view, depth: 0, maxDepth: maxDepth)
    }

    // MARK: - Private Implementation

    private static func _searchForMaskingState(
        in subject: Any,
        depth: Int,
        maxDepth: Int
    ) -> NRMaskingState? {
        guard depth < maxDepth else { return nil }

        let inspector = RunTimeTypeInspector(subject: subject)
        let typeName = String(describing: type(of: subject))

        // Check if this is a ModifiedContent with our NRMaskingViewModifier
        if typeName.contains("ModifiedContent") {
            if let state = _extractFromModifiedContent(inspector: inspector, depth: depth, maxDepth: maxDepth) {
                return state
            }
        }

        // Check if this is the NRMaskingViewModifier itself
        if typeName.contains("NRMaskingViewModifier") {
            if let state = _extractFromMaskingModifier(inspector: inspector) {
                return state
            }
        }

        // Check for environment values
        if typeName.contains("Environment") || typeName.contains("EnvironmentValues") {
            if let state = _extractFromEnvironment(inspector: inspector, typeName: typeName) {
                return state
            }
        }

        // Recursively search children (but prefer modifier over content)
        // First check for 'modifier' child
        if let modifier = inspector.child(.key("modifier")) {
            if let state = _searchForMaskingState(in: modifier, depth: depth + 1, maxDepth: maxDepth) {
                return state
            }
        }

        // Then check other children
        for child in inspector.children {
            // Skip 'modifier' since we already checked it
            if child.label == "modifier" { continue }

            if let state = _searchForMaskingState(in: child.value, depth: depth + 1, maxDepth: maxDepth) {
                return state
            }
        }

        return nil
    }

    private static func _extractFromModifiedContent(
        inspector: RunTimeTypeInspector,
        depth: Int,
        maxDepth: Int
    ) -> NRMaskingState? {
        // ModifiedContent has 'modifier' property which might be our NRMaskingViewModifier
        if let modifier = inspector.child(.key("modifier")) {
            if let state = _searchForMaskingState(in: modifier, depth: depth + 1, maxDepth: maxDepth) {
                return state
            }
        }

        // Also check the content (in case there's a nested modifier)
        if let content = inspector.child(.key("content")) {
            if let state = _searchForMaskingState(in: content, depth: depth + 1, maxDepth: maxDepth) {
                return state
            }
        }

        return nil
    }

    private static func _extractFromMaskingModifier(inspector: RunTimeTypeInspector) -> NRMaskingState? {
        // Look for the 'maskingState' property in NRMaskingViewModifier
        if let maskingStateValue = inspector.child(.key("maskingState")) {
            return _parseNRMaskingState(from: maskingStateValue)
        }

        return nil
    }

    private static func _extractFromEnvironment(
        inspector: RunTimeTypeInspector,
        typeName: String
    ) -> NRMaskingState? {
        // Look for 'nrMaskingState' in environment values
        if let maskingState = inspector.child(.key("nrMaskingState")) {
            return _parseNRMaskingState(from: maskingState)
        }

        // Check for storage property that might contain environment values
        if let storage = inspector.child(.key("storage")) ?? inspector.child(.key("_storage")) {
            let storageInspector = RunTimeTypeInspector(subject: storage)
            if let maskingState = storageInspector.child(.key("nrMaskingState")) {
                return _parseNRMaskingState(from: maskingState)
            }
        }

        return nil
    }

    private static func _parseNRMaskingState(from value: Any) -> NRMaskingState? {
        let inspector = RunTimeTypeInspector(subject: value)
        let typeName = String(describing: type(of: value))

        // Handle Optional<NRMaskingState>
        if typeName.contains("Optional") {
            //if case .optional = inspector.displayStyle {
                // Check if it's .some
                if let unwrapped = inspector.children.first?.value {
                    return _parseNRMaskingState(from: unwrapped)
                }
            //}
            return nil
        }

        // Check if this is actually NRMaskingState enum
        if typeName.contains("NRMaskingState") {
            if case .enum(let caseName) = inspector.displayStyle {
                // Parse enum case
                switch caseName {
                case "masked":
                    return .masked
                case "unmasked":
                    return .unmasked
                case "custom":
                    // Extract associated value (the string identifier)
                    if let firstChild = inspector.children.first?.value as? String {
                        return .custom(firstChild)
                    }
                    return nil
                default:
                    return nil
                }
            }
        }

        return nil
    }

    // MARK: - Legacy Compatibility

    /// Attempts to extract masking state from accessibility identifier (backward compatibility)
    /// This is deprecated and should be replaced with nrMasking modifiers
    public static func extractMaskingStateFromAccessibilityIdentifier(_ identifier: String?) -> NRMaskingState? {
        guard let identifier = identifier else { return nil }

        if identifier == "nr-mask" || identifier.hasSuffix(".nr-mask") {
            return .masked
        }

        if identifier == "nr-unmask" || identifier.hasSuffix(".nr-unmask") {
            return .unmasked
        }

        return nil
    }
}
