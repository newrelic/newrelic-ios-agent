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
    private static let rootSearchMaxDepth = 3
    private static let rootSearchMaxNodes = 64

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
    internal static func screenIdentity(for controller: UIViewController) -> SwiftUIScreenIdentity? {
        guard let root = rootViewValue(of: controller) else { return nil }

        let outcome = resolveContentType(from: root)
        // Coexistence rule: where the modifier is present it wins outright. It carries an
        // explicit name and custom attributes this resolver cannot know, so reporting the host
        // as well would double-count the screen.
        if outcome.isExplicitlyInstrumented { return nil }
        guard let qualified = outcome.qualifiedTypeName else { return nil }

        return SwiftUIScreenIdentity(viewName: simpleName(from: qualified),
                                     viewClass: qualified)
    }

    // MARK: - Reflection

    /// The root view value held by a hosting controller.
    ///
    /// Found by shallow breadth-first search for the first value that is actually a `View`, rather
    /// than by reading a named property: on iOS 27 `UIHostingController` has no `rootView` stored
    /// property at all. Its root view hangs off a `host: _UIHostingView<Content>`, and that name
    /// is an implementation detail that has changed before. What does not change is that the root
    /// view conforms to `View` while the ~25 sibling properties (bridges, trackers, sizing
    /// options) do not, so conformance is the more durable signal.
    private static func rootViewValue(of controller: UIViewController) -> Any? {
        var queue: [(value: Any, depth: Int)] = [(controller, 0)]
        var visited = 0

        while !queue.isEmpty {
            let (value, depth) = queue.removeFirst()
            visited += 1
            if visited > rootSearchMaxNodes { return nil }

            if depth > 0, value is any View { return value }
            guard depth < rootSearchMaxDepth else { continue }

            for child in Mirror(reflecting: value).children {
                queue.append((child.value, depth + 1))
            }
        }
        return nil
    }

    private struct ContentTypeOutcome {
        var qualifiedTypeName: String?
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
    private static func resolveContentType(from root: Any) -> ContentTypeOutcome {
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
            if isExplicitInstrumentationMarker(qualified) {
                outcome.isExplicitlyInstrumented = true
                // Nothing else about this host matters once the modifier owns it.
                return outcome
            }

            // Breadth-first, so the shallowest app type wins. A screen that embeds another
            // screen as a child should report as itself, not as its child.
            if outcome.qualifiedTypeName == nil, isAppViewType(qualified, value: value) {
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

        guard let module = qualifiedName.components(separatedBy: ".").first,
              !module.isEmpty,
              // Unqualified names are runtime-internal types, never an app's view.
              qualifiedName.contains(".") else { return false }

        if module == "SwiftUI" || module == "Swift" || module == agentModule { return false }

        // Agent types wrap customer content for Session Replay (MaskedContainerView,
        // NRConditionalMaskView) and the probe found them inside real host class names. The
        // module check above catches them in a normal build; the name check also catches a
        // build where the agent's sources are compiled into the app module directly.
        if qualifiedName.contains("MaskedContainerView")
            || qualifiedName.contains("NRConditionalMaskView")
            || qualifiedName.contains("NRMaskedViewRepresentable") { return false }

        return true
    }

    // MARK: - Objective-C facade

    /// Composed decision for a producer: a host is a screen only when it is navigation
    /// participating *and* its content type resolves. Kept here rather than in the tracker so the
    /// rule lives with the two halves it combines.
    fileprivate static func automaticScreen(for controller: UIViewController) -> SwiftUIScreenIdentity? {
        guard isSwiftUIHost(controller),
              isNavigationParticipating(controller) else { return nil }
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
    /// "MyApp.(unknown context at $10945b7b4).SettingsRow". Left in place that address would
    /// become part of `viewName` -- and it differs per build, so one screen would fan out into a
    /// new view name every release.
    private static func stripCompilerContexts(from name: String) -> String {
        guard name.contains("(unknown context") else { return name }

        var result = name
        while result.hasPrefix("(") {
            guard let close = result.range(of: ")."), close.lowerBound >= result.startIndex else { break }
            result = String(result[close.upperBound...])
        }
        return result
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
