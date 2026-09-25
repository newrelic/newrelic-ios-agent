//
//  SwiftUIScreenResolver.swift
//  Agent
//
//  Answers two questions about a SwiftUI hosting controller: is it a *screen*, and what is
//  that screen called. Those are the only things standing between the existing UIKit
//  producer and automatic SwiftUI MobileView collection -- `NRMAMobileViewTracker` already
//  swizzles `viewDidLoad`/`viewDidAppear:`/`viewDidDisappear:` on every UIViewController,
//  and hosting controllers *are* UIViewControllers, so their lifecycle is already observed.
//  They were simply dropped by class-name prefix (see `NRMAExcludedViewClassPrefixes`).
//
//  Why a resolver is needed at all. A runtime probe of NRTestApp on iOS 27 found that every
//  dynamically-presented SwiftUI host erases its content type in the class name:
//
//    NavigationView push          UIHostingController<RootView>
//    NavigationStack destination  NavigationStackHostingController<AnyView>
//    sheet / cover                PresentationHostingController<AnyView>
//    TabView tab                  TabHostingController          (no generic parameter at all)
//    app root                     UIHostingController<AppRootView>   <- the only real name
//
//  So the class name cannot supply `viewName`. The concrete type is still reachable at
//  runtime inside the erasure box, which is what `resolveContentType` walks.
//
//  Two deliberate semantics, both chosen over the alternatives:
//
//  1. A host is a screen only if it is *navigation-participating* AND its content type
//     resolves. Hosting controllers exist at sub-screen granularity -- a navigation title's
//     Text gets its own UIHostingController -- so promoting every host would over-count.
//  2. When the type cannot be resolved, emit nothing. No synthetic names, no placeholder
//     `viewName`, because a placeholder would pollute every aggregate keyed on view name.
//     The cost is a silent blind spot if SwiftUI changes its storage layout, which is why
//     `SwiftUIScreenResolverTests` asserts the unwrap directly.
//
//  Copyright © 2026 New Relic. All rights reserved.
//

import Foundation
#if canImport(UIKit) && canImport(SwiftUI) && !os(watchOS)
import UIKit
import SwiftUI

/// The identity of one SwiftUI screen: the two names the MobileView schema wants.
internal struct SwiftUIScreenIdentity {
    /// Simple type name, e.g. "CheckoutScreen". Becomes `viewName`.
    let viewName: String
    /// Module-qualified type name, e.g. "MyApp.CheckoutScreen". Becomes `viewClass`, matching
    /// what the UIKit producer reports via `NRMA_DemangledName(cls, YES)`.
    let viewClass: String
}

internal enum SwiftUIScreenResolver {

    // MARK: - Tuning
    //
    // The walk runs on the main thread inside viewDidAppear:, so it is bounded twice over:
    // by depth, and by total nodes visited. A SwiftUI view tree is a deeply nested generic
    // structure and an unbounded mirror walk over a whole screen would be a visible hitch.
    // Real content sits within a few nodes of the root -- the erasure box plus the modifiers
    // the app applied -- so these bounds are generous rather than tight.

    private static let maxDepth = 12
    private static let maxNodes = 256

    /// Bounds for locating the root view inside the hosting controller. Deliberately tiny: on
    /// iOS 27 the root view sits two hops away (controller → `host` → the `AnyView`), and every
    /// hop beyond that is SwiftUI bookkeeping.
    private static let rootSearchMaxDepth = 4
    private static let rootSearchMaxNodes = 128

    /// Bounds for the route/tag fallback, which cannot prune to the view chain (a route is not a
    /// view) and so must be bounded by brute force instead.
    private static let routeSearchMaxDepth = 10
    private static let routeSearchMaxNodes = 512

    // MARK: - Is this a SwiftUI host?

    /// True for any SwiftUI hosting controller: `UIHostingController`,
    /// `NavigationStackHostingController`, `PresentationHostingController`, `TabHostingController`.
    ///
    /// Matched on the demangled name so one check covers all four, rather than enumerating the
    /// concrete classes -- the probe found the set differs by OS version.
    internal static func isSwiftUIHost(_ controller: UIViewController) -> Bool {
        String(describing: type(of: controller)).contains("HostingController")
    }

    // MARK: - Is it navigated to?

    /// True when something navigated to this host: it is a child of a navigation or tab
    /// container, or it was presented modally.
    ///
    /// This is the filter that keeps decorative hosts out. A `UIHostingController` created for
    /// a navigation title has neither a container parent nor a presenter, so it fails here.
    internal static func isNavigationParticipating(_ controller: UIViewController) -> Bool {
        isNavigationParticipating(parent: controller.parent,
                                  presenter: controller.presentingViewController)
    }

    /// The rule itself, as a total function of the two relationships it depends on.
    ///
    /// Split out from the `UIViewController` overload because `presentingViewController` is
    /// readonly and a real presentation cannot be driven to completion in a unit-test bundle with
    /// no active scene -- so the modal branch was reachable only from a running app. Taking the
    /// inputs directly makes every branch testable offline; the overload above is the only part
    /// that still needs a live controller, and it does nothing but read two properties.
    internal static func isNavigationParticipating(parent: UIViewController?,
                                                  presenter: UIViewController?) -> Bool {
        // Sheets, full-screen covers and popovers arrive as presented controllers rather than
        // as children, so the parent chain alone would miss every modal.
        if presenter != nil { return true }

        guard let parent = parent else { return false }
        return isNavigationContainer(parent)
    }

    private static func isNavigationContainer(_ controller: UIViewController) -> Bool {
        if controller is UINavigationController || controller is UITabBarController { return true }

        // SwiftUI's own containers are private classes that do not inherit from the UIKit ones:
        // UIKitNavigationController backs NavigationView/NavigationStack, UIKitTabBarController
        // and TabHostingController back TabView.
        let name = String(describing: type(of: controller))
        return name.contains("NavigationController")
            || name.contains("TabBarController")
            || name.contains("TabHostingController")
    }

    // MARK: - What is it called?

    /// The screen identity for a host, or `nil` when this host must not be reported.
    ///
    /// Returns `nil` in three cases, all meaning "emit nothing":
    ///   - the content is only SwiftUI primitives or agent-injected wrappers (not a screen),
    ///   - the concrete type could not be recovered from the erasure box,
    ///   - the content already carries `.NRMobileView(...)`, which owns this screen instead.
    ///
    /// Navigation participation is deliberately *not* checked here: the caller composes the two
    /// so each stays independently testable.
    ///
    /// `ignoringModifier` is for the modifier itself: one with no usable name of its own takes its
    /// host's, and that host may well carry it visibly (`Screen().padding().NRMobileView()`).
    internal static func screenIdentity(for controller: UIViewController,
                                        ignoringModifier: Bool = false) -> SwiftUIScreenIdentity? {
        guard let root = rootViewValue(of: controller) else { return nil }

        let outcome = resolveContentType(from: root, stopAtModifier: !ignoringModifier)
        // Coexistence rule: where the modifier is present it wins outright. It carries an
        // explicit name and custom attributes this resolver cannot know, so reporting the host
        // as well would double-count the screen.
        if outcome.isExplicitlyInstrumented { return nil }

        // Preferred: the app's own view type, stored in the content chain.
        if let qualified = outcome.qualifiedTypeName {
            return identity(forQualifiedName: qualified)
        }

        // Next: the type a lazy wrapper will build, read from its generic parameters. This is the
        // only identity available for a `navigationDestination(for:)` destination or a `.popover`
        // body, neither of which stores its view.
        if let destination = outcome.lazyDestinationTypeName {
            return identity(forQualifiedName: destination)
        }

        // Fallback: the route or tab tag that identifies this screen.
        //
        // Needed because in real SwiftUI apps the screen's view struct frequently is not stored
        // anywhere in the host's graph, so the preferred path above finds nothing:
        //
        //   * a `navigationDestination(for:)` host holds a `ParameterizedLazyView` plus the route
        //     value -- the destination view has not been built yet and does not exist,
        //   * a tab host holds only the tab's tag enum,
        //   * a screen whose body *is* a NavigationStack puts the stack's inner content in the
        //     host, leaving the enclosing type absent entirely.
        //
        // The type name of the lazy destination is deliberately not parsed instead: it is commonly
        // `_ConditionalContent<ScreenA, ScreenB>`, which cannot say which branch is on screen,
        // whereas the route case can.
        return routeIdentity(from: root)
    }

    // MARK: - Route / tag identity

    /// Names a screen after the shallowest app-module enum reachable from its content -- a
    /// navigation route or a tab tag.
    ///
    /// Only the *case* is used, never associated values: naming a screen
    /// `TestRoute.listing(id: "L-1006")` would mint a fresh `viewName` per listing and make every
    /// aggregate over view name meaningless. `TestRoute.listing` is one name for one screen.
    private static func routeIdentity(from root: Any) -> SwiftUIScreenIdentity? {
        var queue: [(value: Any, depth: Int)] = [(root, 0)]
        var visited = 0

        // Two candidates rather than "first match wins". This scan cannot prune to the view chain,
        // so it walks SwiftUI's own bookkeeping and reaches foreign enums in quantity; taking the
        // first acceptable one made the winner an accident of traversal order. The app's own module
        // is the better identity, so a linked package's enum is held only as a fallback.
        var fromOtherModule: String?

        while !queue.isEmpty {
            let (value, depth) = queue.removeFirst()
            visited += 1
            if visited > routeSearchMaxNodes { break }

            let mirror = Mirror(reflecting: value)
            let qualified = String(reflecting: type(of: value))

            if mirror.displayStyle == .enum,
               isAppModuleType(qualified),
               let caseName = enumCaseName(of: value, mirror: mirror) {
                // Synthesised so it reads like any other qualified type name, which lets
                // `simpleName` strip the module exactly as it does for a view type.
                let qualifiedCase = qualified + "." + caseName

                if isMainBundleModuleType(qualified) {
                    // Nothing can outrank the app's own module, so stop here.
                    return identity(forQualifiedName: qualifiedCase)
                }
                if fromOtherModule == nil { fromOtherModule = qualifiedCase }
            }

            guard depth < routeSearchMaxDepth else { continue }
            for child in mirror.children {
                queue.append((child.value, depth + 1))
            }
        }

        guard let fallback = fromOtherModule else { return nil }
        return identity(forQualifiedName: fallback)
    }

    /// The case name of an enum value, with any associated values discarded.
    ///
    /// Two shapes to handle: a case *with* associated values reflects as a single child labelled
    /// with the case name, while a case without them has no children at all and is only readable
    /// from its description. The description is truncated at the first "(" so an associated value
    /// can never survive even if the labelled path is unavailable.
    private static func enumCaseName(of value: Any, mirror: Mirror) -> String? {
        if let label = mirror.children.first?.label, !label.isEmpty {
            return label
        }
        let described = String(describing: value)
        let name = described.prefix { $0 != "(" }
        return name.isEmpty ? nil : String(name)
    }

    // MARK: - Reflection

    /// The root view value held by a hosting controller.
    ///
    /// Found by shallow breadth-first search for the first value that is actually a `View`, rather
    /// than by reading a named property: on iOS 27 `UIHostingController` has no `rootView` stored
    /// property at all, and the name of the one it does have (`host`) is an implementation detail
    /// that has changed before.
    ///
    /// Two things this has to get right, both learned from a real app reporting nothing at all:
    ///
    ///  1. **Inherited storage.** Every erasing idiom produces a *subclass* --
    ///     `NavigationStackHostingController`, `TabHostingController`,
    ///     `PresentationHostingController` -- and `Mirror.children` exposes only the immediate
    ///     class's stored properties. The root view lives on `UIHostingController`, so without
    ///     walking `superclassMirror` it is invisible and every SwiftUI screen resolves to nothing.
    ///     Plain `UIHostingController` worked, which is why unit tests over it passed while a whole
    ///     app stayed silent.
    ///  2. **Nil optionals that claim to be views.** SwiftUI declares
    ///     `extension Optional: View where Wrapped: View`, so `Optional<AnyView>.none` satisfies
    ///     `value is any View`. `NavigationStackHostingController` declares exactly such a property
    ///     (`pendingContent`, normally nil) and breadth-first search reaches it *before* the
    ///     inherited root view -- so it was selected, and resolution stopped at an empty box.
    private static func rootViewValue(of controller: UIViewController) -> Any? {
        var queue: [(value: Any, depth: Int)] = [(controller, 0)]
        var visited = 0

        while !queue.isEmpty {
            let (value, depth) = queue.removeFirst()
            visited += 1
            if visited > rootSearchMaxNodes { return nil }

            let mirror = Mirror(reflecting: value)

            // An empty optional is a nil optional. Rejected here rather than unwrapped because a
            // nil `Optional<some View>` is indistinguishable from a real view by conformance alone.
            if depth > 0, value is any View, !isNilOptional(mirror) { return value }
            guard depth < rootSearchMaxDepth else { continue }

            for child in mirror.children {
                queue.append((child.value, depth + 1))
            }
            // Inherited stored properties, which `children` omits. This is where the root view of
            // every SwiftUI-private hosting subclass actually lives.
            var superclass = mirror.superclassMirror
            while let superMirror = superclass {
                for child in superMirror.children {
                    queue.append((child.value, depth + 1))
                }
                superclass = superMirror.superclassMirror
            }
        }
        return nil
    }

    private static func isNilOptional(_ mirror: Mirror) -> Bool {
        mirror.displayStyle == .optional && mirror.children.isEmpty
    }

    private struct ContentTypeOutcome {
        var qualifiedTypeName: String?
        /// The type a lazy wrapper would build. Held separately from `qualifiedTypeName` so a real
        /// stored app view always outranks a type read out of a generic parameter.
        var lazyDestinationTypeName: String?
        var isExplicitlyInstrumented = false
    }

    /// Walks the view tree looking for the app's own view type, past erasure boxes
    /// (`AnyView` → `AnyViewStorage<T>` → `T`) and modifier wrappers
    /// (`ModifiedContent<Content, Modifier>` → `Content`).
    ///
    /// Descends only into values that are themselves `View`s (plus the one non-`View` hop an
    /// erasure box requires). That pruning is not an optimisation -- it is what makes the result
    /// correct. A blind mirror walk from the hosting controller reaches sibling
    /// `_UIHostingView`s, a back-reference to the `UIHostingController`, and presentation
    /// bookkeeping, any of which can lead to *another* screen's view type; it also buries the
    /// real content behind ~200 nodes, so a modified view was missed entirely under the node
    /// budget. Following only the view chain keeps the walk to a handful of nodes on the one path
    /// that actually holds this screen's content.
    ///
    /// The walk always completes rather than returning at the first candidate, because the
    /// `.NRMobileView(...)` marker sits in the *modifier* position of a `ModifiedContent` whose
    /// *content* is the app view -- returning early would find the app view first and miss the
    /// suppression signal entirely.
    private static func resolveContentType(from root: Any, stopAtModifier: Bool) -> ContentTypeOutcome {
        var outcome = ContentTypeOutcome()
        var queue: [(value: Any, depth: Int)] = [(root, 0)]
        var visited = 0

        while !queue.isEmpty {
            let (value, depth) = queue.removeFirst()
            if depth > maxDepth { continue }
            visited += 1
            if visited > maxNodes { break }

            let qualified = String(reflecting: type(of: value))

            // Checked on every node's *type name*, which is what makes suppression work even
            // though a ViewModifier is not a View and is therefore never descended into: the
            // marker still appears in the enclosing ModifiedContent's generic parameters.
            if stopAtModifier, isExplicitInstrumentationMarker(qualified) {
                outcome.isExplicitlyInstrumented = true
                // Nothing else about this host matters once the modifier owns it.
                return outcome
            }

            // A lazy wrapper is checked before the app-view test and instead of it. It is never
            // itself the screen -- naming it would report "LazyView<MyApp.Detail>" -- and the type
            // it builds is only in its generic parameters, so this is the one place that type can
            // be recovered at all.
            if let destination = lazyDestinationTypeName(from: qualified) {
                if outcome.lazyDestinationTypeName == nil {
                    outcome.lazyDestinationTypeName = destination
                }
            } else if outcome.qualifiedTypeName == nil, isAppViewType(qualified, value: value) {
                // Breadth-first, so the shallowest app type wins. A screen that embeds another
                // screen as a child should report as itself, not as its child.
                outcome.qualifiedTypeName = qualified
            }

            for child in Mirror(reflecting: value).children {
                let childName = String(reflecting: type(of: child.value))
                guard child.value is any View || isErasureStorage(childName) else { continue }
                queue.append((child.value, depth + 1))
            }
        }

        return outcome
    }

    /// The one non-`View` link in the chain: `AnyView` holds its content in an `AnyViewStorage`
    /// box, which is a class rather than a view, so pruning to `View`s alone would stop dead at
    /// every erased screen -- which is to say at every NavigationStack destination and sheet.
    private static func isErasureStorage(_ qualifiedName: String) -> Bool {
        qualifiedName.contains("AnyViewStorage")
    }

    // MARK: - Type classification

    /// The module this file is compiled into, so agent-injected types can be excluded without
    /// hardcoding a product name that a repackaged build would change.
    private static let agentModule: String = {
        let own = String(reflecting: SwiftUIScreenIdentity.self)
        return own.components(separatedBy: ".").first ?? "NewRelic"
    }()

    /// Modules that ship with the platform, and so can never contain one of the app's screens.
    ///
    /// This list is what stands between the route/tag fallback and nonsense names. The gate used to
    /// deny only SwiftUI, Swift and the agent, which let `__C` -- the namespace for declarations
    /// imported from C and Objective-C -- straight through. A TabView tab's content lives in
    /// SwiftUI's attribute graph where reflection cannot reach it, so the route scan kept walking
    /// past it and named every tab in the app after the first foreign enum it happened to reach:
    /// `__C.CoreSystem.CoreSystem`. Every tab shared one wrong name.
    ///
    /// A denylist rather than an allowlist because the app's own screens legitimately live in any
    /// module name at all, including Swift packages and frameworks.
    private static let systemModules: Set<String> = [
        "__C", "Swift", "SwiftUI", "SwiftUICore", "AttributeGraph",
        "Foundation", "CoreFoundation", "ObjectiveC", "Darwin", "Dispatch", "os",
        "_Concurrency", "_StringProcessing", "Observation", "Combine",
        "UIKit", "QuartzCore", "CoreGraphics", "CoreText", "CoreImage",
        "CoreData", "CoreLocation", "CoreMedia", "AVFoundation", "MapKit", "WebKit",
        "Photos", "PhotosUI", "StoreKit", "SwiftData", "Charts", "Network", "Security",
        "CloudKit", "UserNotifications", "Metal", "MetalKit", "SpriteKit", "SceneKit",
    ]

    /// True when a qualified type name belongs to the app rather than to the platform or the agent.
    internal static func isAppModuleType(_ qualifiedName: String) -> Bool {
        guard let module = moduleName(of: qualifiedName) else { return false }
        return !systemModules.contains(module) && module != agentModule
    }

    /// True when a type belongs to the app's *own* module, as opposed to a package or framework it
    /// links. Used to break ties in the route scan: both are acceptable, the app's own is better.
    internal static func isMainBundleModuleType(_ qualifiedName: String) -> Bool {
        guard let module = moduleName(of: qualifiedName),
              let mainModule = mainBundleModule else { return false }
        return module == mainModule
    }

    private static func moduleName(of qualifiedName: String) -> String? {
        guard qualifiedName.contains(".") else { return nil }
        guard let module = qualifiedName.components(separatedBy: ".").first,
              !module.isEmpty else { return nil }
        return module
    }

    /// Agent types that wrap customer content for Session Replay. Rejected by name as well as by
    /// module so a build that compiles the agent's sources into the app module is still covered.
    private static func isAgentWrapperType(_ qualifiedName: String) -> Bool {
        qualifiedName.contains("MaskedContainerView")
            || qualifiedName.contains("NRConditionalMaskView")
            || qualifiedName.contains("NRMaskedViewRepresentable")
    }

    /// The module the app itself was compiled into, derived from the main bundle's executable
    /// name the way Swift derives a module name from a product name.
    ///
    /// Settable so tests do not depend on whichever bundle is `main` in a test runner. Used only
    /// as a *preference* between candidate routes, never as a requirement -- a modularised app
    /// keeps its screens in packages and frameworks, and those must still resolve.
    internal static var mainBundleModule: String? = defaultMainBundleModule()

    private static func defaultMainBundleModule() -> String? {
        guard let executable = Bundle.main.executableURL?.deletingPathExtension().lastPathComponent,
              !executable.isEmpty else { return nil }
        return String(executable.map { ($0.isLetter || $0.isNumber) ? $0 : "_" })
    }

    /// SwiftUI wrappers that build their content lazily. Matched by simple name because they are
    /// private types whose module path has changed between releases.
    private static let lazyDestinationWrappers: Set<String> = ["LazyView", "ParameterizedLazyView"]

    /// The app view type a lazy wrapper *would* build, read out of its generic parameters.
    ///
    /// Needed because a lazy wrapper stores a closure, not a view: `LazyView` holds `() -> Content`
    /// and `ParameterizedLazyView` holds `(Route) -> Content`. Reflection cannot see through a
    /// closure, so a `navigationDestination(for:)` destination and a `.popover` body are present in
    /// the graph only as a *type argument*. A walk of NRTestApp found three screens visibly on
    /// screen and completely unreported for this reason.
    ///
    /// Matched on the *leading* type name rather than by substring: a
    /// `ModifiedContent<ParameterizedLazyView<Route, Screen>, SomeModifier>` also contains the
    /// wrapper's name, and its own last type argument is the modifier -- so a substring match would
    /// name every such screen after a SwiftUI modifier.
    internal static func lazyDestinationTypeName(from qualifiedName: String) -> String? {
        guard let open = qualifiedName.firstIndex(of: "<"), qualifiedName.hasSuffix(">") else {
            return nil
        }

        let head = String(qualifiedName[qualifiedName.startIndex..<open])
        let wrapper = head.components(separatedBy: ".").last ?? head
        guard lazyDestinationWrappers.contains(wrapper) else { return nil }

        let inner = String(qualifiedName[qualifiedName.index(after: open)..<qualifiedName.index(before: qualifiedName.endIndex)])
        guard let last = topLevelTypeArguments(of: inner).last else { return nil }

        let candidate = last.trimmingCharacters(in: .whitespaces)

        // `_ConditionalContent<A, B>` is what a destination closure containing an `if` compiles to.
        // It names both branches and cannot say which is on screen, so naming it would attribute
        // every visit to whichever branch was written first.
        guard !candidate.contains("_ConditionalContent") else { return nil }
        guard isAppModuleType(candidate), !isAgentWrapperType(candidate) else { return nil }

        return candidate
    }

    /// Splits a generic argument list at top-level commas only. A route that is itself generic --
    /// `ParameterizedLazyView<Dictionary<String, Int>, Screen>` -- carries commas of its own, and
    /// splitting on all of them would truncate the destination.
    private static func topLevelTypeArguments(of arguments: String) -> [String] {
        var result: [String] = []
        var depth = 0
        var current = ""

        for character in arguments {
            switch character {
            case "<": depth += 1; current.append(character)
            case ">": depth -= 1; current.append(character)
            case "," where depth == 0:
                result.append(current)
                current = ""
            default: current.append(character)
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    private static func isExplicitInstrumentationMarker(_ qualifiedName: String) -> Bool {
        qualifiedName.contains("NRMobileViewModifier")
    }

    /// True when a type is plausibly one of the app's own screens.
    ///
    /// Two independent gates, because either alone admits noise: the module gate rejects
    /// SwiftUI's and the agent's types, and the `View` conformance gate rejects the state,
    /// storage and layout values that a mirror walk turns up in equal numbers.
    private static func isAppViewType(_ qualifiedName: String, value: Any) -> Bool {
        guard value is any View else { return false }

        guard isAppModuleType(qualifiedName) else { return false }

        // Agent types wrap customer content for Session Replay (MaskedContainerView,
        // NRConditionalMaskView) and the probe found them inside real host class names. The
        // module check above catches them in a normal build; the name check also catches a
        // build where the agent's sources are compiled into the app module directly.
        if isAgentWrapperType(qualifiedName) { return false }

        return true
    }

    // MARK: - Hosts owned by .NRMobileView

    /// Marks a host whose content carries `.NRMobileView(...)`, so automatic collection leaves it to
    /// the modifier.
    ///
    /// The marker check in `resolveContentType` cannot do this alone: it sees the modifier only where
    /// it is *stored* in the host's view graph, which is at a call site. Applied inside `body` -- the
    /// usual place -- it is never stored, because `body` is computed, and the screen was reported by
    /// both producers. The modifier finds its host at runtime and claims it instead.
    ///
    /// Called roughly half a second before the host's `viewDidAppear:` in practice (the modifier's
    /// view reaches the window when the push starts, the host appears when it ends), which is the
    /// only point the tracker consults this. A claim after that would come too late to matter.
    internal static func claimForModifier(_ controller: UIViewController) {
        guard isSwiftUIHost(controller) else { return }
        objc_setAssociatedObject(controller, &modifierClaimKey, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    internal static func isClaimedByModifier(_ controller: UIViewController) -> Bool {
        (objc_getAssociatedObject(controller, &modifierClaimKey) as? Bool) ?? false
    }

    private static var modifierClaimKey: UInt8 = 0

    /// The name `.NRMobileView()` can take from its own type, or `nil` when that type does not name
    /// a screen.
    ///
    /// At a call site (`CheckoutScreen().NRMobileView()`) the modifier's `self` is the screen, and its
    /// type is the right name. Inside `body` it is the modifier chain the body built, and the type
    /// names nothing -- it was observed as a ~1.5 KB `ModifiedContent<ModifiedContent<…ScrollView<…`
    /// string reported as a viewName. Only an app type is accepted, by the same rule automatic
    /// collection names screens by; anything else defers to the host's name.
    internal static func modifierDefaultName(for type: Any.Type) -> String? {
        let qualified = String(reflecting: type)
        guard isAppModuleType(qualified), !isAgentWrapperType(qualified) else { return nil }
        return simpleName(from: qualified)
    }

    // MARK: - Objective-C facade

    /// Composed decision for a producer: a host is a screen only when it is navigation
    /// participating *and* its content type resolves. Kept here rather than in the tracker so the
    /// rule lives with the two halves it combines.
    fileprivate static func automaticScreen(for controller: UIViewController) -> SwiftUIScreenIdentity? {
        guard isSwiftUIHost(controller),
              isNavigationParticipating(controller),
              !isClaimedByModifier(controller) else { return nil }
        return screenIdentity(for: controller)
    }

    /// Strips the outermost module prefix, ignoring dots inside generic parameters.
    ///
    /// The Swift counterpart of `NRMA_StripOuterModule` in NRMAMobileViewTracker.m; the two
    /// must agree or the same screen would be named differently depending on which producer
    /// saw it. Like that function it strips only the *outermost* component, so a nested type
    /// keeps its enclosing type in the name ("MyApp.Settings.Row" → "Settings.Row").
    private static func simpleName(from qualifiedName: String) -> String {
        var depth = 0
        for (offset, character) in qualifiedName.enumerated() {
            switch character {
            case "<": depth += 1
            case ">": if depth > 0 { depth -= 1 }
            case "." where depth == 0:
                return stripCompilerContexts(from: String(qualifiedName.dropFirst(offset + 1)))
            default: break
            }
        }
        return stripCompilerContexts(from: qualifiedName)
    }

    /// Drops "(unknown context at $7f…)" segments the reflection API emits for types declared at
    /// private or function scope.
    ///
    /// A `private struct SettingsRow: View` inside an app reflects as
    /// "MyApp.(unknown context at $10945b7b4).SettingsRow". The address differs per build, so left
    /// in place one screen fans out into a new identity every release.
    ///
    /// Applied to `viewClass` as well as `viewName`, which it previously was not: a private sheet
    /// body was observed reporting a stable viewName of "SheetDetailView" alongside a viewClass of
    /// "NRTestApp.(unknown context at $103c6ce48).SheetDetailView", making viewClass useless for
    /// grouping. IDD §6.1 wants viewClass to be the stable qualified type name.
    ///
    /// Removes every such segment wherever it appears rather than only a leading one, because the
    /// module prefix is still attached when this runs over a qualified name.
    private static func stripCompilerContexts(from name: String) -> String {
        guard name.contains("(unknown context") else { return name }

        var result = name
        while let start = result.range(of: "(unknown context at "),
              let close = result.range(of: ").", range: start.upperBound..<result.endIndex) {
            result.replaceSubrange(start.lowerBound..<close.upperBound, with: "")
        }
        return result
    }

    /// The two names for one resolved type, so every path that mints an identity applies the same
    /// normalisation. Previously each call site built the struct itself and only `viewName` was
    /// normalised.
    private static func identity(forQualifiedName qualifiedName: String) -> SwiftUIScreenIdentity {
        SwiftUIScreenIdentity(viewName: simpleName(from: qualifiedName),
                              viewClass: stripCompilerContexts(from: qualifiedName))
    }
}

/// One resolved SwiftUI screen, as seen from Objective-C.
@objcMembers
public class NRMASwiftUIScreen: NSObject {
    public let viewName: String
    public let viewClass: String

    fileprivate init(_ identity: SwiftUIScreenIdentity) {
        self.viewName = identity.viewName
        self.viewClass = identity.viewClass
        super.init()
    }
}

/// The Objective-C entry point used by `NRMAMobileViewTracker`.
///
/// A thin facade on purpose: the decision logic stays in `SwiftUIScreenResolver`, which is
/// `internal` and unit-tested directly, so the bridge carries no rules of its own.
@objcMembers
public class NRMASwiftUIScreenResolver: NSObject {

    /// Cheap pre-check so the tracker can skip the reflection path for plain UIKit controllers
    /// without paying an Objective-C → Swift call per screen.
    public static func isSwiftUIHost(_ controller: UIViewController) -> Bool {
        SwiftUIScreenResolver.isSwiftUIHost(controller)
    }

    /// The screen this host represents, or `nil` when it must not be reported -- a decorative
    /// sub-host, an unresolvable content type, or a view that already carries `.NRMobileView(...)`.
    public static func screen(for controller: UIViewController) -> NRMASwiftUIScreen? {
        SwiftUIScreenResolver.automaticScreen(for: controller).map(NRMASwiftUIScreen.init)
    }
}

#endif
