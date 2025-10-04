//
//  Reflector2.swift
//  Agent
//
//  Created by Chris Dillard on 10/2/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import SwiftUI

/// 🔬 A framework for deeply reflecting on a SwiftUI View to extract its modifier chain.
///
/// **How It Works - Reading the Whole Hierarchy Including RootView:**
///
/// 1. **Entry Point**: Start with `analyze(view:)` which accepts any SwiftUI View.
///    - This view is typically obtained from `UIHostingController.rootView` (see below).
///    - The RootView is the top-level SwiftUI view that the hosting controller manages.
///
/// 2. **Initialization**: Create an empty dictionary to store ID -> Modifiers associations.
///    - Initialize with a default root ID (AnyHashable(0)) to track modifiers without explicit IDs.
///
/// 3. **Traversal**: Call `traverse(view:currentID:associations:accumulating:)` recursively.
///    - Each view is inspected using Swift's Mirror API to access its internal structure.
///    - The function peels away layers of view wrappers to discover modifiers and child views.
///
/// 4. **Reading Hierarchy from RootView**:
///    - The traversal starts at the RootView and works inward through nested ModifiedContent wrappers.
///    - Each ModifiedContent represents one .modifier() call applied to a view.
///    - Structure: ModifiedContent<ModifiedContent<...<BaseView, Modifier1>, Modifier2>, Modifier3>
///    - The algorithm unwraps each layer, extracting modifiers and continuing to the inner content.
///
/// 5. **ID Tracking**: When an IDView wrapper is found (created by .id()), update currentID.
///    - All subsequent modifiers are associated with this new ID until another IDView is encountered.
///
/// 6. **Container Handling**: Works with VStack, HStack, ZStack, and other containers.
///    - The commented-out code shows potential for traversing into container children.
///    - Current implementation focuses on modifier chain extraction.
///
/// 7. **AnyView Unwrapping**: Special handling for type-erased AnyView wrappers.
///    - Drills into storage to find the actual underlying view and continues traversal.
///
/// **How to Get RootView**:
/// - Use `getSwiftUIView(from:)` function (defined below) with any UIView in the hierarchy.
/// - It walks the responder chain to find the UIHostingController.
/// - The hosting controller's `rootView` property contains the top-level SwiftUI view.
/// - Pass this rootView to `DeepReflection.analyze(view:)` to scan the entire hierarchy.
///
@available(iOS 13.0, tvOS 13.0, *)
public enum DeepReflection {
    
    /// Combined reflection helper - uses BOTH Mirror and RunTimeTypeInspector
    /// This maximizes our ability to find hidden properties and views
    private static func combinedReflect(on subject: Any) -> (mirror: Mirror, inspector: RunTimeTypeInspector, allChildren: [(label: String?, value: Any)]) {
        
        let mirror = Mirror(reflecting: subject)
        let inspector = RunTimeTypeInspector(subject: subject)
        
        // Combine children from both sources
        var allChildren: [(label: String?, value: Any)] = []
        
        // Add Mirror children
        for child in mirror.children {
            allChildren.append((child.label, child.value))
        }
        
        // Add XRAY children that Mirror might have missed
        for child in inspector.children {
            // Only add if not already present (check by label)
            if !allChildren.contains(where: { $0.label == child.label && child.label != nil }) {
                allChildren.append((child.label, child.value))
            }
        }
        
        return (mirror, inspector, allChildren)
    }
    
    /// Helper function to extract all details from a ViewModifier
    /// Returns a dictionary with all property names and values
    public static func extractModifierDetails(modifier: any ViewModifier) -> [String: Any] {
        var details: [String: Any] = [:]
        
        // Get type
        details["_type"] = String(describing: type(of: modifier))
        
        // Extract via Mirror
        let mirror = Mirror(reflecting: modifier)
        for child in mirror.children {
            let key = child.label ?? "unlabeled"
            details[key] = child.value
        }
        
        // Extract via XRAY
        let inspector = RunTimeTypeInspector(subject: modifier)
        for child in inspector.children {
            let key = child.label ?? "unlabeled"
            if details[key] == nil { // Don't overwrite Mirror data
                details[key] = child.value
            }
        }
        
        return details
    }
    
    /// Helper function to dump the complete structure of any view for debugging
    /// This is useful when encountering unknown view types like RootView
    
    /// Attempts to access UIHostingController's internal view storage
    /// This may contain materialized views that aren't accessible through normal reflection
    private static func tryAccessHostingControllerInternals(from view: any View) -> [any View] {
        print("\n🎯 [HostingController] Attempting to access UIHostingController internals...")
        
        var foundViews: [any View] = []
        
        // Try to get the hosting controller by searching responder chain
        // This is a best-effort attempt - might not work in all contexts
        
        // Use Mirror to deeply inspect the view for any UIHostingController references
        let viewMirror = Mirror(reflecting: view)
        print("🎯 [HostingController] Searching view structure for UIHostingController references...")
        
        func searchForHostingController(in value: Any, path: String, depth: Int) {
            if depth > 8 { return }
            
            // Check if this is a UIHostingController
            let valueType = type(of: value)
            let valueTypeName = String(describing: valueType)
            
            if valueTypeName.contains("UIHostingController") {
                print("🎯 [HostingController] ✅ Found UIHostingController at \(path)!")
                
                // Deep inspect the hosting controller
                let hcMirror = Mirror(reflecting: value)
                print("🎯 [HostingController] Inspecting controller internals...")
                
                for child in hcMirror.children {
                    let label = child.label ?? "<unlabeled>"
                    let childType = type(of: child.value)
                    print("🎯 [HostingController]   [\(label)]: \(childType)")
                    
                    // Look for view storage properties
                    if label.contains("view") || label.contains("content") ||
                        label.contains("host") || label.contains("root") ||
                        label == "_graph" || label == "graph" {
                        print("🎯 [HostingController]     └─ Interesting property! Inspecting deeper...")
                        
                        if let childView = child.value as? any View {
                            print("🎯 [HostingController]     ✅ IS A VIEW!")
                            foundViews.append(childView)
                        } else {
                            // Go deeper
                            let deepMirror = Mirror(reflecting: child.value)
                            for deepChild in deepMirror.children {
                                if let deepView = deepChild.value as? any View {
                                    print("🎯 [HostingController]       ✅ Found View: \(deepChild.label ?? "?")")
                                    foundViews.append(deepView)
                                }
                            }
                        }
                    }
                }
            }
            
            // Continue searching
            let mirror = Mirror(reflecting: value)
            for child in mirror.children {
                let label = child.label ?? "<unlabeled>"
                searchForHostingController(in: child.value, path: "\(path).\(label)", depth: depth + 1)
            }
        }
        
        searchForHostingController(in: view, path: "rootView", depth: 0)
        
        print("🎯 [HostingController] Found \(foundViews.count) additional view(s) in hosting controller")
        return foundViews
    }
    
    /// Analyzes an entire view hierarchy, extracting all modifiers and
    /// associating them with the nearest preceding `.id()` tag.
    ///
    /// **Traversal Flow**:
    /// 1. Accepts the rootView (top-level SwiftUI view from UIHostingController)
    /// 2. Initializes tracking structures (associations dictionary, modifiers array)
    /// 3. Begins recursive descent through the view tree starting from rootView
    /// 4. Each level of nesting is unwrapped and inspected for modifiers
    /// 5. Returns a complete map of all IDs to their associated modifiers
    ///
    /// **Example Hierarchy**:
    /// ```
    /// RootView (from UIHostingController.rootView)
    ///   └─ ModifiedContent (background modifier)
    ///       └─ ModifiedContent (padding modifier)
    ///           └─ IDView (id: "myView")
    ///               └─ ModifiedContent (foregroundColor modifier)
    ///                   └─ Text("Hello")
    /// ```
    /// Result: ["myView": [foregroundColor modifier]]
    ///
    /// - Parameter view: The SwiftUI View instance to inspect (typically rootView from UIHostingController).
    /// - Returns: A dictionary where keys are IDs and values are the modifiers applied.
    public static func analyze(view: any View) -> [AnyHashable: [any ViewModifier]] {
        print("\n🔬 [DeepReflection] ========== STARTING ANALYSIS ==========")
        print("🔬 [DeepReflection] RootView type: \(type(of: view))")
        
        // Try to access UIHostingController internals for additional views
        let additionalViews = tryAccessHostingControllerInternals(from: view)
        
        var associations: [AnyHashable: [any ViewModifier]] = [:]
        // Start the traversal with a default "root" ID (AnyHashable(0)).
        // This catches any modifiers applied before the first .id() is encountered.
        var modifiers: [any ViewModifier] = []
        
        // Start the recursive traversal with the initial view (the RootView).
        // This begins unwrapping the hierarchy layer by layer.
        traverse(view: view, currentID: AnyHashable(0), associations: &associations, accumulating: &modifiers, depth: 0)
        
        // Also traverse any additional views found in UIHostingController
        print("\n🔬 [DeepReflection] Traversing \(additionalViews.count) additional view(s) from UIHostingController...")
        for (idx, additionalView) in additionalViews.enumerated() {
            print("🔬 [DeepReflection] Additional view[\(idx)]: \(type(of: additionalView))")
            traverse(view: additionalView, currentID: AnyHashable(0), associations: &associations, accumulating: &modifiers, depth: 0)
        }
        
        print("\n🔬 [DeepReflection] ========== ANALYSIS COMPLETE ==========")
        print("🔬 [DeepReflection] Total unique IDs found: \(associations.keys.count)")
        print("🔬 [DeepReflection] Total modifiers found: \(modifiers.count)")
        
        print("\n🔬 [DeepReflection] ========== DETAILED MODIFIER REPORT ==========")
        for (id, mods) in associations.sorted(by: { String(describing: $0.key) < String(describing: $1.key) }) {
            print("🔬 [DeepReflection] 📌 ID: '\(id)' -> \(mods.count) modifier(s)")
            for (idx, modifier) in mods.enumerated() {
                let modType = type(of: modifier)
                print("🔬 [DeepReflection]   [\(idx)] Type: \(modType)")
                
                // Extract all details
                let details = extractModifierDetails(modifier: modifier)
                if details.count > 1 { // More than just _type
                    print("🔬 [DeepReflection]       Properties:")
                    for (key, value) in details.sorted(by: { $0.key < $1.key }) {
                        if key != "_type" {
                            let valueStr = String(describing: value)
                            let valueType = type(of: value)
                            print("🔬 [DeepReflection]         • \(key): \(valueType) = \(valueStr)")
                        }
                    }
                } else {
                    print("🔬 [DeepReflection]       (No extractable properties)")
                }
            }
            print("🔬 [DeepReflection]")
        }
        print("🔬 [DeepReflection] ==========================================\n")
        
        return associations
    }
    
    
    /// **The Core Traversal Engine**: Recursively walks through the SwiftUI view hierarchy.
    ///
    /// **How It Reads the Hierarchy**:
    /// 1. **Reflection**: Uses Mirror(reflecting:) to inspect the view's internal structure
    /// 2. **Type Detection**: Checks the runtime type name to determine view wrapper type
    /// 3. **Layer Peeling**: Unwraps each wrapper type to access inner content:
    ///    - IDView: Updates the current ID and continues with inner content
    ///    - ModifiedContent: Extracts the modifier, stores it, then recurses into content
    ///    - AnyView: Drills into storage to find the real view
    /// 4. **Association**: Links each discovered modifier with the current ID
    /// 5. **Recursion**: Continues inward until reaching a base view (Text, Image, etc.)
    ///
    /// **View Wrapper Structure**:
    /// SwiftUI wraps views in layers. Each .modifier() creates a ModifiedContent wrapper:
    /// - ModifiedContent has two properties: 'content' (inner view) and 'modifier' (the modifier)
    /// - Reading the hierarchy means: extract modifier → recurse into content → repeat
    /// - This continues from the RootView down to the innermost primitive view
    ///
    /// **Example Walk-through**:
    /// Starting with: `Text("Hi").padding().background(Color.blue).id("myID")`
    /// 1. Encounter IDView with id="myID" → update currentID to "myID"
    /// 2. Recurse into content → find ModifiedContent with background modifier
    /// 3. Store background modifier with ID "myID"
    /// 4. Recurse into content → find ModifiedContent with padding modifier
    /// 5. Store padding modifier with ID "myID"
    /// 6. Recurse into content → reach Text("Hi") (base view, stop)
    ///
    /// - Parameters:
    ///   - view: The current view object (as `Any`) being inspected in this recursion level.
    ///   - currentID: The active ID to associate modifiers with (from most recent .id() call).
    ///   - associations: Dictionary storing ID → [Modifiers] mappings (modified in-place).
    ///   - modifiers: Array accumulating all modifiers found (modified in-place).
    ///   - depth: Current recursion depth for indented logging.
    private static func traverse(view: Any, currentID: AnyHashable, associations: inout [AnyHashable: [any ViewModifier]], accumulating modifiers: inout [any ViewModifier], depth: Int) {
        // Get the runtime type name of the current view object.
        // This tells us what kind of wrapper we're dealing with (ModifiedContent, IDView, etc.)
        let viewTypeName = String(describing: type(of: view))
        
        // Create indentation based on depth for readable logging
        let indent = String(repeating: "  ", count: depth)
        
        print("\(indent)🔍 [Traverse] Depth \(depth) | Type: \(viewTypeName) | CurrentID: \(currentID)")
        
        if viewTypeName.starts(with: "ModifiedContent<ModifiedContent<ModifiedContent<ModifiedContent<ModifiedContent<ModifiedContent<ModifiedContent<ModifiedContent<ModifiedContent<ResolvedList<Never>") {
            print("found the gnarly ModifiedContent")
            
        }
        
        // **Use BOTH Mirror and XRAY for maximum coverage**
        let (mirror, inspector, allChildren) = combinedReflect(on: view)
        
        print("\(indent)📊 [Reflection] Mirror: \(mirror.children.count) children, XRAY: \(inspector.children.count) children")
        print("\(indent)📊 [Reflection] Combined: \(allChildren.count) total unique children")
        print("\(indent)📊 [XRAY] DisplayStyle: \(inspector.displayStyle)")
        
        // Log all unique children found by combined reflection
        for (index, child) in allChildren.enumerated() {
            let label = child.label ?? "<unlabeled>"
            let childType = type(of: child.value)
            print("\(indent)📊 [Combined]   Child[\(index)]: '\(label)' -> \(childType)")
        }
        
        // **Case 0: RootView Detection** - Special handling for RootView structures
        // RootView is often the top-level view type from UIHostingController.rootView
        // It may contain the actual view hierarchy we need to traverse
        if viewTypeName.contains("RootView") {
            print("\(indent)🌳 [RootView] ================================================")
            print("\(indent)🌳 [RootView] DETECTED RootView type: \(viewTypeName)")
            print("\(indent)🌳 [RootView] ================================================")
            
            // First, dump the complete structure using our helper
            print("\(indent)🌳 [RootView] === COMPLETE STRUCTURE DUMP ===")
            //dumpViewStructure(view: view, label: "RootView", depth: depth)
            print("\(indent)🌳 [RootView] === END STRUCTURE DUMP ===\n")
            
            // Use XRAY to deeply inspect RootView structure
            print("\(indent)🌳 [RootView] Using XRAY to inspect RootView structure...")
            print("\(indent)🌳 [RootView] DisplayStyle: \(inspector.displayStyle)")
            print("\(indent)🌳 [RootView] Total children: \(inspector.children.count)")
            
            // Log ALL children with detailed information
            print("\(indent)🌳 [RootView] === Detailed Children Analysis ===")
            for (index, child) in inspector.children.enumerated() {
                let label = child.label ?? "<unlabeled>"
                let childType = type(of: child.value)
                let childTypeName = String(describing: childType)
                print("\(indent)🌳 [RootView]   Child[\(index)]: label='\(label)' type=\(childTypeName)")
                
                // Try to inspect the child further with XRAY
                let childInspector = RunTimeTypeInspector(subject: child.value)
                print("\(indent)🌳 [RootView]     └─ DisplayStyle: \(childInspector.displayStyle)")
                print("\(indent)🌳 [RootView]     └─ Has \(childInspector.children.count) children")
                
                // Check if child is a View
                if let childAsView = child.value as? any View {
                    print("\(indent)🌳 [RootView]     └─ ✅ IS a View - can traverse!")
                } else {
                    print("\(indent)🌳 [RootView]     └─ ⚠️  NOT a View")
                }
            }
            
            // Try standard property names that RootView might have
            print("\(indent)🌳 [RootView] === Attempting Standard Property Extraction ===")
            let standardProps = ["value", "content", "body", "rootView", "wrappedValue", "some", "base"]
            
            for propName in standardProps {
                if let propValue = mirror.descendant(propName) {
                    let propType = type(of: propValue)
                    print("\(indent)🌳 [RootView]   Found '\(propName)': \(propType)")
                    
                    if let viewValue = propValue as? any View {
                        print("\(indent)🌳 [RootView]   ✅ '\(propName)' is a View! Traversing...")
                        traverse(view: viewValue, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                        print("\(indent)🌳 [RootView] ================================================")
                        return
                    }
                } else {
                    print("\(indent)🌳 [RootView]   Property '\(propName)': NOT FOUND")
                }
            }
            
            // Try using XrayDecoder to extract properties
            print("\(indent)🌳 [RootView] === Using XrayDecoder for Deep Extraction ===")
            let xrayDecoder = XrayDecoder(subject: view)
            
            // Try each standard path with XrayDecoder
            for propName in standardProps {
                if let extracted = xrayDecoder.childIfPresent(.key(propName)) {
                    let extractedType = type(of: extracted)
                    print("\(indent)🌳 [RootView]   XRAY extracted '\(propName)': \(extractedType)")
                    
                    if let viewValue = extracted as? any View {
                        print("\(indent)🌳 [RootView]   ✅ XRAY '\(propName)' is a View! Traversing...")
                        traverse(view: viewValue, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                        print("\(indent)🌳 [RootView] ================================================")
                        return
                    }
                }
            }
            
            // Try traversing all children that are Views
            print("\(indent)🌳 [RootView] === Attempting to Traverse All View Children ===")
            var foundView = false
            for (index, child) in inspector.children.enumerated() {
                if let childView = child.value as? any View {
                    let label = child.label ?? "<unlabeled>"
                    print("\(indent)🌳 [RootView]   Traversing child[\(index)] '\(label)' as View...")
                    traverse(view: childView, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                    foundView = true
                    // Don't return - continue with other children if any
                }
            }
            
            if foundView {
                print("\(indent)🌳 [RootView] Successfully traversed View children")
                print("\(indent)🌳 [RootView] ================================================")
                return
            }
            
            // Last resort: try to traverse into nested structures
            print("\(indent)🌳 [RootView] === Last Resort: Deep Nested Traversal ===")
            for (index, child) in inspector.children.enumerated() {
                let label = child.label ?? "<unlabeled>"
                print("\(indent)🌳 [RootView]   Attempting deep inspection of child[\(index)] '\(label)'...")
                
                // Use RunTimeTypeInspector to go deeper
                let childInspector = RunTimeTypeInspector(subject: child.value)
                for (subIndex, subChild) in childInspector.children.enumerated() {
                    let subLabel = subChild.label ?? "<unlabeled>"
                    let subType = type(of: subChild.value)
                    print("\(indent)🌳 [RootView]     Sub-child[\(subIndex)] '\(subLabel)': \(subType)")
                    
                    if let subView = subChild.value as? any View {
                        print("\(indent)🌳 [RootView]     ✅ Found View at nested level! Traversing...")
                        traverse(view: subView, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                        foundView = true
                    }
                }
            }
            
            if foundView {
                print("\(indent)🌳 [RootView] Successfully traversed nested View children")
                print("\(indent)🌳 [RootView] ================================================")
                return
            }
            
            print("\(indent)🌳 [RootView] ⚠️  WARNING: Could not find any traversable View in RootView")
            print("\(indent)🌳 [RootView] If you see this, examine the structure dump above to understand RootView's layout")
            print("\(indent)🌳 [RootView] ================================================")
           // return
        }
        
        // **Case 1: IDView Detection** - The view was created by calling .id() on another view.
        // IDView is a wrapper that tags a view with an identifier.
        // When we find one, we need to:
        // 1. Extract the new ID value
        // 2. Extract the wrapped content view
        // 3. Continue traversal with the new ID (all subsequent modifiers use this ID)
        if viewTypeName.starts(with: "IDView") {
            print("\(indent)🆔 [IDView] Found IDView wrapper")
            // Use descendant() to access nested properties by name.
            // "content" holds the wrapped view, "id" holds the identifier value.
            guard let content = mirror.descendant("content"),
                  let newID = mirror.descendant("id") as? AnyHashable else {
                print("\(indent)❌ [IDView] Failed to extract content or id")
                return
            }
            print("\(indent)🆔 [IDView] Switching to new ID: \(newID)")
            // Recurse with the updated ID. From this point forward, modifiers belong to this ID.
            traverse(view: content, currentID: newID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
            return
        }
        
        // **Case 2: ModifiedContent Detection** - This is THE KEY to reading the modifier chain.
        // ModifiedContent is SwiftUI's internal wrapper created by every .modifier() call.
        // It has exactly two properties:
        //   - "content": The inner view (next layer in the hierarchy)
        //   - "modifier": The ViewModifier being applied
        //
        // By repeatedly unwrapping ModifiedContent wrappers, we can read the entire chain
        // from the RootView down to the base view, collecting modifiers along the way.
        
        // POSSIBLE POINT TO TAP INTO LONG PATH
        if viewTypeName.starts(with: "ModifiedContent") {
            print("\(indent)🔧 [ModifiedContent] Found ModifiedContent wrapper")
            
            // list all mirrored properties and try runtypeinsepctor as well
            //let modifierInspector = RunTimeTypeInspector(subject: modifier)
           // print("\(indent)🔬 [XRAY-Modifier] Children count: \(modifierInspector.children.count)")
            let (mirror, inspector, allChildren) = combinedReflect(on: view)
            
            print("\(indent)🔧 [ModifiedContent][Reflection] Mirror: \(mirror.children.count) children, XRAY: \(inspector.children.count) children")
            print("\(indent)🔧 [ModifiedContent][Reflection] Combined: \(allChildren.count) total unique children")
            print("\(indent)🔧 [ModifiedContent][XRAY] DisplayStyle: \(inspector.displayStyle)")
            
            // Log all unique children found by combined reflection
            for (index, child) in allChildren.enumerated() {
                let label = child.label ?? "<unlabeled>"
                let childType = type(of: child.value)
                print("\(indent)🔧 [ModifiedContent][Combined]   Child[\(index)]: '\(label)' -> \(childType)")
                
                // Use RunTimeTypeInspector to go deeper
                let childInspector = RunTimeTypeInspector(subject: child.value)
                for (subIndex, subChild) in childInspector.children.enumerated() {
                    let subLabel = subChild.label ?? "<unlabeled>"
                    let subType = type(of: subChild.value)
                    print("\(indent)🔧 [ModifiedContent]     Sub-child[\(subIndex)] '\(subLabel)': \(subType)")
                    
                    if let subView = subChild.value as? any View {
                        print("\(indent)🔧 [ModifiedContent]     ✅ Found View at nested level! Traversing...")
                        traverse(view: subView, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                    }
                    else {
                        traverse(view: child, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)

                    }
                }
            }
            //try to traverse child[0] as ModifiedContent
            
            let modifiedContentTypeInspector = RunTimeTypeInspector(subject: view)
            for (subIndex, subChild) in modifiedContentTypeInspector.children.enumerated() {
                let subLabel = subChild.label ?? "<unlabeled>"
                let subType = type(of: subChild.value)
                print("\(indent)🔧 [ModifiedContent]     Sub-child[\(subIndex)] '\(subLabel)': \(subType)")
                
                if let subView = subChild.value as? any View {
                    print("\(indent)🔧 [ModifiedContent]     ✅ Found View at nested level! Traversing...")
                    traverse(view: subView, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                }
            }
            if let content = mirror.descendant("content") {
                
            }
            else {
                let newMirror =  Mirror(reflecting: modifiedContentTypeInspector.subject)
                for child in newMirror.children {
                   // print("\(indent)🔬 [XRAY-Modifier]   Property[\(index)]: '\(label)' = \(childValue) (\(childType))")
                    print("\(indent)🔧 [ModifiedContent]     newMirror = \(child.label ?? "<unlabeled>")")

                }
                //traverse(view: modifiedContentTypeInspector.subject, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)

            }

            
            // Extract the 'content' and 'modifier' properties using reflection.
            // These property names are defined by SwiftUI's ModifiedContent struct.
            guard let content = mirror.descendant("content"),
                  let modifier = mirror.descendant("modifier") else {
                
                // If the structure is not as expected, terminate traversal for this branch.
                print("\(indent)❌ [ModifiedContent] Failed to extract content or modifier")
                return
            }
            
            let modifierTypeName = String(describing: type(of: modifier))
            print("\(indent)🔧 [ModifiedContent] Modifier type: \(modifierTypeName)")
            
            // **Use XRAY to deeply inspect the modifier**
            let xray = XrayDecoder(subject: modifier)
            print("\(indent)🔬 [XRAY-Modifier] DisplayStyle: \(xray.displayStyle)")
            
            // Try to extract all properties from the modifier using RunTimeTypeInspector
            let modifierInspector = RunTimeTypeInspector(subject: modifier)
            print("\(indent)🔬 [XRAY-Modifier] Children count: \(modifierInspector.children.count)")
            
            // Log all modifier properties discovered by XRAY
            for (index, child) in modifierInspector.children.enumerated() {
                let label = child.label ?? "<unlabeled>"
                let childType = type(of: child.value)
                let childValue = String(describing: child.value)
                print("\(indent)🔬 [XRAY-Modifier]   Property[\(index)]: '\(label)' = \(childValue) (\(childType))")
            }
            
            // Cast the modifier from 'Any' to 'any ViewModifier'.
            // This is safe because ModifiedContent is generic over types conforming to ViewModifier.
            if let viewModifier = modifier as? any ViewModifier {
                print("\(indent)✅ [ModifiedContent] Successfully cast to ViewModifier")
                
                // **EXTRACT ALL MODIFIER DETAILS**
                print("\(indent)📝 [ModifierDetails] === EXTRACTING ALL MODIFIER INFORMATION ===")
                print("\(indent)📝 [ModifierDetails] Modifier Type: \(modifierTypeName)")
                
                // Use both Mirror and XRAY to get ALL properties
                let modMirror = Mirror(reflecting: viewModifier)
                let modInspector = RunTimeTypeInspector(subject: viewModifier)
                
                print("\(indent)📝 [ModifierDetails] Mirror properties: \(modMirror.children.count)")
                print("\(indent)📝 [ModifierDetails] XRAY properties: \(modInspector.children.count)")
                
                // Extract from Mirror
                if modMirror.children.count > 0 {
                    print("\(indent)📝 [ModifierDetails] --- Mirror Extraction ---")
                    for (idx, child) in modMirror.children.enumerated() {
                        let label = child.label ?? "<unlabeled-\(idx)>"
                        let value = child.value
                        let valueType = type(of: value)
                        let valueStr = String(describing: value)
                        print("\(indent)📝 [ModifierDetails]   [\(idx)] '\(label)': \(valueType)")
                        print("\(indent)📝 [ModifierDetails]       Value: \(valueStr)")
                        
                        // If the value itself has properties, show them too
                        let valueMirror = Mirror(reflecting: value)
                        if valueMirror.children.count > 0 {
                            print("\(indent)📝 [ModifierDetails]       Nested properties:")
                            for (subIdx, subChild) in valueMirror.children.enumerated() {
                                let subLabel = subChild.label ?? "<unlabeled-\(subIdx)>"
                                let subValue = String(describing: subChild.value)
                                let subType = type(of: subChild.value)
                                print("\(indent)📝 [ModifierDetails]         [\(subIdx)] '\(subLabel)': \(subType) = \(subValue)")
                            }
                        }
                    }
                }
                
                // Extract from XRAY (might find different things)
                if modInspector.children.count > 0 {
                    print("\(indent)📝 [ModifierDetails] --- XRAY Extraction ---")
                    for (idx, child) in modInspector.children.enumerated() {
                        let label = child.label ?? "<unlabeled-\(idx)>"
                        let value = child.value
                        let valueType = type(of: value)
                        let valueStr = String(describing: value)
                        print("\(indent)📝 [ModifierDetails]   [\(idx)] '\(label)': \(valueType)")
                        print("\(indent)📝 [ModifierDetails]       Value: \(valueStr)")
                    }
                }
                
                print("\(indent)📝 [ModifierDetails] === END MODIFIER DETAILS ===")
                
                // Add to the global modifiers accumulator (tracks all modifiers found).
                modifiers.append(viewModifier)
                
                // **Associate this modifier with the current ID**:
                // If this is the first modifier for this ID, initialize the array.
                if associations[currentID] == nil {
                    associations[currentID] = [any ViewModifier]()
                    associations[currentID]?.append(viewModifier)
                    print("\(indent)📝 [Association] Created new association for ID '\(currentID)' with 1 modifier")
                }
                else {
                    // Otherwise, append to the existing array for this ID.
                    associations[currentID]?.append(viewModifier)
                    let count = associations[currentID]?.count ?? 0
                    print("\(indent)📝 [Association] Added modifier to ID '\(currentID)' (now \(count) modifiers)")
                }
            } else {
                print("\(indent)⚠️ [ModifiedContent] Failed to cast modifier to ViewModifier")
            }
            
            // **Recurse into the 'content' to continue unwrapping**:
            // This is how we move from outer layers to inner layers of the hierarchy.
            // The content might be another ModifiedContent, an IDView, or a base view.
            print("\(indent)⬇️ [ModifiedContent] Recursing into content...")
            traverse(view: content, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
            
        }
        // **Case 3: AnyView Unwrapping** - Handle type-erased views.
        // AnyView is SwiftUI's way of hiding the concrete type of a view.
        // It wraps the actual view in an internal storage structure.
        else if viewTypeName == "AnyView" {
            print("\(indent)🎭 [AnyView] Found AnyView wrapper, attempting to unwrap...")
            
            // Reflect on the AnyView to access its internal structure.
            let mirror = Mirror(reflecting: view)
            // The actual view is stored in nested properties: storage.view
            if let storage = mirror.descendant("storage") {
                print("\(indent)🎭 [AnyView] Found storage")
                let storageMirror = Mirror(reflecting: storage)
                let storageType = type(of: storage)
                print("\(indent)🎭 [AnyView] Storage type: \(storageType)")
                
                // Extract the underlying view from the storage.
                if let underlyingView = storageMirror.descendant("view") {
                    let underlyingType = type(of: underlyingView)
                    print("\(indent)🎭 [AnyView] Unwrapped to: \(underlyingType)")
                    
                    // Continue the traversal from the unwrapped view.
                    // Use the same currentID since AnyView doesn't change identity.
                    traverse(view: underlyingView, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                } else {
                    print("\(indent)❌ [AnyView] Failed to extract view from storage")
                }
            } else {
                print("\(indent)❌ [AnyView] Failed to find storage")
            }
        }
        // **Case 4: SwiftUIContentView and Container Views**
        // SwiftUIContentView is an internal SwiftUI container that wraps content
        // VStack, HStack, ZStack and other containers also need special handling
        else if viewTypeName.contains("SwiftUIContentView") ||
                    viewTypeName.contains("VStack") ||
                    viewTypeName.contains("HStack") ||
                    viewTypeName.contains("ZStack") ||
                    viewTypeName.contains("TupleView") ||
                    viewTypeName.contains("_ConditionalContent") {
            
            print("\(indent)📦 [Container] ================================================")
            print("\(indent)📦 [Container] DETECTED Container View: \(viewTypeName)")
            print("\(indent)📦 [Container] ================================================")
            
            // Use XRAY to deeply inspect the container structure
            print("\(indent)📦 [Container] Using XRAY to inspect container structure...")
            print("\(indent)📦 [Container] DisplayStyle: \(inspector.displayStyle)")
            print("\(indent)📦 [Container] XRAY children count: \(inspector.children.count)")
            
            // IMPORTANT: Also check Mirror children separately!
            print("\(indent)📦 [Container] Mirror children count: \(mirror.children.count)")
            
            // If BOTH are 0, do a complete structure dump to figure out what's going on
            if inspector.children.count == 0 && mirror.children.count == 0 {
                print("\(indent)📦 [Container] ⚠️ WARNING: Both XRAY and Mirror show 0 children!")
                print("\(indent)📦 [Container] Dumping complete structure to diagnose...")
                //dumpViewStructure(view: view, label: "EmptyContainer", depth: depth)
            }
            
            // Log Mirror children (might be different from XRAY!)
            if mirror.children.count > 0 {
                print("\(indent)📦 [Container] === Mirror Children ===")
                for (index, child) in mirror.children.enumerated() {
                    let label = child.label ?? "<unlabeled-\(index)>"
                    let childType = type(of: child.value)
                    let childTypeName = String(describing: childType)
                    print("\(indent)📦 [Container]   Mirror[\(index)]: '\(label)' -> \(childTypeName)")
                    
                    if child.value is (any View) {
                        print("\(indent)📦 [Container]     ✅ IS a View!")
                    } else {
                        print("\(indent)📦 [Container]     ⚠️ NOT a View, type: \(childTypeName)")
                    }
                }
            }
            
            // Log all children with detailed information
            print("\(indent)📦 [Container] === XRAY Children Analysis ===")
            for (index, child) in inspector.children.enumerated() {
                let label = child.label ?? "<unlabeled>"
                let childType = type(of: child.value)
                let childTypeName = String(describing: childType)
                print("\(indent)📦 [Container]   Child[\(index)]: label='\(label)' type=\(childTypeName)")
                
                // Try to inspect the child further with XRAY
                let childInspector = RunTimeTypeInspector(subject: child.value)
                print("\(indent)📦 [Container]     └─ DisplayStyle: \(childInspector.displayStyle)")
                print("\(indent)📦 [Container]     └─ Has \(childInspector.children.count) children")
                
                // Check if child is a View
                if child.value is (any View) {
                    print("\(indent)📦 [Container]     └─ ✅ IS a View - will traverse!")
                } else {
                    print("\(indent)📦 [Container]     └─ ⚠️  NOT a View")
                }
            }
            
            // Try standard property names that containers might have
            print("\(indent)📦 [Container] === Attempting Standard Property Extraction ===")
            let containerProps = ["content", "value", "storage", "tree", "root", "body", "_tree", "_storage", "base", "wrappedValue", "some"]
            
            var foundContentProperty = false
            for propName in containerProps {
                if let propValue = mirror.descendant(propName) {
                    let propType = type(of: propValue)
                    print("\(indent)📦 [Container]   Found '\(propName)': \(propType)")
                    foundContentProperty = true
                    
                    if let viewValue = propValue as? any View {
                        print("\(indent)📦 [Container]   ✅ '\(propName)' is a View! Traversing...")
                        traverse(view: viewValue, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                        print("\(indent)📦 [Container] Successfully traversed '\(propName)'")
                        print("\(indent)📦 [Container] ================================================")
                        return
                    } else {
                        // Even if not directly a View, it might be a tuple or container of Views
                        let propInspector = RunTimeTypeInspector(subject: propValue)
                        print("\(indent)📦 [Container]   '\(propName)' not a View, has \(propInspector.children.count) children")
                        if propInspector.children.count > 0 {
                            print("\(indent)📦 [Container]   Inspecting children of '\(propName)'...")
                            var foundNestedViews = false
                            for (subIndex, subChild) in propInspector.children.enumerated() {
                                let subLabel = subChild.label ?? "<unlabeled>"
                                let subType = type(of: subChild.value)
                                print("\(indent)📦 [Container]     Child[\(subIndex)] '\(subLabel)': \(subType)")
                                if let subView = subChild.value as? any View {
                                    print("\(indent)📦 [Container]     ✅ Child[\(subIndex)] '\(subLabel)' is a View! Traversing...")
                                    traverse(view: subView, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                                    foundNestedViews = true
                                }
                            }
                            if foundNestedViews {
                                print("\(indent)📦 [Container] Successfully traversed nested views from '\(propName)'")
                                print("\(indent)📦 [Container] ================================================")
                                return
                            }
                        }
                    }
                }
            }
            
            if !foundContentProperty {
                print("\(indent)📦 [Container]   ⚠️ NO standard properties found - this is unusual!")
            }
            
            // Traverse Mirror children first (they might have content that XRAY misses)
            print("\(indent)📦 [Container] === Traversing Mirror Children ===")
            var foundViews = 0
            for (index, child) in mirror.children.enumerated() {
                let label = child.label ?? "<unlabeled-\(index)>"
                if let childView = child.value as? any View {
                    print("\(indent)📦 [Container]   Traversing Mirror child[\(index)] '\(label)' as View...")
                    traverse(view: childView, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                    foundViews += 1
                } else {
                    // Even if not a View, it might contain Views - inspect it
                    print("\(indent)📦 [Container]   Mirror child[\(index)] '\(label)' is not a View, inspecting deeper...")
                    let childInspector = RunTimeTypeInspector(subject: child.value)
                    print("\(indent)📦 [Container]     Has \(childInspector.children.count) nested children")
                    
                    for (subIdx, subChild) in childInspector.children.enumerated() {
                        if let subView = subChild.value as? any View {
                            let subLabel = subChild.label ?? "<unlabeled>"
                            print("\(indent)📦 [Container]     ✅ Nested child[\(subIdx)] '\(subLabel)' is a View! Traversing...")
                            traverse(view: subView, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                            foundViews += 1
                        }
                    }
                }
            }
            
            print("\(indent)📦 [Container] Traversed \(foundViews) view(s) from Mirror children")
            
            // Also traverse XRAY children (might find different things)
            print("\(indent)📦 [Container] === Traversing XRAY Children ===")
            var xrayFoundViews = 0
            for (index, child) in inspector.children.enumerated() {
                if let childView = child.value as? any View {
                    let label = child.label ?? "<unlabeled>"
                    print("\(indent)📦 [Container]   Traversing XRAY child[\(index)] '\(label)' as View...")
                    traverse(view: childView, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                    xrayFoundViews += 1
                }
            }
            
            print("\(indent)📦 [Container] Traversed \(xrayFoundViews) view(s) from XRAY children")
            foundViews += xrayFoundViews
            
            // If no direct views found, try nested traversal
            if foundViews == 0 {
                print("\(indent)📦 [Container] === No Direct Views Found, Trying Nested Traversal ===")
                for (index, child) in inspector.children.enumerated() {
                    let label = child.label ?? "<unlabeled>"
                    print("\(indent)📦 [Container]   Deep inspecting child[\(index)] '\(label)'...")
                    
                    let childInspector = RunTimeTypeInspector(subject: child.value)
                    for (subIndex, subChild) in childInspector.children.enumerated() {
                        let subLabel = subChild.label ?? "<unlabeled>"
                        let subType = type(of: subChild.value)
                        print("\(indent)📦 [Container]     Sub-child[\(subIndex)] '\(subLabel)': \(subType)")
                        
                        if let subView = subChild.value as? any View {
                            print("\(indent)📦 [Container]     ✅ Found View at nested level! Traversing...")
                            traverse(view: subView, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                            foundViews += 1
                        }
                    }
                }
            }
            
            print("\(indent)📦 [Container] Total views found and traversed: \(foundViews)")
            print("\(indent)📦 [Container] ================================================")
            
            // Always return after handling container - don't fall through to base case
            return
        }
        // **Case 5: Optional Views**
        // Handle Optional<SomeView> wrappers - need to unwrap and continue
        else if viewTypeName.starts(with: "Optional<") || inspector.displayStyle == .nil {
            print("\(indent)🎁 [Optional] ================================================")
            print("\(indent)🎁 [Optional] DETECTED Optional wrapper: \(viewTypeName)")
            print("\(indent)🎁 [Optional] DisplayStyle: \(inspector.displayStyle)")
            print("\(indent)🎁 [Optional] ================================================")
            
            // Check if it's nil or has a value
            if inspector.displayStyle == .nil {
                print("\(indent)🎁 [Optional] Value is nil - stopping traversal")
                return
            }
            
            print("\(indent)🎁 [Optional] Optional has a value, attempting to unwrap...")
            
            // Try to unwrap using Mirror
            print("\(indent)🎁 [Optional] === Mirror unwrapping ===")
            for (index, child) in mirror.children.enumerated() {
                let label = child.label ?? "<unlabeled-\(index)>"
                let childType = type(of: child.value)
                print("\(indent)🎁 [Optional]   Mirror child[\(index)] '\(label)': \(childType)")
                
                if let unwrappedView = child.value as? any View {
                    print("\(indent)🎁 [Optional]   ✅ Successfully unwrapped to View: \(childType)")
                    traverse(view: unwrappedView, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                    print("\(indent)🎁 [Optional] ================================================")
                    return
                } else {
                    print("\(indent)🎁 [Optional]   ⚠️ Child is not a View, continuing...")
                    // Still traverse it - might contain the view
                    traverse(view: child.value, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                    print("\(indent)🎁 [Optional] ================================================")
                    return
                }
            }
            
            // Try using XRAY to unwrap
            print("\(indent)🎁 [Optional] === XRAY unwrapping ===")
            for (index, child) in inspector.children.enumerated() {
                let label = child.label ?? "<unlabeled-\(index)>"
                let childType = type(of: child.value)
                print("\(indent)🎁 [Optional]   XRAY child[\(index)] '\(label)': \(childType)")
                
                if let unwrappedView = child.value as? any View {
                    print("\(indent)🎁 [Optional]   ✅ Successfully unwrapped to View: \(childType)")
                    traverse(view: unwrappedView, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                    print("\(indent)🎁 [Optional] ================================================")
                    return
                } else {
                    print("\(indent)🎁 [Optional]   ⚠️ Child is not a View, continuing anyway...")
                    traverse(view: child.value, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                    print("\(indent)🎁 [Optional] ================================================")
                    return
                }
            }
            
            print("\(indent)🎁 [Optional] ⚠️ Could not unwrap optional")
            print("\(indent)🎁 [Optional] ================================================")
            return
        }
        // **Case 6: Internal SwiftUI Collection/List Views**
        // _ViewList_View, ModifiedElements, and similar internal types that contain collections
        else if viewTypeName.contains("_ViewList_View") ||
                    viewTypeName.contains("ModifiedElements") ||
                    viewTypeName.contains("_ViewList") ||
                    viewTypeName.contains("ForEach") {
            
            print("\(indent)📋 [ListView] ================================================")
            print("\(indent)📋 [ListView] DETECTED List/Collection View: \(viewTypeName)")
            print("\(indent)📋 [ListView] ================================================")
            
            print("\(indent)📋 [ListView] Using XRAY to inspect structure...")
            print("\(indent)📋 [ListView] DisplayStyle: \(inspector.displayStyle)")
            print("\(indent)📋 [ListView] Children count: \(inspector.children.count)")
            
            // Log all properties
            print("\(indent)📋 [ListView] === All Properties ===")
            for (index, child) in inspector.children.enumerated() {
                let label = child.label ?? "<unlabeled>"
                let childType = type(of: child.value)
                let childTypeName = String(describing: childType)
                print("\(indent)📋 [ListView]   Property[\(index)]: '\(label)' type=\(childTypeName)")
            }
            
            // **PRIORITY: Check for contentSubgraph first** - this contains actual view instances
            print("\(indent)📋 [ListView] ================================================")
            print("\(indent)📋 [ListView] 🎯 PRIORITY: AGGRESSIVE contentSubgraph INSPECTION")
            print("\(indent)📋 [ListView] ================================================")
            
            for (index, child) in allChildren.enumerated() {
                let label = child.label ?? "<unlabeled>"
                if label == "contentSubgraph" {
                    print("\(indent)📋 [ListView] 🎯🎯🎯 FOUND contentSubgraph! THIS IS THE KEY!")
                    let childType = type(of: child.value)
                    let childTypeName = String(describing: childType)
                    print("\(indent)📋 [ListView]   Type: \(childTypeName)")
                    
                    // Check if it's Optional and unwrap it
                    if childTypeName.starts(with: "Optional<") {
                        print("\(indent)📋 [ListView]   📦 It's an Optional - attempting to unwrap...")
                        
                        let optionalMirror = Mirror(reflecting: child.value)
                        print("\(indent)📋 [ListView]   📦 Optional mirror children: \(optionalMirror.children.count)")
                        
                        if optionalMirror.children.count == 0 {
                            print("\(indent)📋 [ListView]   ❌ Optional is nil - no content subgraph")
                            continue
                        }
                        
                        // Unwrap the optional
                        for optChild in optionalMirror.children {
                            print("\(indent)📋 [ListView]   ✅✅✅ UNWRAPPED! Accessing AGSubgraphRef...")
                            print("\(indent)📋 [ListView]   ================================================")
                            print("\(indent)📋 [ListView]   🔬 CRITICAL SECTION: AGSubgraphRef Deep Analysis")
                            print("\(indent)📋 [ListView]   This is where view instances SHOULD be stored!")
                            print("\(indent)📋 [ListView]   ================================================")
                            
                            let unwrappedValue = optChild.value
                            let unwrappedType = type(of: unwrappedValue)
                            let unwrappedTypeName = String(describing: unwrappedType)
                            print("\(indent)📋 [ListView]   Unwrapped type: \(unwrappedTypeName)")
                            
                            // AGGRESSIVE INSPECTION using BOTH Mirror and XRAY
                            print("\(indent)📋 [ListView]   === STAGE 1: Initial Reflection ===")
                            
                            let sgMirror = Mirror(reflecting: unwrappedValue)
                            let sgInspector = RunTimeTypeInspector(subject: unwrappedValue)
                            
                            print("\(indent)📋 [ListView]   Mirror children: \(sgMirror.children.count)")
                            print("\(indent)📋 [ListView]   XRAY children: \(sgInspector.children.count)")
                            print("\(indent)📋 [ListView]   DisplayStyle: \(sgInspector.displayStyle)")
                            
                            // Try to access AGSubgraphRef as if it's a reference/pointer
                            print("\(indent)📋 [ListView]   === STAGE 2: Attempting to dereference subgraph ===")
                            print("\(indent)📋 [ListView]   AGSubgraphRef is likely a reference to actual graph data")
                            print("\(indent)📋 [ListView]   Looking for: graph, outputs, nodes, roots, values...")
                            
                            // Log ALL properties using Mirror
                            print("\(indent)📋 [ListView]   === STAGE 3: Mirror Property Exploration ===")
                            for (mirIdx, mirChild) in sgMirror.children.enumerated() {
                                let mirLabel = mirChild.label ?? "<mirror-\(mirIdx)>"
                                let mirType = type(of: mirChild.value)
                                let mirTypeName = String(describing: mirType)
                                print("\(indent)📋 [ListView]   ================================================")
                                print("\(indent)📋 [ListView]     🔍 Property [\(mirIdx)]: '\(mirLabel)'")
                                print("\(indent)📋 [ListView]     Type: \(mirTypeName)")
                                
                                // Try to extract value representation
                                let valueStr = String(describing: mirChild.value)
                                if valueStr.count < 200 {
                                    print("\(indent)📋 [ListView]     Value: \(valueStr)")
                                }
                                
                                // Check if it's a View
                                if let mirView = mirChild.value as? any View {
                                    print("\(indent)📋 [ListView]     🚀🚀🚀 IS A VIEW! Traversing...")
                                    traverse(view: mirView, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                                    continue
                                }
                                
                                // CRITICAL: Check if this looks like a graph reference, pointer, or storage
                                let isGraphRelated = mirTypeName.contains("Graph") ||
                                mirTypeName.contains("Attribute") ||
                                mirTypeName.contains("Output") ||
                                mirTypeName.contains("Node") ||
                                mirTypeName.contains("Subgraph") ||
                                mirTypeName.contains("Storage") ||
                                mirTypeName.contains("Buffer") ||
                                mirTypeName.contains("Ref") ||
                                mirLabel.contains("graph") ||
                                mirLabel.contains("output") ||
                                mirLabel.contains("node") ||
                                mirLabel.contains("value") ||
                                mirLabel.contains("content") ||
                                mirLabel.contains("root")
                                
                                if isGraphRelated {
                                    print("\(indent)📋 [ListView]     ⚡ GRAPH-RELATED PROPERTY DETECTED!")
                                    print("\(indent)📋 [ListView]     ⚡ This might contain view instances or references to them")
                                }
                                
                                // Deep dive into this property
                                print("\(indent)📋 [ListView]     === Level 2: Diving into '\(mirLabel)' ===")
                                let deepMirror = Mirror(reflecting: mirChild.value)
                                let deepInspector = RunTimeTypeInspector(subject: mirChild.value)
                                
                                print("\(indent)📋 [ListView]       Mirror children: \(deepMirror.children.count)")
                                print("\(indent)📋 [ListView]       XRAY children: \(deepInspector.children.count)")
                                print("\(indent)📋 [ListView]       DisplayStyle: \(deepInspector.displayStyle)")
                                
                                // If it has children, log them ALL
                                if deepMirror.children.count > 0 || deepInspector.children.count > 0 {
                                    print("\(indent)📋 [ListView]       Listing ALL children of '\(mirLabel)'...")
                                    
                                    // Check all deep children with EXTREME detail
                                    for (deepIdx, deepChild) in deepMirror.children.enumerated() {
                                        let deepLabel = deepChild.label ?? "<deep-\(deepIdx)>"
                                        let deepType = type(of: deepChild.value)
                                        let deepTypeName = String(describing: deepType)
                                        
                                        print("\(indent)📋 [ListView]         [\(deepIdx)] '\(deepLabel)': \(deepTypeName)")
                                        
                                        // SPECIAL HANDLING for _details property
                                        if deepLabel == "_details" || deepLabel == "details" ||
                                            deepTypeName.contains("__Unnamed_struct") ||
                                            deepTypeName.contains("details") {
                                            print("\(indent)📋 [ListView]         ⚡⚡⚡ FOUND '_details' OR UNNAMED STRUCT!")
                                            print("\(indent)📋 [ListView]         ⚡ This is a critical low-level structure!")
                                            print("\(indent)📋 [ListView]         ⚡ Performing ULTRA-DEEP inspection...")
                                            
                                            let detailsMirror = Mirror(reflecting: deepChild.value)
                                            let detailsInspector = RunTimeTypeInspector(subject: deepChild.value)
                                            
                                            print("\(indent)📋 [ListView]         Details Mirror: \(detailsMirror.children.count)")
                                            print("\(indent)📋 [ListView]         Details XRAY: \(detailsInspector.children.count)")
                                            
                                            // Log EVERYTHING in _details
                                            print("\(indent)📋 [ListView]         === _details Contents (Mirror) ===")
                                            for (detIdx, detChild) in detailsMirror.children.enumerated() {
                                                let detLabel = detChild.label ?? "<det-\(detIdx)>"
                                                let detType = type(of: detChild.value)
                                                let detTypeName = String(describing: detType)
                                                let detValue = String(describing: detChild.value)
                                                
                                                print("\(indent)📋 [ListView]           [\(detIdx)] '\(detLabel)': \(detTypeName)")
                                                if detValue.count < 150 {
                                                    print("\(indent)📋 [ListView]                Value: \(detValue)")
                                                }
                                                
                                                // Check if it's a view
                                                if let detView = detChild.value as? any View {
                                                    print("\(indent)📋 [ListView]           🚀🚀🚀 FOUND VIEW IN _details!")
                                                    traverse(view: detView, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                                                }
                                                
                                                // Go ANOTHER level deeper for _details
                                                let detDeepMirror = Mirror(reflecting: detChild.value)
                                                if detDeepMirror.children.count > 0 {
                                                    print("\(indent)📋 [ListView]             Going deeper into '\(detLabel)' (\(detDeepMirror.children.count) children)...")
                                                    for (ddIdx, ddChild) in detDeepMirror.children.enumerated() {
                                                        let ddLabel = ddChild.label ?? "<dd-\(ddIdx)>"
                                                        let ddType = type(of: ddChild.value)
                                                        let ddTypeName = String(describing: ddType)
                                                        print("\(indent)📋 [ListView]               [\(ddIdx)] '\(ddLabel)': \(ddTypeName)")
                                                        
                                                        if let ddView = ddChild.value as? any View {
                                                            print("\(indent)📋 [ListView]                 🚀🚀🚀 VIEW AT ULTRA-DEEP LEVEL!")
                                                            traverse(view: ddView, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                                                        }
                                                        
                                                        // Check for pointers, references, storage
                                                        if ddTypeName.contains("Pointer") ||
                                                            ddTypeName.contains("Storage") ||
                                                            ddTypeName.contains("Buffer") ||
                                                            ddTypeName.contains("Unmanaged") ||
                                                            ddTypeName.contains("UnsafePointer") ||
                                                            ddLabel.contains("ptr") ||
                                                            ddLabel.contains("ref") {
                                                            print("\(indent)📋 [ListView]                 ⚠️ POINTER/STORAGE DETECTED!")
                                                            print("\(indent)📋 [ListView]                 ⚠️ Might need unsafe memory access")
                                                            print("\(indent)📋 [ListView]                 ⚠️ Type: \(ddTypeName)")
                                                        }
                                                    }
                                                }
                                            }
                                            
                                            
                                            print("\(indent)📋 [ListView]         === _details Contents (XRAY) ===")
                                            for (xdetIdx, xdetChild) in detailsInspector.children.enumerated() {
                                                let xdetLabel = xdetChild.label ?? "<xdet-\(xdetIdx)>"
                                                let xdetType = type(of: xdetChild.value)
                                                let xdetTypeName = String(describing: xdetType)
                                                print("\(indent)📋 [ListView]           [X\(xdetIdx)] '\(xdetLabel)': \(xdetTypeName)")
                                                
                                                if let xdetView = xdetChild.value as? any View {
                                                    print("\(indent)📋 [ListView]           🚀🚀🚀 FOUND VIEW VIA XRAY IN _details!")
                                                    traverse(view: xdetView, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                                                }
                                            }
                                        }
                                        
                                        if let deepView = deepChild.value as? any View {
                                            print("\(indent)📋 [ListView]           🚀🚀 FOUND VIEW IN DEEP PROPERTY!")
                                            traverse(view: deepView, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                                        }
                                        
                                        // Check for graph nodes, outputs, values
                                        if deepTypeName.contains("Output") ||
                                            deepTypeName.contains("Node") ||
                                            deepTypeName.contains("Item") ||
                                            deepTypeName.contains("ViewList") ||
                                            deepLabel.contains("output") ||
                                            deepLabel.contains("value") ||
                                            deepLabel.contains("content") {
                                            print("\(indent)📋 [ListView]           🔍 Interesting type! Going even deeper...")
                                            
                                            // Go 3rd level deep
                                            let level3Mirror = Mirror(reflecting: deepChild.value)
                                            for (l3Idx, l3Child) in level3Mirror.children.enumerated() {
                                                let l3Label = l3Child.label ?? "<l3-\(l3Idx)>"
                                                let l3Type = type(of: l3Child.value)
                                                
                                                print("\(indent)📋 [ListView]             [L3-\(l3Idx)] '\(l3Label)': \(l3Type)")
                                                
                                                if let l3View = l3Child.value as? any View {
                                                    print("\(indent)📋 [ListView]               🚀🚀🚀 FOUND VIEW AT LEVEL 3!")
                                                    traverse(view: l3View, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                                                }
                                            }
                                        }
                                    }
                                    
                                    // Also check XRAY children at deep level
                                    for (xrayIdx, xrayChild) in deepInspector.children.enumerated() {
                                        let xrayLabel = xrayChild.label ?? "<xray-\(xrayIdx)>"
                                        let xrayType = type(of: xrayChild.value)
                                        
                                        if let xrayView = xrayChild.value as? any View {
                                            print("\(indent)📋 [ListView]         🚀 XRAY found view at '\(xrayLabel)'!")
                                            traverse(view: xrayView, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                                        }
                                    }
                                }
                                
                                // Log ALL XRAY properties
                                print("\(indent)📋 [ListView]   --- XRAY Properties ---")
                                for (xrayIdx, xrayChild) in sgInspector.children.enumerated() {
                                    let xrayLabel = xrayChild.label ?? "<xray-\(xrayIdx)>"
                                    let xrayType = type(of: xrayChild.value)
                                    let xrayTypeName = String(describing: xrayType)
                                    print("\(indent)📋 [ListView]     [\(xrayIdx)] '\(xrayLabel)': \(xrayTypeName)")
                                    
                                    if let xrayView = xrayChild.value as? any View {
                                        print("\(indent)📋 [ListView]       🚀 XRAY VIEW! Traversing...")
                                        traverse(view: xrayView, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                                    }
                                }
                                
                                print("\(indent)📋 [ListView]   === END AGSubgraphRef INSPECTION ===")
                            }
                        }
                        //                        else {
                        //                            print("\(indent)📋 [ListView]   ⚠️ Not an Optional - directly inspecting...")
                        //                            // Non-optional case - inspect directly
                        //                            let subgraphInspector = RunTimeTypeInspector(subject: child.value)
                        //                            print("\(indent)📋 [ListView]   Subgraph has \(subgraphInspector.children.count) children")
                        //                            
                        //                            for (sgIdx, sgChild) in subgraphInspector.children.enumerated() {
                        //                                let sgLabel = sgChild.label ?? "<unlabeled>"
                        //                                let sgType = type(of: sgChild.value)
                        //                                print("\(indent)📋 [ListView]     [\(sgIdx)] '\(sgLabel)': \(sgType)")
                        //                                
                        //                                if let sgView = sgChild.value as? any View {
                        //                                    print("\(indent)📋 [ListView]     ✅ Found View in contentSubgraph! Traversing...")
                        //                                    traverse(view: sgView, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                        //                                }
                        //                            }
                        //                        }
                    }
                }
                print("\(indent)📋 [ListView] ================================================")
                
                // **DEEP TRAVERSE ALL PROPERTIES** - especially 'elements'
                print("\(indent)📋 [ListView] === DEEP TRAVERSAL OF ALL PROPERTIES ===")
                for (index, child) in inspector.children.enumerated() {
                    let label = child.label ?? "<unlabeled>"
                    let childType = type(of: child.value)
                    let childTypeName = String(describing: childType)
                    
                    print("\(indent)📋 [ListView]   Processing property '\(label)': \(childTypeName)")
                    
                    if label == "contentSubgraph" {
                        print("We've found the ContentSubgraph! Digging...")
                    }
                    // Check if it's directly a View
                    if let viewValue = child.value as? any View {
                        print("\(indent)📋 [ListView]     ✅ Property IS a View! Traversing...")
                        traverse(view: viewValue, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                        continue
                    }
                    
                    if childTypeName.hasPrefix("Optional<") {
                        print("\(indent)📋 [ListView]     ⚠️ Optional property! digging in...")
                        
                        // call traverse without the Optional< prefix or trailing >
                        print("\(indent)🎁 [Optional] === XRAY unwrapping ===")
                        for (index, child) in inspector.children.enumerated() {
                            let label = child.label ?? "<unlabeled-\(index)>"
                            let childType = type(of: child.value)
                            print("\(indent)🎁 [Optional]   XRAY child[\(index)] '\(label)': \(childType)")
                            
                            if let unwrappedView = child.value as? any View {
                                print("\(indent)🎁 [Optional]   ✅ Successfully unwrapped to View: \(childType)")
                                traverse(view: unwrappedView, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                                print("\(indent)🎁 [Optional] ================================================")
                                return
                            }
//                            else {
//                                print("\(indent)🎁 [Optional]   ⚠️ Child is not a View, continuing anyway...")
//                                traverse(view: child.value, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
//                                print("\(indent)🎁 [Optional] ================================================")
//                                return
//                            }
                        }
                        
                        print("\(indent)🎁 [Optional] ⚠️ Could not unwrap optional")
                        print("\(indent)🎁 [Optional] ================================================")
//                        return
//                    }

                        
                    }
                    // **SPECIAL HANDLING for SwiftUI internal collection types**
                    if childTypeName.contains("ModifiedElements") ||
                        childTypeName.contains("SubgraphElements") ||
                        childTypeName.contains("UnaryElements") ||
                        childTypeName.contains("LazyContainerModifier") ||
                        childTypeName.contains("TypedUnaryViewGenerator") {
                        print("\(indent)📋 [ListView]     ⚙️ INTERNAL STRUCTURE DETECTED! Deep diving into '\(label)'...")
                        
                        // Deep inspect this structure
                        let structInspector = RunTimeTypeInspector(subject: child.value)
                        print("\(indent)📋 [ListView]       Structure has \(structInspector.children.count) properties")
                        
                        for (structIdx, structChild) in structInspector.children.enumerated() {
                            let structLabel = structChild.label ?? "<unlabeled>"
                            let structType = type(of: structChild.value)
                            let structTypeName = String(describing: structType)
                            print("\(indent)📋 [ListView]       [\(structIdx)] '\(structLabel)': \(structTypeName)")
                            
                            // Check if it's a View
                            if let structView = structChild.value as? any View {
                                print("\(indent)📋 [ListView]         ✅ IS A VIEW! Traversing...")
                                traverse(view: structView, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                            } else if structTypeName.contains("ModifiedElements") ||
                                        structTypeName.contains("SubgraphElements") ||
                                        structTypeName.contains("UnaryElements") ||
                                        structTypeName.contains("TupleView") {
                                // Recursively handle nested internal structures
                                print("\(indent)📋 [ListView]         🔄 Nested internal structure, recursing...")
                                traverse(view: structChild.value, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                            } else {
                                // Go even deeper
                                let deeperInspector = RunTimeTypeInspector(subject: structChild.value)
                                if deeperInspector.children.count > 0 {
                                    print("\(indent)📋 [ListView]           Going deeper (\(deeperInspector.children.count) children)...")
                                    
                                    // **LOG ALL CHILDREN to understand the structure**
                                    print("\(indent)📋 [ListView]           === ALL CHILDREN IN THIS LEVEL ===")
                                    for (idx, child) in deeperInspector.children.enumerated() {
                                        let childLabel = child.label ?? "<unlabeled>"
                                        let childType = type(of: child.value)
                                        print("\(indent)📋 [ListView]             [\(idx)] '\(childLabel)': \(childType)")
                                    }
                                    print("\(indent)📋 [ListView]           === END ALL CHILDREN ===")
                                    
                                    for (deepIdx, deepChild) in deeperInspector.children.enumerated() {
                                        let deepLabel = deepChild.label ?? "<unlabeled>"
                                        let deepType = type(of: deepChild.value)
                                        let deepTypeName = String(describing: deepType)
                                        
                                        // **PRIORITY: Check for allItems or similar collection properties**
                                        if deepLabel == "allItems" || deepLabel == "items" || deepLabel == "children" || deepLabel == "_items" || deepLabel == "customInputs" {
                                            print("\(indent)📋 [ListView]             🎯 FOUND ITEMS COLLECTION '\(deepLabel)': \(deepTypeName)")
                                            
                                            if deepTypeName == "PropertyList" {
                                                print("Found PropertyList")
                                            }
                                            // Inspect the collection
                                            let collectionInspector = RunTimeTypeInspector(subject: deepChild.value)
                                            print("\(indent)📋 [ListView]               Collection has \(collectionInspector.children.count) properties")
                                            for (unmIdx, unmChild) in collectionInspector.children.enumerated() {
                                                let unmLabel = unmChild.label ?? "<unlabeled>"
                                                print("\(indent)📋 [ListView]               collectionInspector        [\(unmIdx)] '\(unmLabel)'")
                                                
                                            }
                                            
                                            
                                            
                                            // Try to get the underlying array from MutableBox/Array
                                            for (collIdx, collChild) in collectionInspector.children.enumerated() {
                                                let collLabel = collChild.label ?? "<unlabeled>"
                                                let collType = type(of: collChild.value)
                                                let collTypeName = String(describing: collType)
                                                print("\(indent)📋 [ListView]                 [\(collIdx)] '\(collLabel)': \(collTypeName)")
                                                
                                                // If it's an array or buffer, iterate through it
                                                if collTypeName.contains("Array") || collLabel == "value" || collLabel == "_value" || collLabel == "elements" {
                                                    print("\(indent)📋 [ListView]                   Inspecting array-like structure...")
                                                    
                                                    // IMPORTANT: Try to access array elements directly via reflection
                                                    // before drilling into _ArrayBuffer internals
                                                    let arrayMirror = Mirror(reflecting: collChild.value)
                                                    print("\(indent)📋 [ListView]                   Array Mirror children count: \(arrayMirror.children.count)")
                                                    
                                                    
                                                   // ArrayMirror is Optional<Element>
                                                    
                                                    // Try to access array elements by index using Mirror descendant
                                                    // Swift arrays can be accessed via numeric indices
                                                    var foundElements = false
                                                    var elementIndex = 0
                                                    
                                                    // Try accessing elements by index (0, 1, 2, etc.)
                                                    while elementIndex < 8 { // reasonable limit
                                                        if let element = arrayMirror.descendant(elementIndex) {
                                                            print("\(indent)📋 [ListView]                   ✅ Found array element at index [\(elementIndex)]")
                                                            let elementType = type(of: element)
                                                            let elementTypeName = String(describing: elementType)
                                                            print("\(indent)📋 [ListView]                     Element type: \(elementTypeName)")
                                                            // SwiftUI.(unknown context at $1d4e944f4).TypedElement<SwiftUI.(unknown context at $1d43b5498).SourceInput<SwiftUI.ListStyleContent>>
                                                            // SEEN elementTypeName    String    "TypedElement<SourceInput<ListStyleContent>>"
                                                            
                                                            // This should be Unmanaged<Item>
                                                            if elementTypeName.contains("Unmanaged") {
                                                                print("\(indent)📋 [ListView]                     Unwrapping Unmanaged element...")
                                                                let unmanagedInspector = RunTimeTypeInspector(subject: element)
                                                                for (unmIdx, unmChild) in unmanagedInspector.children.enumerated() {
                                                                    let unmLabel = unmChild.label ?? "<unlabeled>"
                                                                    print("\(indent)📋 [ListView]                       [\(unmIdx)] '\(unmLabel)'")
                                                                    
                                                                    if unmLabel == "_value" || unmLabel == "value" || unmLabel.isEmpty {
                                                                        print("\(indent)📋 [ListView]                         🔄 Recursing into Item from array element...")
                                                                        traverse(view: unmChild.value, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                                                                    }
                                                                }
                                                            }
                                                            else if elementTypeName.starts(with: "TypedElement<") {
                                                                traverse(view: element, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                                                                break
                                                            }
                                                            else {
                                                                print("diff type encountered \(elementTypeName)")
                                                                break
                                                            }
//                                                            else {
//                                                                // Directly traverse the element
//                                                                print("\(indent)📋 [ListView]                     🔄 Recursing into array element...")
//                                                                traverse(view: element, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
//                                                            }
                                                            
                                                            foundElements = true
                                                            elementIndex += 1
                                                        }
                                                        else {
                                                            print("DONE type encountered Failed")
                                                            break

                                                        }
                                                    }
                                                    
                                                    if foundElements {
                                                        print("\(indent)📋 [ListView]                   ✅ Successfully iterated \(elementIndex) array element(s) via Mirror descendant")
                                                        continue // Skip the _ArrayBuffer approach
                                                    } else {
                                                        print("\(indent)📋 [ListView]                   ⚠️ Could not access array elements via Mirror descendant")
                                                        print("\(indent)📋 [ListView]                   Falling back to _ArrayBuffer inspection...")
                                                    }
                                                    
                                                    let arrayInspector = RunTimeTypeInspector(subject: collChild.value)
                                                    
                                                    // Try to iterate the array
                                                    for (arrIdx, arrChild) in arrayInspector.children.enumerated() {
                                                        let arrLabel = arrChild.label ?? "<unlabeled>"
                                                        let arrType = type(of: arrChild.value)
                                                        let arrTypeName = String(describing: arrType)
                                                        print("\(indent)📋 [ListView]                     Array[\(arrIdx)] '\(arrLabel)': \(arrTypeName)")
                                                        
                                                        // Check if it's an _ArrayBuffer - need to go into _storage
                                                        if arrTypeName.contains("_ArrayBuffer") || arrLabel == "_buffer" {
                                                            print("\(indent)📋 [ListView]                       Found _ArrayBuffer, accessing _storage...")
                                                            let bufferInspector = RunTimeTypeInspector(subject: arrChild.value)
                                                            for (bufIdx, bufChild) in bufferInspector.children.enumerated() {
                                                                let bufLabel = bufChild.label ?? "<unlabeled>"
                                                                let bufType = type(of: bufChild.value)
                                                                print("\(indent)📋 [ListView]                         [\(bufIdx)] '\(bufLabel)': \(bufType)")
                                                                
                                                                if bufLabel == "_storage" || bufLabel == "storage" {
                                                                    print("\(indent)📋 [ListView]                           Accessing array storage...")
                                                                    let storageInspector = RunTimeTypeInspector(subject: bufChild.value)
                                                                    let storageType = type(of: bufChild.value)
                                                                    let storageTypeName = String(describing: storageType)
                                                                    
                                                                    print("\(indent)📋 [ListView]                           Storage type: \(storageTypeName)")
                                                                    print("\(indent)📋 [ListView]                           Storage has \(storageInspector.children.count) children")
                                                                    
                                                                    // _BridgeStorage wraps __ContiguousArrayStorageBase
                                                                    // The rawValue is just the bridge wrapper - we need to access the storage base directly
                                                                    // Try to get the native storage or unwrap the bridge
                                                                    
                                                                    // First, check if this is BridgeStorage and try to access rawValue as the storage base
                                                                    if storageTypeName.contains("_BridgeStorage") || storageTypeName.contains("BridgeStorage") {
                                                                        print("\(indent)📋 [ListView]                           🌉 Detected BridgeStorage - need to access underlying storage base")
                                                                        
                                                                        // The rawValue property should be the actual storage
                                                                        // But we need to cast it to access elements
                                                                        // Try using Mirror on the original array instead
                                                                        
                                                                        // Alternative approach: Access the storage as an object and look for indexed children
                                                                        // ContiguousArrayStorage stores elements at indexed positions
                                                                        print("\(indent)📋 [ListView]                           Attempting to access storage base elements directly...")
                                                                        
                                                                        // Try to access rawValue and see if we can get the storage from there
                                                                        if let rawValueProp = storageInspector.children.first(where: { $0.label == "rawValue" }) {
                                                                            print("\(indent)📋 [ListView]                           Found rawValue property, inspecting...")
                                                                            let rawValueType = type(of: rawValueProp.value)
                                                                            let rawValueTypeName = String(describing: rawValueType)
                                                                            print("\(indent)📋 [ListView]                           RawValue type: \(rawValueTypeName)")
                                                                            
                                                                            // The rawValue is Builtin.BridgeObject - this is the low-level bridge
                                                                            // We need to access the actual storage differently
                                                                            // Try creating a new inspector from the storage value itself
                                                                            let storageValueInspector = RunTimeTypeInspector(subject: bufChild.value)
                                                                            
                                                                            print("\(indent)📋 [ListView]                           Attempting direct element access on storage...")
                                                                            print("\(indent)📋 [ListView]                           DisplayStyle: \(storageValueInspector.displayStyle)")
                                                                            
                                                                            // If it's a class, it might have indexed elements
                                                                            // Try iterating through numeric indices to find stored elements
                                                                            // Swift's ContiguousArrayStorageBase stores elements after header
                                                                            
                                                                            // Alternative: Use the original array value and try to iterate it differently
                                                                            // Go back up to collChild.value which is the Array<Unmanaged<Item>>
                                                                            print("\(indent)📋 [ListView]                           ⚠️ BridgeStorage detected - using alternative array iteration strategy")
                                                                            print("\(indent)📋 [ListView]                           Attempting to access parent array directly as collection...")
                                                                            
                                                                            // Get the array from parent (collChild.value from line 926)
                                                                            // We're too deep - let's try a different approach
                                                                            // Skip the storage internals and try to iterate the array as a Swift collection
                                                                        }
                                                                    }
                                                                    
                                                                    // Try direct iteration through storage children
                                                                    for (storIdx, storChild) in storageInspector.children.enumerated() {
                                                                        let storLabel = storChild.label ?? "<unlabeled>"
                                                                        let storType = type(of: storChild.value)
                                                                        let storTypeName = String(describing: storType)
                                                                        print("\(indent)📋 [ListView]                             [\(storIdx)] '\(storLabel)': \(storTypeName)")
                                                                        
                                                                        // Skip rawValue of BridgeObject - it's the wrapper
                                                                        if storLabel == "rawValue" && storTypeName.contains("Builtin") {
                                                                            print("\(indent)📋 [ListView]                               ⏭️  Skipping Builtin.BridgeObject wrapper")
                                                                            continue
                                                                        }
                                                                        
                                                                        // Check if it's Unmanaged
                                                                        if storTypeName.contains("Unmanaged") {
                                                                            print("\(indent)📋 [ListView]                               Unwrapping Unmanaged item...")
                                                                            let unmanagedInspector = RunTimeTypeInspector(subject: storChild.value)
                                                                            for (unmIdx, unmChild) in unmanagedInspector.children.enumerated() {
                                                                                let unmLabel = unmChild.label ?? "<unlabeled>"
                                                                                print("\(indent)📋 [ListView]                                 [\(unmIdx)] '\(unmLabel)'")
                                                                                
                                                                                if unmLabel == "_value" || unmLabel == "value" || unmLabel.isEmpty {
                                                                                    print("\(indent)📋 [ListView]                                   🔄 Recursing into Item...")
                                                                                    traverse(view: unmChild.value, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                                                                                }
                                                                            }
                                                                        } else if !storTypeName.contains("Builtin") {
                                                                            // Try to traverse non-builtin types
                                                                            print("\(indent)📋 [ListView]                               🔄 Recursing into storage item...")
                                                                            traverse(view: storChild.value, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                                                                        }
                                                                    }
                                                                }
                                                            }
                                                        }
                                                        // Check if it's an Unmanaged<Item> - need to get the actual Item
                                                        else if arrTypeName.contains("Unmanaged") {
                                                            print("\(indent)📋 [ListView]                       Unwrapping Unmanaged...")
                                                            let unmanagedInspector = RunTimeTypeInspector(subject: arrChild.value)
                                                            for (unmIdx, unmChild) in unmanagedInspector.children.enumerated() {
                                                                let unmLabel = unmChild.label ?? "<unlabeled>"
                                                                print("\(indent)📋 [ListView]                         [\(unmIdx)] '\(unmLabel)'")
                                                                
                                                                // Recursively traverse the unmanaged item
                                                                if unmLabel == "_value" || unmLabel == "value" || unmLabel.isEmpty {
                                                                    print("\(indent)📋 [ListView]                           🔄 Recursing into unwrapped item...")
                                                                    traverse(view: unmChild.value, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                                                                }
                                                            }
                                                        } else {
                                                            // Directly traverse if it's an item
                                                            print("\(indent)📋 [ListView]                       🔄 Recursing into array item...")
                                                            traverse(view: arrChild.value, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                                                        }
                                                    }
                                                }
                                            }
                                            continue
                                        }
                                        
                                        if let deepView = deepChild.value as? any View {
                                            print("\(indent)📋 [ListView]             ✅ Found View '\(deepLabel)'")
                                            traverse(view: deepView, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                                        }
                                        else if deepTypeName.contains("ModifiedElements") ||
                                                    deepTypeName.contains("SubgraphElements") ||
                                                    deepTypeName.contains("UnaryElements") ||
                                                    deepTypeName.contains("TupleView") {
                                            print("\(indent)📋 [ListView]             🔄 Deep nested structure '\(deepLabel)', recursing...")
                                            traverse(view: deepChild.value, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                                        }
                                        else if deepLabel == "type" && deepTypeName.hasSuffix(".Type") {
                                            // Skip metatypes - they don't contain actual instances
                                            print("\(indent)📋 [ListView]             ⚠️ Skipping metatype '\(deepLabel)' (it's a type, not an instance)")
                                            print("\(indent)📋 [ListView]             ⚠️ FOUND metatype '\(deepLabel)' (it's a type, not an instance)")

                                            
                                            let instanceInspector = RunTimeTypeInspector(subject: deepChild.value)
                                            print(instanceInspector)

                                        }
                                        else if deepLabel == "body" || deepLabel == "view" || deepLabel == "value" ||
                                                    deepLabel == "instance" || deepLabel == "root" || deepLabel == "storage" ||
                                                    deepLabel == "content" || deepLabel == "base" {
                                            // These properties often contain the actual instances
                                            print("\(indent)📋 [ListView]             🔍 Found potential instance property '\(deepLabel)': \(deepTypeName), going deeper...")
                                            let instanceInspector = RunTimeTypeInspector(subject: deepChild.value)
                                            if instanceInspector.children.count > 0 {
                                                print("\(indent)📋 [ListView]               Instance has \(instanceInspector.children.count) properties")
                                                for (instIdx, instChild) in instanceInspector.children.enumerated() {
                                                    let instLabel = instChild.label ?? "<unlabeled>"
                                                    let instType = type(of: instChild.value)
                                                    if let instView = instChild.value as? any View {
                                                        print("\(indent)📋 [ListView]                 ✅ Instance child '\(instLabel)' is a View!")
                                                        traverse(view: instView, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                                                    } else {
                                                        print("\(indent)📋 [ListView]                 [\(instIdx)] '\(instLabel)': \(instType)")
                                                        
                                                        // TODO: IS htis where we dig
                                                    }
                                                }
                                            }
                                            // if not found that way then try via Mirror
                                        }
                                        else {
                                            // For any other property, check if it contains views
                                            print("\(indent)📋 [ListView]             🔎 Checking property '\(deepLabel)': \(deepTypeName)...")
                                            let checkInspector = RunTimeTypeInspector(subject: deepChild.value)
                                            if checkInspector.children.count > 0 {
                                                for (checkIdx, checkChild) in checkInspector.children.enumerated() {
                                                    if let checkView = checkChild.value as? any View {
                                                        let checkLabel = checkChild.label ?? "<unlabeled>"
                                                        print("\(indent)📋 [ListView]               ✅ Found View in '\(deepLabel)'.'\(checkLabel)'!")
                                                        traverse(view: checkView, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        // Regular property - still inspect it
                        let propInspector = RunTimeTypeInspector(subject: child.value)
                        if propInspector.children.count > 0 {
                            print("\(indent)📋 [ListView]     Property has \(propInspector.children.count) children, inspecting...")
                            for (childIdx, propChild) in propInspector.children.enumerated() {
                                if let propView = propChild.value as? any View {
                                    let propLabel = propChild.label ?? "<unlabeled>"
                                    print("\(indent)📋 [ListView]       ✅ Child '\(propLabel)' is a View! Traversing...")
                                    traverse(view: propView, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                                }
                            }
                        }
                    }
                }
                
                // Also try traversing any direct children that are Views
                print("\(indent)📋 [ListView] === Checking all properties for Views ===")
                var foundViews = 0
                for (index, child) in inspector.children.enumerated() {
                    let label = child.label ?? "<unlabeled>"
                    
                    if let childView = child.value as? any View {
                        print("\(indent)📋 [ListView]   Property[\(index)] '\(label)' IS a View! Traversing...")
                        traverse(view: childView, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                        foundViews += 1
                    }
                }
                
                print("\(indent)📋 [ListView] Found and traversed \(foundViews) View properties")
                print("\(indent)📋 [ListView] ================================================")
                return
            }
        }
        // **Case 7: Custom View Types**
        // Any user-defined or SwiftUI view that conforms to View protocol
        // These have a 'body' property that contains their actual content
        else if view is (any View) {
            print("\(indent)🎨 [CustomView] ================================================")
            print("\(indent)🎨 [CustomView] DETECTED Custom/Unknown View: \(viewTypeName)")
            print("\(indent)🎨 [CustomView] This appears to be a View type - looking for body property...")
            print("\(indent)🎨 [CustomView] ================================================")
            
            // Use XRAY to inspect the custom view structure
            print("\(indent)🎨 [CustomView] Using XRAY to inspect structure...")
            print("\(indent)🎨 [CustomView] DisplayStyle: \(inspector.displayStyle)")
            print("\(indent)🎨 [CustomView] XRAY children count: \(inspector.children.count)")
            print("\(indent)🎨 [CustomView] Mirror children count: \(mirror.children.count)")
            
            // **DEEP PROPERTY EXTRACTION** - Get ALL information from this view
            print("\(indent)🎨 [CustomView] === DEEP PROPERTY EXTRACTION ===")
            
            // Extract from XRAY
            print("\(indent)🎨 [CustomView] --- XRAY Properties ---")
            for (index, child) in inspector.children.enumerated() {
                let label = child.label ?? "<unlabeled-\(index)>"
                let childType = type(of: child.value)
                let childTypeName = String(describing: childType)
                let valueStr = String(describing: child.value)
                print("\(indent)🎨 [CustomView]   [\(index)] '\(label)': \(childTypeName)")
                
                // HUGE LOG
                //print("\(indent)🎨 [CustomView]       Value: \(valueStr)")
                
                // **DEEP RECURSE into the actual value object**
                // Check if the value itself is a View - if so, traverse it immediately!
                if let valueAsView = child.value as? any View {
                    print("\(indent)🎨 [CustomView]       🚀 VALUE IS A VIEW! Recursing into it...")
                    traverse(view: valueAsView, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                    continue
                }
                
                // **SPECIAL HANDLING for SwiftUI internal collection types**
                // These types contain nested Views/Modifiers but don't conform to View themselves
                if childTypeName.contains("ModifiedElements") ||
                    childTypeName.contains("SubgraphElements") ||
                    childTypeName.contains("UnaryElements") ||
                    childTypeName.contains("LazyContainerModifier") ||
                    childTypeName.contains("TypedUnaryViewGenerator") ||
                    childTypeName.contains("CollectionViewListRoot") ||
                    childTypeName.contains("TupleView") {
                    print("\(indent)🎨 [CustomView]       ⚙️ SWIFTUI INTERNAL STRUCTURE DETECTED! Deep diving...")
                    
                    // Recursively traverse into this structure
                    let structInspector = RunTimeTypeInspector(subject: child.value)
                    print("\(indent)🎨 [CustomView]         Structure has \(structInspector.children.count) properties")
                    
                    for (structIdx, structChild) in structInspector.children.enumerated() {
                        let structLabel = structChild.label ?? "<unlabeled>"
                        let structType = type(of: structChild.value)
                        print("\(indent)🎨 [CustomView]         [\(structIdx)] '\(structLabel)': \(structType)")
                        
                        // Check if it's a View
                        if let structView = structChild.value as? any View {
                            print("\(indent)🎨 [CustomView]           ✅ IS A VIEW! Traversing...")
                            traverse(view: structView, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                        } else {
                            // Recursively go deeper into nested structures
                            let deepStructInspector = RunTimeTypeInspector(subject: structChild.value)
                            if deepStructInspector.children.count > 0 {
                                print("\(indent)🎨 [CustomView]             Going deeper (\(deepStructInspector.children.count) children)...")
                                for (deepIdx, deepChild) in deepStructInspector.children.enumerated() {
                                    let deepLabel = deepChild.label ?? "<unlabeled>"
                                    let deepType = type(of: deepChild.value)
                                    let deepTypeName = String(describing: deepType)
                                    
                                    if let deepView = deepChild.value as? any View {
                                        print("\(indent)🎨 [CustomView]               ✅ Found View '\(deepLabel)': \(deepType)")
                                        traverse(view: deepView, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                                    }
                                    else if deepTypeName.contains("ModifiedElements") ||
                                                deepTypeName.contains("SubgraphElements") ||
                                                deepTypeName.contains("UnaryElements") ||
                                                deepTypeName.contains("TupleView") {
                                        // Recursively handle nested internal structures
                                        print("\(indent)🎨 [CustomView]               🔄 Nested internal structure '\(deepLabel)', recursing...")
                                        // Use traverse with the structure itself to handle it
                                        traverse(view: deepChild.value, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                                    }
                                }
                            }
                        }
                    }
                    continue
                }
                
                // Deep inspect this property
                let propInspector = RunTimeTypeInspector(subject: child.value)
                if propInspector.children.count > 0 {
                    print("\(indent)🎨 [CustomView]       Nested properties (\(propInspector.children.count)):")
                    for (subIdx, subChild) in propInspector.children.enumerated() {
                        let subLabel = subChild.label ?? "<unlabeled-\(subIdx)>"
                        let subType = type(of: subChild.value)
                        let subValue = String(describing: subChild.value)
                        print("\(indent)🎨 [CustomView]         [\(subIdx)] '\(subLabel)': \(subType) = \(subValue)")
                        
                        // **DEEP RECURSE into nested value**
                        if let nestedView = subChild.value as? any View {
                            print("\(indent)🎨 [CustomView]           🚀 NESTED VALUE IS A VIEW! Recursing...")
                            traverse(view: nestedView, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                        } else {
                            // Go even deeper - check if this nested value contains Views
                            let deeperInspector = RunTimeTypeInspector(subject: subChild.value)
                            if deeperInspector.children.count > 0 {
                                print("\(indent)🎨 [CustomView]           Going deeper (\(deeperInspector.children.count) children)...")
                                for (deepIdx, deepChild) in deeperInspector.children.enumerated() {
                                    if let deepView = deepChild.value as? any View {
                                        let deepLabel = deepChild.label ?? "<unlabeled>"
                                        print("\(indent)🎨 [CustomView]             🚀 DEEP CHILD '\(deepLabel)' IS A VIEW! Recursing...")
                                        traverse(view: deepView, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Check if it's special
                if label == "body" || label == "_body" {
                    print("\(indent)🎨 [CustomView]       🎯 This is the body property!")
                }
                if child.value is (any View) {
                    print("\(indent)🎨 [CustomView]       ✅ This property IS a View!")
                }
            }
            
            // Extract from Mirror (might find different things)
            print("\(indent)🎨 [CustomView] --- Mirror Properties ---")
            for (index, child) in mirror.children.enumerated() {
                let label = child.label ?? "<unlabeled-\(index)>"
                let childType = type(of: child.value)
                let childTypeName = String(describing: childType)
                let valueStr = String(describing: child.value)
                print("\(indent)🎨 [CustomView]   [\(index)] '\(label)': \(childTypeName)")
                // HUGE LOG
                //print("\(indent)🎨 [CustomView]       Value: \(valueStr)")
                
                // **DEEP RECURSE into the actual Mirror value object**
                if let valueAsView = child.value as? any View {
                    print("\(indent)🎨 [CustomView]       🚀 MIRROR VALUE IS A VIEW! Recursing into it...")
                    traverse(view: valueAsView, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                    continue
                }
                
                // Deep inspect via Mirror
                let propMirror = Mirror(reflecting: child.value)
                if propMirror.children.count > 0 {
                    print("\(indent)🎨 [CustomView]       Nested properties (\(propMirror.children.count)):")
                    for (subIdx, subChild) in propMirror.children.enumerated() {
                        let subLabel = subChild.label ?? "<unlabeled-\(subIdx)>"
                        let subType = type(of: subChild.value)
                        let subValue = String(describing: subChild.value)
                        print("\(indent)🎨 [CustomView]         [\(subIdx)] '\(subLabel)': \(subType) = \(subValue)")
                        
                        // **DEEP RECURSE into nested Mirror value**
                        if let nestedView = subChild.value as? any View {
                            print("\(indent)🎨 [CustomView]           🚀 NESTED MIRROR VALUE IS A VIEW! Recursing...")
                            traverse(view: nestedView, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                        } else {
                            // Go even deeper via Mirror
                            let deeperMirror = Mirror(reflecting: subChild.value)
                            if deeperMirror.children.count > 0 {
                                print("\(indent)🎨 [CustomView]           Going deeper via Mirror (\(deeperMirror.children.count) children)...")
                                for (deepIdx, deepChild) in deeperMirror.children.enumerated() {
                                    if let deepView = deepChild.value as? any View {
                                        let deepLabel = deepChild.label ?? "<unlabeled>"
                                        print("\(indent)🎨 [CustomView]             🚀 DEEP MIRROR CHILD '\(deepLabel)' IS A VIEW! Recursing...")
                                        traverse(view: deepView, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            print("\(indent)🎨 [CustomView] === END DEEP EXTRACTION ===")
            
            // Log all properties summary
            print("\(indent)🎨 [CustomView] === All Properties Summary ===")
            for (index, child) in inspector.children.enumerated() {
                let label = child.label ?? "<unlabeled>"
                let childType = type(of: child.value)
                let childTypeName = String(describing: childType)
                print("\(indent)🎨 [CustomView]   Property[\(index)]: '\(label)' type=\(childTypeName)")
                
                // Check if it's the body or a View
                if label == "body" || label == "_body" {
                    print("\(indent)🎨 [CustomView]     🎯 Found body property!")
                }
                if child.value is (any View) {
                    print("\(indent)🎨 [CustomView]     ✅ This property is a View!")
                }
            }
            
            // Strategy 1: Traverse ALL View properties discovered by deep extraction
            print("\(indent)🎨 [CustomView] === Strategy 1: Traverse discovered View properties ===")
            var foundViews = 0
            
            // First, check XRAY children for Views
            for (index, child) in inspector.children.enumerated() {
                let label = child.label ?? "<unlabeled-\(index)>"
                
                if let childView = child.value as? any View {
                    let childType = type(of: childView)
                    print("\(indent)🎨 [CustomView]   ✅ XRAY property[\(index)] '\(label)' (\(childType)) IS a View! Traversing...")
                    traverse(view: childView, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                    foundViews += 1
                }
            }
            
            // Also check Mirror children
            for (index, child) in mirror.children.enumerated() {
                let label = child.label ?? "<unlabeled-\(index)>"
                
                if let childView = child.value as? any View {
                    let childType = type(of: childView)
                    print("\(indent)🎨 [CustomView]   ✅ Mirror property[\(index)] '\(label)' (\(childType)) IS a View! Traversing...")
                    traverse(view: childView, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                    foundViews += 1
                }
            }
            
            if foundViews > 0 {
                print("\(indent)🎨 [CustomView] Successfully traversed \(foundViews) View properties")
                print("\(indent)🎨 [CustomView] ================================================")
                return
            }
            
            // Strategy 2: Try body property access
            print("\(indent)🎨 [CustomView] === Strategy 2: Direct body access ===")
            
            // Check all Mirror children, including unlabeled ones
            print("\(indent)🎨 [CustomView] Checking all Mirror children (including unlabeled)...")
            for (index, child) in mirror.children.enumerated() {
                let label = child.label ?? "<unlabeled-\(index)>"
                let childType = type(of: child.value)
                print("\(indent)🎨 [CustomView]   Mirror child[\(index)] '\(label)': \(childType)")
                
                // Check if this is a View (might be the body!)
                if let childView = child.value as? any View {
                    print("\(indent)🎨 [CustomView]   ✅ Mirror child[\(index)] '\(label)' IS a View! This might be the evaluated body!")
                    traverse(view: childView, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                    print("\(indent)🎨 [CustomView] ================================================")
                    return
                }
            }
            
            let bodyProps = ["body", "_body", "wrappedValue", "some"]
            for bodyProp in bodyProps {
                if let bodyValue = mirror.descendant(bodyProp) {
                    let bodyType = type(of: bodyValue)
                    print("\(indent)🎨 [CustomView]   Found '\(bodyProp)': \(bodyType)")
                    
                    if let bodyView = bodyValue as? any View {
                        print("\(indent)🎨 [CustomView]   ✅ '\(bodyProp)' is a View! Traversing...")
                        traverse(view: bodyView, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                        print("\(indent)🎨 [CustomView] ================================================")
                        return
                    } else {
                        print("\(indent)🎨 [CustomView]   ⚠️ '\(bodyProp)' found but not castable to View")
                        // Try to inspect what's inside
                        let bodyInspector = RunTimeTypeInspector(subject: bodyValue)
                        print("\(indent)🎨 [CustomView]   '\(bodyProp)' has \(bodyInspector.children.count) children")
                        for (idx, bChild) in bodyInspector.children.enumerated() {
                            let bLabel = bChild.label ?? "<unlabeled>"
                            let bType = type(of: bChild.value)
                            print("\(indent)🎨 [CustomView]     Child[\(idx)] '\(bLabel)': \(bType)")
                            if let bView = bChild.value as? any View {
                                print("\(indent)🎨 [CustomView]     ✅ Body child is a View! Traversing...")
                                traverse(view: bView, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                                print("\(indent)🎨 [CustomView] ================================================")
                                return
                            }
                        }
                    }
                } else {
                    print("\(indent)🎨 [CustomView]   Property '\(bodyProp)': NOT FOUND")
                }
            }
            
            // Strategy 3: Try using XRAY to extract body
            print("\(indent)🎨 [CustomView] === Strategy 3: XRAY body extraction ===")
            let xrayDecoder = XrayDecoder(subject: view)
            for bodyProp in bodyProps {
                if let extracted = xrayDecoder.childIfPresent(.key(bodyProp)) {
                    let extractedType = type(of: extracted)
                    print("\(indent)🎨 [CustomView]   XRAY extracted '\(bodyProp)': \(extractedType)")
                    
                    if let bodyView = extracted as? any View {
                        print("\(indent)🎨 [CustomView]   ✅ XRAY '\(bodyProp)' is a View! Traversing...")
                        traverse(view: bodyView, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                        print("\(indent)🎨 [CustomView] ================================================")
                        return
                    }
                }
            }
            
            // Strategy 4: Deep nested search - look inside EVERY property for Views
            print("\(indent)🎨 [CustomView] === Strategy 4: Deep nested View search ===")
            foundViews = 0
            
            // Check nested properties in XRAY children
            for (index, child) in inspector.children.enumerated() {
                let label = child.label ?? "<unlabeled>"
                print("\(indent)🎨 [CustomView]   Deep inspecting XRAY property[\(index)] '\(label)'...")
                
                let childInspector = RunTimeTypeInspector(subject: child.value)
                print("\(indent)🎨 [CustomView]     Has \(childInspector.children.count) nested children")
                
                for (subIndex, subChild) in childInspector.children.enumerated() {
                    let subLabel = subChild.label ?? "<unlabeled>"
                    let subType = type(of: subChild.value)
                    
                    if let subView = subChild.value as? any View {
                        print("\(indent)🎨 [CustomView]     ✅ Found View at nested level [\(subIndex)] '\(subLabel)': \(subType)")
                        traverse(view: subView, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                        foundViews += 1
                    } else {
                        // Go even deeper - 3 levels
                        let deeperInspector = RunTimeTypeInspector(subject: subChild.value)
                        if deeperInspector.children.count > 0 {
                            print("\(indent)🎨 [CustomView]       Nested child '\(subLabel)' has \(deeperInspector.children.count) children, checking...")
                            for (deepIdx, deepChild) in deeperInspector.children.enumerated() {
                                if let deepView = deepChild.value as? any View {
                                    let deepLabel = deepChild.label ?? "<unlabeled>"
                                    print("\(indent)🎨 [CustomView]         ✅ Found View at 3rd level [\(deepIdx)] '\(deepLabel)'")
                                    traverse(view: deepView, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                                    foundViews += 1
                                }
                            }
                        }
                    }
                }
            }
            
            // Also check nested in Mirror children
            for (index, child) in mirror.children.enumerated() {
                let label = child.label ?? "<unlabeled>"
                print("\(indent)🎨 [CustomView]   Deep inspecting Mirror property[\(index)] '\(label)'...")
                
                let childMirror = Mirror(reflecting: child.value)
                print("\(indent)🎨 [CustomView]     Has \(childMirror.children.count) nested children")
                
                for (subIndex, subChild) in childMirror.children.enumerated() {
                    let subLabel = subChild.label ?? "<unlabeled>"
                    
                    if let subView = subChild.value as? any View {
                        let subType = type(of: subView)
                        print("\(indent)🎨 [CustomView]     ✅ Found View at nested level [\(subIndex)] '\(subLabel)': \(subType)")
                        traverse(view: subView, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                        foundViews += 1
                    }
                }
            }
            
            if foundViews > 0 {
                print("\(indent)🎨 [CustomView] Successfully traversed \(foundViews) nested Views")
            } else {
                print("\(indent)🎨 [CustomView] ⚠️ Could not access body property via reflection")
                print("\(indent)🎨 [CustomView] 📝 NOTE: Custom SwiftUI View bodies are computed properties")
                print("\(indent)🎨 [CustomView] 📝 They are not accessible via Mirror/reflection at runtime")
                print("\(indent)🎨 [CustomView] ✅ However, modifiers applied TO this view have already been captured!")
                print("\(indent)🎨 [CustomView] Current ID '\(currentID)' has \(associations[currentID]?.count ?? 0) modifier(s)")
                
                // Show what modifiers we captured for this view
                if let mods = associations[currentID], !mods.isEmpty {
                    print("\(indent)🎨 [CustomView] Captured modifiers for '\(viewTypeName)':")
                    for (idx, mod) in mods.enumerated() {
                        let modType = type(of: mod)
                        print("\(indent)🎨 [CustomView]   [\(idx)] \(modType)")
                    }
                }
            }
            print("\(indent)🎨 [CustomView] ================================================")
            return
        }
        // **Case 8: True Base View or Non-View Type**
        // If we reach here, it's not a View at all, or it's a primitive SwiftUI view
        // HOWEVER: SwiftUI internal classes like Item don't conform to View but DO contain views
        // So we need to traverse into their children to find the actual views
        else {
            print("\(indent)🛑 [Base/Unknown] ================================================")
            print("\(indent)🛑 [Base/Unknown] Reached non-View type: \(viewTypeName)")
            print("\(indent)🛑 [Base/Unknown] DisplayStyle: \(inspector.displayStyle)")
            print("\(indent)🛑 [Base/Unknown] ================================================")
            if inspector.displayStyle == .enum(case: "node") {
                print("FOUND THE GOLDMIND foud node")
                // I believe at this point we'll need to use Deep Reflection on the cast Any data
                let mirroredGold = Mirror(reflecting: view)
                
                print("Tyoe = \(mirroredGold.subjectType)")
                print("Desc = \(mirroredGold.description)")

                // at this point view =
                /*
                 Printing description of view:
                 ▿ Stack<AnySource>
                   ▿ node : 2 elements
                     ▿ value : AnySource
                       - formula : SwiftUI.(unknown context at $1d43b5418).SourceFormula<SwiftUI.ModifiedContent<SwiftUI.ModifiedContent<SwiftUI.ModifiedContent<SwiftUI.ModifiedContent<SwiftUI.ListStyleContent, SwiftUI.StaticIf<SwiftUI._SemanticFeature_v4_4, SwiftUI.(unknown context at $1d438272c).RefreshScopeModifier, SwiftUI.EmptyModifier>>, SwiftUI.StaticIf<SwiftUI._SemanticFeature_v6, SwiftUI.ResetScrollEnvironmentModifier, SwiftUI.EmptyModifier>>, SwiftUI.(unknown context at $1d4e6fda8).ResetScrollInputsModifier>, SwiftUI.(unknown context at $1d436d814).ResetContentMarginModifier>>
                       ▿ value : #11897
                         ▿ _details : __Unnamed_struct__details
                           ▿ identifier : #11897
                             - rawValue : 11897
                           - seed : 4
                       - valueIsNil : nil
                     ▿ next : Stack<AnySource>
                       ▿ node : 2 elements
                         ▿ value : AnySource
                           - formula : SwiftUI.(unknown context at $1d43b5418).SourceFormula<SwiftUI.ModifiedContent<SwiftUI.ModifiedContent<SwiftUI.ModifiedContent<SwiftUI.ModifiedContent<SwiftUI.TupleView<(SwiftUI.NavigationLink<SwiftUI.ModifiedContent<SwiftUI.Text, SwiftUI.AccessibilityAttachmentModifier>, NRTestApp.MaskingView>, SwiftUI.NavigationLink<SwiftUI.Text, NRTestApp.ButtonsView>, SwiftUI.NavigationLink<SwiftUI.Text, NRTestApp.TextFieldsView>, SwiftUI.NavigationLink<SwiftUI.Text, NRTestApp.PickersView>, SwiftUI.NavigationLink<SwiftUI.Text, NRTestApp.TogglesView>, SwiftUI.NavigationLink<SwiftUI.Text, NRTestApp.SlidersView>, SwiftUI.NavigationLink<SwiftUI.Text, NRTestApp.SteppersView>, SwiftUI.NavigationLink<SwiftUI.Text, NRTestApp.DatePickersView>, SwiftUI.NavigationLink<SwiftUI.Text, NRTestApp.ProgressViewsView>, SwiftUI.NavigationLink<SwiftUI.Text, NRTestApp.SegmentedControlsView>, SwiftUI.NavigationLink<SwiftUI.Text, NRTestApp.ListsView>, SwiftUI.NavigationLink<SwiftUI.Text, NRTestApp.ScrollViewsView>, SwiftUI.NavigationLink<SwiftUI.Text, NRTestApp.StacksView>, SwiftUI.NavigationLink<SwiftUI.Text, NRTestApp.GridsView>, SwiftUI.NavigationLink<SwiftUI.Text, NRTestApp.ShapesView>)>, SwiftUI.StaticIf<SwiftUI._SemanticFeature_v4_4, SwiftUI.(unknown context at $1d438272c).RefreshScopeModifier, SwiftUI.EmptyModifier>>, SwiftUI.StaticIf<SwiftUI._SemanticFeature_v6, SwiftUI.ResetScrollEnvironmentModifier, SwiftUI.EmptyModifier>>, SwiftUI.(unknown context at $1d4e6fda8).ResetScrollInputsModifier>, SwiftUI.(unknown context at $1d436d814).ResetContentMarginModifier>>
                           ▿ value : #9273
                             ▿ _details : __Unnamed_struct__details
                               ▿ identifier : #9273
                                 - rawValue : 9273
                               - seed : 3
                           - valueIsNil : nil
                         - next : SwiftUI.Stack<SwiftUI.(unknown context at $1d43b5474).AnySource>.empty
                 */
                print("Found mirrored gold")
            }
            // **Use XRAY to inspect and TRAVERSE children that might contain Views**
            let baseInspector = RunTimeTypeInspector(subject: view)
            if baseInspector.children.count > 0 {
                print("\(indent)🔎 [Base/Unknown] XRAY found \(baseInspector.children.count) children - inspecting for Views...")
                
                // SPECIAL DETECTION: Check if this is an AttributeGraph Item with view type metadata
                // If the 'type' property contains the views we want, we need a different strategy
                var hasInterestingTypeMetadata = false
                var typeMetadataString = ""
                
                for (index, child) in baseInspector.children.enumerated() {
                    let label = child.label ?? "<unlabeled>"
                    if label == "type" {
                        let childTypeName = String(describing: type(of: child.value))
                        if childTypeName.hasSuffix(".Type") {
                            typeMetadataString = childTypeName
                            // Check if this metatype contains views we care about
                            if childTypeName.contains("NavigationLink") ||
                                childTypeName.contains("TupleView") ||
                                childTypeName.contains("ModifiedContent") {
                                hasInterestingTypeMetadata = true
                                print("\(indent)🔎 [Base/Unknown] 🎯 DETECTED: Item with view metadata in 'type' property!")
                                print("\(indent)🔎 [Base/Unknown]    Type contains: NavigationLink/TupleView/ModifiedContent")
                                print("\(indent)🔎 [Base/Unknown]    Need to find the actual instance corresponding to this type...")
                                break
                            }
                        }
                    }
                }
                
                var foundViews = 0
                for (index, child) in baseInspector.children.enumerated() {
                    let label = child.label ?? "<unlabeled>"
                    let childType = type(of: child.value)
                    let childTypeName = String(describing: childType)
                    print("\(indent)🔎 [Base/Unknown]   Child[\(index)]: '\(label)' -> \(childTypeName)")
                    
//                    // Skip metatypes - they're type information, not instances
//                    if label == "type" && childTypeName.hasSuffix(".Type") {
//                        print("\(indent)🔎 [Base/Unknown]     ⏭️  Skipping metatype (it's type info, not an instance)")
//                        
//                        // BUT - if this metatype has interesting views, try to find instance in other properties
//                        if hasInterestingTypeMetadata {
//                            print("\(indent)🔎 [Base/Unknown]     💡 But type metadata shows views exist - searching OTHER properties more aggressively...")
//                        }
//                        continue
//                    }
                    
                    // Check if this child is a View - if so, traverse it!
                    if let childView = child.value as? any View {
                        print("\(indent)🔎 [Base/Unknown]     ✅ Child '\(label)' IS a View! Traversing...")
                        traverse(view: childView, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                        foundViews += 1
                    } else {
                        print("\(indent)🔎 [Base/Unknown]     ⚠️  Child '\(label)' is not a View")
                        
                        // **AGGRESSIVE DEEP SEARCH**: For SwiftUI internal types like Item,
                        // the view instance might be nested several levels deep.
                        // We need to search EVERY property recursively to find views.
                        
                        // IMPORTANT: Skip circular references and collections we've already processed
                        // allItems creates infinite loops - we already handle it in ListView case
//                        if label == "allItems" || label == "_allItems" {
//                            print("\(indent)🔎 [Base/Unknown]     ⏭️  Skipping '\(label)' (circular reference - already processed in array iteration)")
//                            continue  // Don't search this property
//                        }
                        
                        print("\(indent)🔎 [Base/Unknown]     🔍 Searching property '\(label)' recursively for views...")
                        
                        // Recursive search function - goes limited depth
                        // Uses BOTH Mirror and RunTimeTypeInspector for maximum coverage
                        func searchForViews(in value: Any, path: String, currentDepth: Int, maxDepth: Int = 6) {
                            let searchIndent = indent + String(repeating: "  ", count: currentDepth)
                            
                            if currentDepth > maxDepth {
                                print("\(searchIndent)⚠️ Max depth reached at \(path)")
                                return
                            }
                            
                            print("\(searchIndent)🔎 Depth \(currentDepth) searching: \(path)")
                            
                            // Use BOTH Mirror and XRAY to find children
                            let mirror = Mirror(reflecting: value)
                            let inspector = RunTimeTypeInspector(subject: value)
                            
                            print("\(searchIndent)  Mirror: \(mirror.children.count) children, XRAY: \(inspector.children.count) children")
                            
                            // Combine children from both sources
                            var allChildren: [(label: String?, value: Any)] = []
                            
                            // Add Mirror children
                            for (idx, child) in mirror.children.enumerated() {
                                allChildren.append((child.label ?? "<mirror-\(idx)>", child.value))
                            }
                            
                            // Add XRAY children (might find different things)
                            for (idx, child) in inspector.children.enumerated() {
                                let label = child.label ?? "<xray-\(idx)>"
                                // Only add if not duplicate (check by label)
                                if !allChildren.contains(where: { $0.label == child.label && child.label != nil }) {
                                    allChildren.append((label, child.value))
                                }
                            }
                            
                            print("\(searchIndent)  Combined: \(allChildren.count) total children")
                            
                            for (idx, child) in allChildren.enumerated() {
                                let childLabel = child.label ?? "<unlabeled-\(idx)>"
                                let childPath = path + ".\(childLabel)"
                                let childType = type(of: child.value)
                                let childTypeName = String(describing: childType)
                                
                                // Check if this is a View
                                if let childView = child.value as? any View {
                                    print("\(searchIndent)  ✅ FOUND View at: \(childPath)")
                                    traverse(view: childView, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                                    foundViews += 1
                                } else {
                                    // Not a view - check if it's something we should traverse
                                    
                                    // someitme it comes in as
                                    /*
                                     Printing description of childTypeName:
                                     (value: AnySource, next: Stack<AnySource>)
                                     */
                                    
                                    /*
                                     we need to extract the `formula from
                                     ▿ 0 : 2 elements
                                       ▿ label : Optional<String>
                                         - some : "formula"
                                       - value : SwiftUI.(unknown context at $1d43b5418).SourceFormula<SwiftUI.ModifiedContent<SwiftUI.ModifiedContent<SwiftUI.ModifiedContent<SwiftUI.ModifiedContent<SwiftUI.ListStyleContent, SwiftUI.StaticIf<SwiftUI._SemanticFeature_v4_4, SwiftUI.(unknown context at $1d438272c).RefreshScopeModifier, SwiftUI.EmptyModifier>>, SwiftUI.StaticIf<SwiftUI._SemanticFeature_v6, SwiftUI.ResetScrollEnvironmentModifier, SwiftUI.EmptyModifier>>, SwiftUI.(unknown context at $1d4e6fda8).ResetScrollInputsModifier>, SwiftUI.(unknown context at $1d436d814).ResetContentMarginModifier>>

                                     */
                                    
                                    print("\(searchIndent)  [\(idx)] '\(childLabel)': \(childTypeName)")
                                    if childTypeName == "__Unnamed_struct__details" {
                                        print("found deep details")
                                    }
                                    if childLabel == "formula" {
                                        print("found a formula label")
                                        print("found goldmine formula: \(child.value)")
                                        // Tnis is where Im at on 10/04/25
                                    }
                                    if childTypeName == "formula" {
                                        print("found formla")
                                    }
                                    // IMPORTANT: Exclude graph attributes - they're just references, not actual instances
                                    if childTypeName.starts(with: "Attribute<") ||
                                        childTypeName.starts(with: "WeakAttribute<") ||
                                        childTypeName.starts(with: "MutableBox<") {
                                        print("\(searchIndent)    ⏭️  Skipping graph attribute/wrapper (not a view instance)")
                                        // Still search deeper - might contain actual instances
                                        searchForViews(in: child.value, path: childPath, currentDepth: currentDepth + 1, maxDepth: maxDepth)
                                        continue
                                    }
                                    
                                    // Check for SwiftUI internal structures that should be traversed
                                    if childTypeName.contains("ModifiedContent") ||
                                        childTypeName.contains("ModifiedElements") ||
                                        childTypeName.contains("SubgraphElements") ||
                                        childTypeName.contains("UnaryElements") ||
                                        childTypeName.contains("TupleView") ||
                                        childTypeName.contains("NavigationLink") ||
                                        childTypeName.contains("VStack") ||
                                        childTypeName.contains("HStack") ||
                                        childTypeName.contains("ZStack") ||
                                        childTypeName.contains("ResolvedList") ||
                                        childTypeName.contains("ViewList") ||
                                        childTypeName == "List" {  // Exact match for List, not substring
                                        print("\(searchIndent)    🔄 SwiftUI structure! Traversing...")
                                        traverse(view: child.value, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                                        foundViews += 1
                                    } else {
                                        // Continue searching deeper for nested views
                                        searchForViews(in: child.value, path: childPath, currentDepth: currentDepth + 1, maxDepth: maxDepth)
                                    }
                                }
                            }
                        }
                        
                        // Start the recursive search from this property
                        searchForViews(in: child.value, path: label, currentDepth: 1)
                    }
                }
                
                if foundViews > 0 {
                    print("\(indent)🔎 [Base/Unknown] ✅ Successfully traversed \(foundViews) View(s) from children")
                } else {
                    print("\(indent)🔎 [Base/Unknown] ⚠️  No Views found in children - this may be a true leaf")
                    
                    // LAST RESORT: If we have interesting type metadata but found no views,
                    // try using Mirror to access the underlying object storage directly
                    if hasInterestingTypeMetadata {
                        print("\(indent)🔎 [Base/Unknown] 🔬 LAST RESORT: Type metadata shows views exist but none found")
                        print("\(indent)🔎 [Base/Unknown] 🔬 Attempting direct memory inspection via Mirror...")
                        
                        let viewMirror = Mirror(reflecting: view)
                        print("\(indent)🔎 [Base/Unknown] 🔬 Mirror children: \(viewMirror.children.count)")
                        
                        // Try to access any properties that might hold the actual instance
                        let potentialInstanceProps = ["value", "instance", "storage", "body", "content",
                                                      "wrappedValue", "projectedValue", "_value", "_instance",
                                                      "_storage", "_body", "_content", "base", "view"]
                        
                        for propName in potentialInstanceProps {
                            if let propValue = viewMirror.descendant(propName) {
                                print("\(indent)🔎 [Base/Unknown] 🔬 Found property '\(propName)': \(type(of: propValue))")
                                
                                if let propView = propValue as? any View {
                                    print("\(indent)🔎 [Base/Unknown] 🔬 ✅ '\(propName)' IS A VIEW! Traversing...")
                                    traverse(view: propView, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                                    foundViews += 1
                                }
                            }
                        }
                        
                        // Also try treating the view itself as having an unwrapped type
                        // Sometimes the metadata and instance are stored together
                        print("\(indent)🔎 [Base/Unknown] 🔬 Attempting to access via type cast...")
                        print("\(indent)🔎 [Base/Unknown] 🔬 Type metadata was: \(typeMetadataString)")
                        
                        if foundViews == 0 {
                            print("\(indent)🔎 [Base/Unknown] 🔬 ❌ Could not locate view instance despite type metadata")
                            print("\(indent)🔎 [Base/Unknown] 🔬 💡 Attempting to access via graph traversal methods...")
                            
                            // CRITICAL INSIGHT: Item nodes in AttributeGraph contain type metadata,
                            // but actual view instances may be in associated subgraphs or value storage
                            
                            // Try to find and follow contentSubgraph, subgraph, or similar properties
                            // that might point to actual view instances
                            for (index, child) in baseInspector.children.enumerated() {
                                let label = child.label ?? "<unlabeled>"
                                
                                // Look for properties that might contain or point to instances
                                if label == "contentSubgraph" || label == "subgraph" ||
                                    label == "_value" || label == "value" ||
                                    label == "storage" || label == "_storage" {
                                    
                                    print("\(indent)🔎 [Base/Unknown] 🔬 Found potential instance container: '\(label)'")
                                    let childType = type(of: child.value)
                                    print("\(indent)🔎 [Base/Unknown] 🔬   Type: \(childType)")
                                    
                                    // Try to traverse into this property recursively
                                    let deepInspector = RunTimeTypeInspector(subject: child.value)
                                    print("\(indent)🔎 [Base/Unknown] 🔬   Has \(deepInspector.children.count) children")
                                    
                                    for (deepIdx, deepChild) in deepInspector.children.enumerated() {
                                        let deepLabel = deepChild.label ?? "<unlabeled>"
                                        let deepType = type(of: deepChild.value)
                                        print("\(indent)🔎 [Base/Unknown] 🔬     [\(deepIdx)] '\(deepLabel)': \(deepType)")
                                        
                                        if let deepView = deepChild.value as? any View {
                                            print("\(indent)🔎 [Base/Unknown] 🔬 ✅ FOUND VIEW in '\(label).\(deepLabel)'!")
                                            traverse(view: deepView, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
                                            foundViews += 1
                                        }
                                    }
                                }
                            }
                            
                            if foundViews == 0 {
                                print("\(indent)🔎 [Base/Unknown] 🔬 ❌ Still no views - instances are in external graph storage")
                                print("\(indent)🔎 [Base/Unknown] 🔬 💡 AGGRESSIVE MIRROR TRAVERSAL: Trying to access ViewList via Attribute...")
                                
                                // CRITICAL: The Item has _list: Attribute<ViewList>
                                // We need to try to dereference this attribute to get the actual ViewList
                                // which should have a contentSubgraph with the view instances
                                
                                // Use Mirror to access _list property
                                let itemMirror = Mirror(reflecting: view)
                                if let listAttr = itemMirror.descendant("_list") {
                                    print("\(indent)🔎 [Base/Unknown] 🔬 Found '_list' attribute via Mirror")
                                    let listAttrType = type(of: listAttr)
                                    print("\(indent)🔎 [Base/Unknown] 🔬   Type: \(listAttrType)")
                                    
                                    // Try to access the graph and follow the attribute reference
                                    // Attributes in SwiftUI's AttributeGraph are references (IDs)
                                    // We need to find if there's a way to dereference them
                                    let runtimeInspected = RunTimeTypeInspector(subject: listAttr)
                                    
                                    print(runtimeInspected.subject)
                                    
                                    let listAttrMirror = Mirror(reflecting: listAttr)
                                    print("\(indent)🔎 [Base/Unknown] 🔬   Attribute has \(listAttrMirror.children.count) properties")
                                                                        
//                                    // Deep dive into EVERY property of the attribute
//                                    func deepMirrorSearch(value: Any, path: String, depth: Int, maxDepth: Int = 10) {
//                                        if depth > maxDepth { return }
//                                        
                                        let mirror = Mirror(reflecting: listAttr)
                                        for child in mirror.children {
                                            let label = child.label ?? "<unlabeled>"
                                            let fullPath = "\("path").\(label)"
                                            let childType = type(of: child.value)
                                            let childTypeName = String(describing: childType)
                                            
                                            print("\(indent)🔎 [Base/Unknown] 🔬   \(String(repeating: "  ", count: depth))\(fullPath): \(childTypeName)")
//                                            
//                                            // Check if it's a View
//                                            if let childView = child.value as? any View {
//                                                print("\(indent)🔎 [Base/Unknown] 🔬 ✅ FOUND VIEW at \(fullPath)!")
//                                                traverse(view: childView, currentID: currentID, associations: &associations, accumulating: &modifiers, depth: depth + 1)
//                                                foundViews += 1
//                                                return
//                                            }
//                                            
//                                            // Look for ViewList, contentSubgraph, or view containers
//                                            if childTypeName.contains("ViewList") ||
//                                                childTypeName.contains("Subgraph") ||
//                                                childTypeName.contains("ContentView") ||
//                                                label.contains("content") ||
//                                                label.contains("view") ||
//                                                label.contains("list") {
//                                                print("\(indent)🔎 [Base/Unknown] 🔬   └─ Interesting! Deep diving...")
//                                                deepMirrorSearch(value: child.value, path: fullPath, depth: depth + 1, maxDepth: maxDepth)
//                                            }
//                                        }
                                    }
                                    
                                   // deepMirrorSearch(value: listAttr, path: "_list", depth: 1)
                                }
                                
                                if foundViews == 0 {
                                    print("\(indent)🔎 [Base/Unknown] 🔬 ❌ FINAL FAILURE: Cannot access view instances")
                                    print("\(indent)🔎 [Base/Unknown] 🔬 💡 View instances are stored in AttributeGraph's contentSubgraph")
                                    print("\(indent)🔎 [Base/Unknown] 🔬 💡 which is separate from the Item metadata nodes")
                                    print("\(indent)🔎 [Base/Unknown] 🔬 💡 Need to access parent _ViewList_View.contentSubgraph")
                                }
                            }
                        }
                    }
                }
                
                print("\(indent)🛑 [Base/Unknown] ================================================")
            } else {
                print("\(indent)🔎 [Base/Unknown] XRAY found no children - this is a true leaf")
            }
        }
    }
}


/// A protocol to create a non-generic way to access the `rootView`
@available(iOS 13.0, tvOS 13.0, *)
protocol SwiftUIViewHost {
    /// Returns the underlying SwiftUI view, type-erased to `any View`.
    var anyRootView: any View { get }
}

/// Make UIHostingController conform to our protocol.
@available(iOS 13.0, tvOS 13.0, *)
extension UIHostingController: SwiftUIViewHost {
    /// The implementation simply returns the `rootView` property.
    var anyRootView: any View {
        return self.rootView
    }
}

/// This function takes any UIView and finds its underlying SwiftUI View.
/// - Parameter uiView: The UIView that is part of a UIHostingController's hierarchy.
/// - Returns: The type-erased SwiftUI `any View` if found, otherwise nil.
@available(iOS 13.0, tvOS 13.0, *)
func getSwiftUIView(from uiView: UIView) -> (any View)? {
    var responder: UIResponder? = uiView
    // Traverse the responder chain to find the view controller
    while responder != nil {
        // Check if the responder conforms to our protocol
        if let host = responder as? SwiftUIViewHost {
            // If it does, we can access its `anyRootView` property
            return host.anyRootView
        }
        responder = responder?.next
    }
    // No hosting controller was found in the responder chain
    return nil
}
