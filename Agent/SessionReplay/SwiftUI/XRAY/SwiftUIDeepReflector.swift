//
//  SwiftUIDeepReflector.swift
//  Agent
//
//  Deep recursive reflection for extracting SwiftUI view modifiers
//  including accessibility identifiers from private/internal structures.
//
//

import Foundation
import SwiftUI

public struct SwiftUIDeepReflector {

    // MARK: - Result Types

    public struct AccessibilityInfo {
        public let identifier: String?
        public let label: String?
        public let hint: String?
        public let traits: [String]

        public var hasIdentifier: Bool {
            identifier != nil && !(identifier?.isEmpty ?? true)
        }
    }

    // MARK: - Public API

    /// Recursively searches for accessibility identifier in a SwiftUI view hierarchy
    /// - Parameter view: The view to inspect (should be Any to accept SwiftUI views)
    /// - Parameter maxDepth: Maximum recursion depth to prevent infinite loops (default: 20)
    /// - Returns: AccessibilityInfo if found, nil otherwise
    public static func extractAccessibilityInfo(from view: Any, maxDepth: Int = 20) -> AccessibilityInfo? {
        return _searchForAccessibilityInfo(in: view, depth: 0, maxDepth: maxDepth)
    }

    /// Extract accessibility identifier only (convenience method)
    public static func extractAccessibilityIdentifier(from view: Any, maxDepth: Int = 20) -> String? {
        return extractAccessibilityInfo(from: view, maxDepth: maxDepth)?.identifier
    }

    // MARK: - Private Implementation

    private static func _searchForAccessibilityInfo(
        in subject: Any,
        depth: Int,
        maxDepth: Int
    ) -> AccessibilityInfo? {
        // Prevent infinite recursion
        guard depth < maxDepth else { return nil }

        let inspector = RunTimeTypeInspector(subject: subject)
        let typeName = String(describing: type(of: subject))

        // DEBUG: Print hierarchy at each level
        let indent = String(repeating: "  ", count: depth)
        NRLOG_DEBUG("\(indent)[\(depth)] Inspecting: \(typeName)")
        NRLOG_DEBUG("\(indent)    DisplayStyle: \(inspector.displayStyle)")
        NRLOG_DEBUG("\(indent)    Children count: \(inspector.children.count)")

        // Print all children with their labels and types
        for (index, child) in inspector.children.enumerated() {
            let childType = String(describing: type(of: child.value))
            let label = child.label ?? "<unlabeled-\(index)>"
            NRLOG_DEBUG("\(indent)    [\(index)] \(label): \(childType)")

            // If it's a string, print the value
            if let stringValue = child.value as? String {
                NRLOG_DEBUG("\(indent)        -> String value: \"\(stringValue)\"")
            }
        }

        // Check if this is ModifiedContent
        if typeName.contains("ModifiedContent") {
            NRLOG_DEBUG("\(indent)    ⚡ Found ModifiedContent!")
            if let result = _inspectModifiedContent(inspector: inspector, depth: depth, maxDepth: maxDepth) {
                NRLOG_DEBUG("\(indent)    ✅ Extracted accessibility from ModifiedContent")
                return result
            }
        }

        // Check for direct AccessibilityAttachmentModifier
        if typeName.contains("AccessibilityAttachmentModifier") {
            NRLOG_DEBUG("\(indent)    ⚡ Found AccessibilityAttachmentModifier!")
            if let result = _extractFromAccessibilityModifier(inspector: inspector) {
                NRLOG_DEBUG("\(indent)    ✅ Extracted accessibility from modifier")
                return result
            }
        }

        // Check for other accessibility-related types
        if typeName.contains("Accessibility") {
            NRLOG_DEBUG("\(indent)    ⚡ Found Accessibility-related type!")
            if let result = _extractFromAccessibilityType(inspector: inspector, typeName: typeName) {
                NRLOG_DEBUG("\(indent)    ✅ Extracted from accessibility type")
                return result
            }
        }

        // Recursively search children
        for (index, child) in inspector.children.enumerated() {
            let label = child.label ?? "<unlabeled-\(index)>"
            NRLOG_DEBUG("\(indent)    🔍 Recursing into child[\(index)] '\(label)'...")
            if let result = _searchForAccessibilityInfo(in: child.value, depth: depth + 1, maxDepth: maxDepth) {
                NRLOG_DEBUG("\(indent)    ✅ Found in child[\(index)] '\(label)'")
                return result
            }
        }

        // Check superclass if available
        if let superMirror = inspector.superclassMirror {
            NRLOG_DEBUG("\(indent)    🔍 Checking superclass...")
            for child in superMirror.children {
                if let result = _searchForAccessibilityInfo(in: child.value, depth: depth + 1, maxDepth: maxDepth) {
                    NRLOG_DEBUG("\(indent)    ✅ Found in superclass")
                    return result
                }
            }
        }

        NRLOG_DEBUG("\(indent)    ❌ No accessibility info found at this level")
        return nil
    }

    private static func _inspectModifiedContent(
        inspector: RunTimeTypeInspector,
        depth: Int,
        maxDepth: Int
    ) -> AccessibilityInfo? {
        // ModifiedContent typically has 'content' and 'modifier' properties
        let indent = String(repeating: "  ", count: depth)
        NRLOG_DEBUG("\(indent)    📦 Inspecting ModifiedContent structure:")

        // First check the modifier
        if let modifier = inspector.child(.key("modifier")) {
            let modifierType = String(describing: type(of: modifier))
            NRLOG_DEBUG("\(indent)        modifier: \(modifierType)")
            if let result = _searchForAccessibilityInfo(in: modifier, depth: depth + 1, maxDepth: maxDepth) {
                return result
            }
        } else {
            NRLOG_DEBUG("\(indent)        ❌ No 'modifier' child found")
        }

        // Then check the content
        if let content = inspector.child(.key("content")) {
            let contentType = String(describing: type(of: content))
            NRLOG_DEBUG("\(indent)        content: \(contentType)")
            if let result = _searchForAccessibilityInfo(in: content, depth: depth + 1, maxDepth: maxDepth) {
                return result
            }
        } else {
            NRLOG_DEBUG("\(indent)        ❌ No 'content' child found")
        }

        return nil
    }

    private static func _extractFromAccessibilityModifier(inspector: RunTimeTypeInspector) -> AccessibilityInfo? {
        // AccessibilityAttachmentModifier typically contains:
        // - identifier (String)
        // - label (Text)
        // - hint (Text)
        // - traits (AccessibilityTraits)

        NRLOG_DEBUG("        🔍 Extracting from AccessibilityAttachmentModifier")
        NRLOG_DEBUG("        Children count: \(inspector.children.count)")

        // Log all children
        for (index, child) in inspector.children.enumerated() {
            let childType = String(describing: type(of: child.value))
            let label = child.label ?? "<unlabeled-\(index)>"
            NRLOG_DEBUG("        [\(index)] \(label): \(childType)")
            if let stringValue = child.value as? String {
                NRLOG_DEBUG("            -> \"\(stringValue)\"")
            }
        }

        var identifier: String?
        var label: String?
        var hint: String?
        var traits: [String] = []

        // Try to find identifier by various possible property names
        let identifierKeys = ["identifier", "id", "_identifier", "accessibilityIdentifier"]
        for key in identifierKeys {
            NRLOG_DEBUG("        Trying key: '\(key)'")
            if let value = inspector.child(.key(key)) {
                NRLOG_DEBUG("        ✅ Found value for '\(key)': \(type(of: value))")
                identifier = _extractString(from: value)
                if identifier != nil {
                    NRLOG_DEBUG("        ✅ Extracted identifier: '\(identifier!)'")
                    break
                }
            }
        }

        // Try to extract label
        if let labelValue = inspector.child(.key("label")) ?? inspector.child(.key("_label")) {
            label = _extractString(from: labelValue)
            NRLOG_DEBUG("        Label: \(label ?? "nil")")
        }

        // Try to extract hint
        if let hintValue = inspector.child(.key("hint")) ?? inspector.child(.key("_hint")) {
            hint = _extractString(from: hintValue)
            NRLOG_DEBUG("        Hint: \(hint ?? "nil")")
        }

        // Try to extract traits
        if let traitsValue = inspector.child(.key("traits")) ?? inspector.child(.key("_traits")) {
            traits = _extractTraits(from: traitsValue)
            NRLOG_DEBUG("        Traits: \(traits)")
        }

        // If we found anything, return it
        if identifier != nil || label != nil || hint != nil || !traits.isEmpty {
            NRLOG_DEBUG("        ✅ Returning AccessibilityInfo")
            return AccessibilityInfo(
                identifier: identifier,
                label: label,
                hint: hint,
                traits: traits
            )
        }

        NRLOG_DEBUG("        ❌ No accessibility info extracted")
        return nil
    }

    private static func _extractFromAccessibilityType(
        inspector: RunTimeTypeInspector,
        typeName: String
    ) -> AccessibilityInfo? {
        // Handle various accessibility types

        // Check for storage property which might contain the actual data
        if let storage = inspector.child(.key("storage")) ?? inspector.child(.key("_storage")) {
            let storageInspector = RunTimeTypeInspector(subject: storage)

            // Try common property names
            if let identifier = storageInspector.child(.key("identifier")) {
                if let idString = _extractString(from: identifier) {
                    return AccessibilityInfo(identifier: idString, label: nil, hint: nil, traits: [])
                }
            }
        }

        // Fallback: search all children for string values that might be identifiers
        for child in inspector.children {
            if let label = child.label, label.contains("identifier") || label.contains("id") {
                if let idString = _extractString(from: child.value) {
                    return AccessibilityInfo(identifier: idString, label: nil, hint: nil, traits: [])
                }
            }
        }

        return nil
    }

    // MARK: - Helper Methods

    private static func _extractString(from value: Any) -> String? {
        // Direct string
        if let string = value as? String {
            return string
        }

        // Optional string
        if let optional = value as? Optional<String> {
            switch optional {
            case .some(let string):
                return string
            case .none:
                return nil
            }
        }

        // Check if it's a Text view (SwiftUI)
        let typeName = String(describing: type(of: value))
        if typeName.contains("Text") {
            return _extractStringFromText(value)
        }

        // Try reflection as last resort
        let inspector = RunTimeTypeInspector(subject: value)

        // Look for common string storage properties
        let stringKeys = ["storage", "_storage", "value", "_value", "string", "_string"]
        for key in stringKeys {
            if let child = inspector.child(.key(key)) {
                if let string = child as? String {
                    return string
                }
                // Recursive one level
                let childInspector = RunTimeTypeInspector(subject: child)
                for innerChild in childInspector.children {
                    if let string = innerChild.value as? String {
                        return string
                    }
                }
            }
        }

        return nil
    }

    private static func _extractStringFromText(_ textValue: Any) -> String? {
        let inspector = RunTimeTypeInspector(subject: textValue)

        // Text typically has a 'storage' property containing the actual string
        if let storage = inspector.child(.key("storage")) ?? inspector.child(.key("_storage")) {
            let storageInspector = RunTimeTypeInspector(subject: storage)

            // Check for verbatim string case (most common)
            if let verbatim = storageInspector.child(.key("verbatim")) {
                if let string = verbatim as? String {
                    return string
                }
            }

            // Check enum cases
            if case .enum(let caseName) = storageInspector.displayStyle {
                if caseName.contains("verbatim") {
                    // Get the associated value
                    if let firstChild = storageInspector.children.first {
                        return _extractString(from: firstChild.value)
                    }
                }
            }
        }

        return nil
    }

    private static func _extractTraits(from value: Any) -> [String] {
        var traits: [String] = []
        let inspector = RunTimeTypeInspector(subject: value)

        // AccessibilityTraits is typically an OptionSet
        // We can try to decode known trait values
        if let rawValue = value as? UInt64 {
            let knownTraits: [(UInt64, String)] = [
                (1 << 0, "button"),
                (1 << 1, "link"),
                (1 << 2, "image"),
                (1 << 3, "selected"),
                (1 << 4, "playsSound"),
                (1 << 5, "keyboardKey"),
                (1 << 6, "staticText"),
                (1 << 7, "summaryElement"),
                (1 << 8, "notEnabled"),
                (1 << 9, "updatesFrequently"),
                (1 << 10, "searchField"),
                (1 << 11, "startsMediaSession"),
                (1 << 12, "adjustable"),
                (1 << 13, "allowsDirectInteraction"),
                (1 << 14, "causesPageTurn"),
                (1 << 15, "header"),
            ]

            for (mask, name) in knownTraits {
                if rawValue & mask != 0 {
                    traits.append(name)
                }
            }
        }

        return traits
    }

    // MARK: - Debug Helpers

    /// Prints the entire view hierarchy for debugging purposes
    public static func debugPrintHierarchy(of view: Any, maxDepth: Int = 10) {
        _debugPrint(subject: view, depth: 0, maxDepth: maxDepth, prefix: "")
    }

    /// Prints ONLY the top-level structure without recursion (compact view)
    public static func debugPrintTopLevel(of view: Any, label: String = "Subject") {
        let inspector = RunTimeTypeInspector(subject: view)
        let typeName = String(describing: type(of: view))

        NRLOG_DEBUG("═══════════════════════════════════════════")
        NRLOG_DEBUG("📋 \(label)")
        NRLOG_DEBUG("Type: \(typeName)")
        NRLOG_DEBUG("DisplayStyle: \(inspector.displayStyle)")
        NRLOG_DEBUG("Children: \(inspector.children.count)")
        NRLOG_DEBUG("───────────────────────────────────────────")

        for (index, child) in inspector.children.enumerated() {
            let childType = String(describing: type(of: child.value))
            let childLabel = child.label ?? "<unlabeled-\(index)>"
            NRLOG_DEBUG("  [\(index)] \(childLabel)")
            NRLOG_DEBUG("      Type: \(childType)")

            if let stringValue = child.value as? String {
                NRLOG_DEBUG("      Value: \"\(stringValue)\"")
            }

            // Show immediate children count if it's a struct/class
            let childInspector = RunTimeTypeInspector(subject: child.value)
            if childInspector.children.count > 0 {
                NRLOG_DEBUG("      Children: \(childInspector.children.count)")
            }
        }

        if let superMirror = inspector.superclassMirror {
            NRLOG_DEBUG("───────────────────────────────────────────")
            NRLOG_DEBUG("Superclass children: \(superMirror.children.count)")
        }

        NRLOG_DEBUG("═══════════════════════════════════════════")
    }

    private static func _debugPrint(subject: Any, depth: Int, maxDepth: Int, prefix: String) {
        guard depth < maxDepth else { return }

        let inspector = RunTimeTypeInspector(subject: subject)
        let typeName = String(describing: type(of: subject))

        print("\(prefix)[\(depth)] \(typeName)")

        for child in inspector.children {
            let label = child.label ?? "<unlabeled>"
            let childType = String(describing: type(of: child.value))
            print("\(prefix)  • \(label): \(childType)")

            // Recursively print children
            _debugPrint(subject: child.value, depth: depth + 1, maxDepth: maxDepth, prefix: prefix + "    ")
        }
    }
}

// MARK: - Convenience Extensions

extension SwiftUIDeepReflector {
    /// Attempts to extract masking preference from accessibility identifier
    /// Returns true if identifier contains "nr-mask", false if "nr-unmask", nil otherwise
    public static func extractMaskingPreference(from view: Any) -> Bool? {
        guard let identifier = extractAccessibilityIdentifier(from: view) else {
            return nil
        }

        if identifier == "nr-mask" || identifier.hasSuffix(".nr-mask") {
            return true
        }

        if identifier == "nr-unmask" || identifier.hasSuffix(".nr-unmask") {
            return false
        }

        return nil
    }
}
