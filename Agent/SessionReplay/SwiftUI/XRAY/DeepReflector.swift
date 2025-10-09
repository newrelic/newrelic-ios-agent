import SwiftUI
import UIKit

/// 🔬 A framework for deeply reflecting on a SwiftUI View to extract its modifier chain.
@available(iOS 13.0, tvOS 13.0, *)
public enum DeepReflector {
    
    
    // The version that starts w. mirror
    
    //    public static func analyze(viewMirror: Mirror) -> [AnyHashable: [any ViewModifier]] {
    //        // print("\n🔬 [DeepReflection] ========== STARTING ANALYSIS ==========")
    //        let rootViewType = viewMirror.subjectType//"\(type(of: view))"
    //          print("🔬 [DeepReflection] RootView type: \(rootViewType)")
    //
    //
    //        //                 ModifiedContent<ModifiedContent<Element, NavigationColumnModifier>, StyleContextWriter<SidebarStyleContext>>
    //        //        if rootViewType == "ModifiedContent<ModifiedContent<Element, NavigationColumnModifier>, StyleContextWriter<SidebarStyleContext>>" {
    //        //            //print("caught")
    //        //            return [:]
    //        //        }
    //
    //        var associations: [AnyHashable: [any ViewModifier]] = [:]
    //        var modifiers: [any ViewModifier] = []
    //        // **NEW**: A set to track visited class instances to prevent infinite loops.
    //        var visited = Set<ObjectIdentifier>()
    //
    //        // Start the recursive traversal with the initial view.
    //        // The default ID of `0` catches any modifiers applied before the first `.id()` is found.
    //        traverse(view: viewMirror as Any, currentID: AnyHashable(0), associations: &associations, accumulating: &modifiers, visited: &visited, depth: 0)
    //
    //        //print("\n🔬 [DeepReflection] ========== ANALYSIS COMPLETE ==========")
    //        var count = 0
    //        // Final report logging
    //        for (id, mods) in associations.sorted(by: { String(describing: $0.key) < String(describing: $1.key) }) {
    //            // print("🔬 [DeepReflection] 📌 ID: '\(id)' -> \(mods.count) modifier(s)")
    //            for (idx, modifier) in mods.enumerated() {
    //                let modType = String(describing: type(of: modifier))
    //                count += 1
    //                //print("🔬 [DeepReflection]   [\(idx)] Type: \(modType)")
    //            }
    //        }
    //        print("🔬 [DeepReflection] Total unique IDs found: \(associations.keys.count) unique ID(s) \(count) total modifier(s)")
    //
    //        //print("🔬 [DeepReflection] ==========================================\n")
    //
    //        return associations
    //    }
    
    
    
    /// Analyzes an entire view hierarchy, extracting all modifiers and
    /// associating them with the nearest preceding `.id()` tag.
    ///
    /// - Parameter view: The SwiftUI View instance to inspect (typically from a UIHostingController).
    /// - Returns: A dictionary where keys are view IDs and values are the modifiers applied to that view.
    public static func analyze(view: any View) -> [AnyHashable: [any ViewModifier]] {
        // print("\n🔬 [DeepReflection] ========== STARTING ANALYSIS ==========")
        let rootViewType = "\(type(of: view))"
       //print("🔬 [DeepReflection] RootView type: \(rootViewType)")
        print("🔬 [DeepReflection] RootView type: [ROOT_VIEW_TYPE REMOVED]]")

        
        var associations: [AnyHashable: [any ViewModifier]] = [:]
        var modifiers: [any ViewModifier] = []
        // **NEW**: A set to track visited class instances to prevent infinite loops.
        var visited = Set<ObjectIdentifier>()
        
        // Start the recursive traversal with the initial view.
        // The default ID of `0` catches any modifiers applied before the first `.id()` is found.
        traverse(view: view, currentID: AnyHashable(0), associations: &associations, accumulating: &modifiers, visited: &visited, depth: 0)
        
        //print("\n🔬 [DeepReflection] ========== ANALYSIS COMPLETE ==========")
        var count = 0
        // Final report logging
        for (id, mods) in associations.sorted(by: { String(describing: $0.key) < String(describing: $1.key) }) {
             print("🔬 [DeepReflection] 📌 ID: '\(id)' -> \(mods.count) modifier(s)")
            for (idx, modifier) in mods.enumerated() {
                let modType = String(describing: type(of: modifier))
                count += 1
                print("🔬 [DeepReflection]   [\(idx)] Type: \(modType)")
            }
        }
        print("🔬 [DeepReflection] Total unique IDs found: \(associations.keys.count) unique ID(s) \(count) total modifier(s)")
        
        //print("🔬 [DeepReflection] ==========================================\n")
        
        return associations
    }
    
    /// **The Core Traversal Engine**: Recursively walks through the SwiftUI view hierarchy.
    ///
    /// This simplified engine focuses on stable, known SwiftUI wrappers and uses a generic
    /// fallback for all other container views, making it robust across iOS versions.
    private static func traverse(
        view: Any,
        currentID: AnyHashable,
        associations: inout [AnyHashable: [any ViewModifier]],
        accumulating modifiers: inout [any ViewModifier],
        visited: inout Set<ObjectIdentifier>, // Pass the tracker
        depth: Int
    ) {
        var foundDirectViews = false
        
        // Create indentation for readable logging.
        let indent = String(repeating: "  ", count: depth)
        
        // Prevent infinite recursion, which can happen with complex or cyclical view structures.
        guard depth < 43 else {
            //print("\(indent)⚠️ Max recursion depth reached. Halting traversal for this branch.")
            return
        }
        
        let viewTypeName = String(describing: type(of: view))
        
        print("\(indent) \(viewTypeName.prefix(60))")
        
        let mirror = Mirror(reflecting:view)

        
        // **Case 2: IDView** - This wrapper assigns an ID.
        // We update `currentID` for all subsequent views/modifiers found within its content.
        if viewTypeName.starts(with: "IDView<") {
            guard let content = mirror.descendant("content"),
                  let newID = mirror.descendant("id") as? AnyHashable else {
                return
            }
            //print("\(indent)  🆔 Found ID: \(newID)")
            
            // Continue traversal with the NEW ID.
            traverse(view: content, currentID: newID, associations: &associations, accumulating: &modifiers,visited: &visited, depth: depth + 1)
            return
        }
        
        // **Case 3: AnyView** - A type-erased wrapper. We need to unwrap it.
        if viewTypeName.starts(with: "AnyView") {
            // AnyView's content is internal. We reflect to find its 'storage' and then the 'view' within.
            if let storage = mirror.descendant("storage"), let underlyingView = Mirror(reflecting: storage).descendant("view") {
                //print("\(indent)  🎭 Unwrapped AnyView to \(type(of: underlyingView))")
                traverse(view: underlyingView, currentID: currentID, associations: &associations, accumulating: &modifiers, visited: &visited, depth: depth + 1)
            }
            return
        }
        
        if let view = view as? any View {
            // Attempt skip statemful wrappers that cause runtime issues.
            
//            if viewTypeName.starts(with: "Binding<") || viewTypeName.starts(with: "State<") || viewTypeName.starts(with: "Optional<Binding<") || viewTypeName.starts(with: "Array<Binding<"){ return }
//            // Does this avoid the runtime death?
//            if viewTypeName == "TextEditor" || viewTypeName == "TextField" || viewTypeName == "TextField<Text>" || viewTypeName == "State<String>" || viewTypeName == "Optional<Binding<Bool>>" { return }
            
            
            // SwiftUI Internal Wrappers
            if viewTypeName.starts(with: "ModifiedContent<") ||
                viewTypeName.starts(with: "ResolvedList<") ||
                viewTypeName.starts(with: "StaticIf<") ||
                viewTypeName.starts(with: "TupleView<") ||
                viewTypeName.starts(with: "PrimitiveNavigationLink<") ||
                viewTypeName.starts(with: "Optional<") ||
                viewTypeName.starts(with: "VStack<") ||
                viewTypeName.starts(with: "ZStack<") ||
                viewTypeName.starts(with: "HStack<") ||
                viewTypeName.starts(with: "Stack<") ||
                viewTypeName.starts(with: "Tree<") ||
                viewTypeName.starts(with: "Section<") ||
                viewTypeName.starts(with: "_ShapeView<") ||
                viewTypeName.starts(with: "CustomProgressView<") ||
                viewTypeName.starts(with: "ForEach<") ||
                viewTypeName.starts(with: "NavigationView<") ||
                viewTypeName.starts(with: "List<") ||
                viewTypeName.starts(with: "AnyViewStorage<") ||
                viewTypeName.starts(with: "NavigationLink<") ||
                viewTypeName.starts(with: "ScrollView<") ||
                viewTypeName.starts(with: "ResolvedPicker<") ||
                viewTypeName.starts(with: "LazyVGrid<") ||
                viewTypeName.starts(with: "LazyHGrid<") ||
                viewTypeName.starts(with: "LazyGrid<") ||
                viewTypeName.starts(with: "ResettableLazyLayoutRoot<") ||
                viewTypeName.starts(with: "ClipEffect<") ||
                viewTypeName.starts(with: "ModifiedElements<") ||
                //  viewTypeName.starts(with: "LazyView<") ||
                
                
                
                // Leaf views
                viewTypeName == "Element" ||
                viewTypeName == "ListStyleContent" ||
                viewTypeName == "Text" ||
                viewTypeName == "_TextFieldStyleLabel" ||
                viewTypeName == "_ViewList_View" ||
                viewTypeName == "Color" ||
                viewTypeName == "Spacer" ||
                viewTypeName == "Image" ||
                viewTypeName == "EmptyView" ||
                viewTypeName == "Label" ||
                viewTypeName == "Content" ||
                viewTypeName == "MinimumValueLabel" ||
                viewTypeName == "MaximumValueLabel" ||
                viewTypeName == "Divider" ||
                viewTypeName == "AnyView"
                
                
            {
                
                //               if  viewTypeName.starts(with:  "AnyViewStorage<") {
                //                    print("AnyViewStorage: %@", "\(view)")
                //                }
                //
                // **Case 1: SwftUI Internals or Leaf Views --- ModifiedContent** - The core of modifier extraction.
                // This is the wrapper for any `.modifier()` call. We peel it off and recurse.
                if viewTypeName.starts(with: "ModifiedContent") {
                    guard let content = mirror.descendant("content"),
                          let modifier = mirror.descendant("modifier") as? any ViewModifier else {
                        return
                    }
                    
                    // Add the found modifier to the dictionary for the current ID.
                    associations[currentID, default: []].append(modifier)
                    //print("\(indent)  🔧 Found Modifier: \(type(of: modifier))")
                    
                    // Continue traversal into the wrapped content.
                    traverse(view: content, currentID: currentID, associations: &associations, accumulating: &modifiers, visited: &visited, depth: depth + 1)
                    return // We've handled this level, so we return.
                }
                
                if viewTypeName.starts(with: "TupleView<") {
                    for child in mirror.children {
                        let childValue = child.value //{
                        for child in Mirror(reflecting: childValue).children {
                            // print("\(indent)  🔍 Traversing \(child.label ?? "(unnamed)")")
                            traverse(view: child.value, currentID: currentID, associations: &associations, accumulating: &modifiers, visited: &visited, depth: depth + 1)
                        }
                    }
                }
                else {
                    let mirrorChildren = Array(mirror.children)
                    
                    for child in mirrorChildren  {
                        foundDirectViews = true
                        
                        traverse(view: child.value, currentID: currentID, associations: &associations, accumulating: &modifiers, visited: &visited, depth: depth + 1)
                    }
                    return
                }
            }
            else {
                // SHOULD WE USE THIS? PROBABLY NOT ???? We need it? How to get it in a more stable way? that doesn't cause BLUE RUNTIME DEATH WARNINGS
                //let mirror = Mirror(reflecting:view.body)
                let mirror2 = Mirror(reflecting:view)
                
                // let mirrorChildren = Array(mirror.children)
                let mirrorChildren2 = Array(mirror2.children)
                
                //                for child in mirrorChildren  {
                //
                //                    foundDirectViews = true
                //
                //                    traverse(view: child.value, currentID: currentID, associations: &associations, accumulating: &modifiers, visited: &visited, depth: depth + 1)
                //
                //                }
                
                for child in mirrorChildren2  {
                    
                    foundDirectViews = true
                    if let childView = child.value as? () -> any View {
                        traverse(view: childView, currentID: currentID, associations: &associations, accumulating: &modifiers, visited: &visited, depth: depth + 1)
                        
                    }
                    else {
                        traverse(view: child.value, currentID: currentID, associations: &associations, accumulating: &modifiers, visited: &visited, depth: depth + 1)
                    }
                    
                }
                
                return
            }
            
        }
        
        // **Case 1: ModifiedContent** - The core of modifier extraction.
        // This is the wrapper for any `.modifier()` call. We peel it off and recurse.
        if viewTypeName.starts(with: "ModifiedContent") {
            guard let content = mirror.descendant("content"),
                  let modifier = mirror.descendant("modifier") as? any ViewModifier else {
                return
            }
            
            // Add the found modifier to the dictionary for the current ID.
            associations[currentID, default: []].append(modifier)
            // print("\(indent)  🔧 Found Modifier: \(type(of: modifier))")
            
            // Continue traversal into the wrapped content.
            traverse(view: content, currentID: currentID, associations: &associations, accumulating: &modifiers, visited: &visited, depth: depth + 1)
            return // We've handled this level, so we return.
        }
    }
    
    
    /// Performs an aggressive, recursive search inside any object to find nested properties
    /// that conform to `View`. This is the last-resort strategy for opaque containers
    /// like `AGSubgraphRef` or `ModifiedElements`.
    private static func deepSearchForViews(
        in value: Any,
        currentID: AnyHashable,
        associations: inout [AnyHashable: [any ViewModifier]],
        accumulating modifiers: inout [any ViewModifier],
        visited: inout Set<ObjectIdentifier>, // Pass the tracker
        searchDepth: Int
    ) {
        let indent = String(repeating: "  ", count: searchDepth)
        
        // Protect against infinite loops in the attribute graph
        guard searchDepth < 64 else {
            print("\(indent)⚠️ Deep search max depth reached.")
            return
        }
        
        let mirror = Mirror(reflecting: value)
        
        // First, we must handle and unwrap Optionals to inspect their content.
        if mirror.displayStyle == .optional {
            if let unwrapped = mirror.children.first?.value {
                deepSearchForViews(in: unwrapped, currentID: currentID, associations: &associations, accumulating: &modifiers, visited: &visited, searchDepth: searchDepth + 1)
            }
            return
        }
        
        // We only search inside structs, classes, and tuples.
        guard mirror.displayStyle == .struct || mirror.displayStyle == .class || mirror.displayStyle == .tuple else {
            return
        }
        
        // Iterate through all properties of the current object.
        for child in mirror.children {
            // SUCCESS CASE: We found a view! Hand it back to the main `traverse` function.
            if let childView = child.value as? any View {
                // print("\(indent)  ✅ Deep search found a View: \(type(of: childView))")
                DeepReflector.traverse(view: childView, currentID: currentID, associations: &associations, accumulating: &modifiers, visited: &visited, depth: searchDepth + 1)
            }
            // RECURSIVE STEP: This child is not a view, so we search inside it.
            else {
                deepSearchForViews(in: child.value, currentID: currentID, associations: &associations, accumulating: &modifiers, visited: &visited, searchDepth: searchDepth + 1)
            }
        }
    }
    
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
}

/// A protocol to create a non-generic way to access the `rootView` of a UIHostingController.
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

/// This function takes any UIView and finds its underlying SwiftUI View by searching the responder chain.
/// - Parameter uiView: The UIView that is part of a UIHostingController's hierarchy.
/// - Returns: The type-erased SwiftUI `any View` if found, otherwise nil.
@available(iOS 13.0, tvOS 13.0, *)
func getSwiftUIView(from uiView: UIView) -> (any View)? {
    var responder: UIResponder? = uiView
    // Traverse the responder chain to find the view controller
    while responder != nil {
        // Check if the responder is a UIHostingController (via our protocol)
        if let host = responder as? SwiftUIViewHost {
            // If it is, we can safely access its `anyRootView` property
            return host.anyRootView
        }
        responder = responder?.next
    }
    // No hosting controller was found in the responder chain
    return nil
}
