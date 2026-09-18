//
//  SwiftUIScreenResolverTests.swift
//  NewRelicAgent
//
//  Covers SwiftUIScreenResolver, which decides whether a UIHostingController is a *screen*
//  and what that screen is called -- the two questions that make automatic SwiftUI
//  MobileView collection possible without `.NRMobileView(...)`.
//
//  Why these tests exist in this shape: a runtime probe of NRTestApp showed that every
//  dynamically-presented SwiftUI host erases its content type. A NavigationView push is
//  `UIHostingController<RootView>`, a NavigationStack destination is
//  `NavigationStackHostingController<AnyView>`, a sheet is
//  `PresentationHostingController<AnyView>`, and a TabView tab is a bare
//  `TabHostingController` with no generic parameter at all. Only the statically-typed app
//  root keeps a real name. So the class name is *not* a usable source of viewName, and the
//  concrete type has to be recovered by reflecting through the erasure box.
//
//  Copyright © 2026 New Relic. All rights reserved.
//

import XCTest
import SwiftUI
@testable import NewRelic

// MARK: - Fixtures
//
// Stand-ins for customer screens, declared at file scope with default (internal) access so they
// reflect the way an app's own views do: "Agent_Tests.CheckoutScreen".
//
// They are deliberately NOT `private`. A private type at file scope reflects as
// "Agent_Tests.(unknown context at $10945b7b4).CheckoutScreen" -- a build-specific address in
// the middle of the name. That form is real and worth covering, but as its own case
// (testStripsCompilerContextFromPrivateTypeNames) rather than as the baseline every other
// assertion is built on.

struct CheckoutScreen: View {
    var body: some View { Text("checkout") }
}

struct ProductScreen: View {
    var body: some View { Text("product") }
}

/// Private on purpose: reproduces the "(unknown context at $…)" reflected name.
private struct PrivateSettingsScreen: View {
    var body: some View { Text("settings") }
}

/// Stands in for SwiftUI's private hosting-controller subclasses -- `NavigationStackHostingController`,
/// `TabHostingController`, `PresentationHostingController` -- which is what every erasing
/// navigation idiom actually produces at runtime.
///
/// Two properties of the real classes are reproduced here, because together they were enough to
/// silence automatic collection in a whole app:
///
///  1. It is a *subclass*, so `UIHostingController`'s own `host` / `_rootView` storage is not among
///     `Mirror.children` -- those require `superclassMirror`.
///  2. It declares its own `pendingContent: AnyView?`, normally nil. SwiftUI declares
///     `extension Optional: View where Wrapped: View`, so a nil `Optional<AnyView>` still satisfies
///     `is any View` -- making it a decoy that a breadth-first search reaches before the real root.
///
/// A HomeSearch run showed `NavigationStackHostingController` yielding exactly these two signals:
/// `pendingContent` (nil) at depth 1, and the real `_rootView` only under the superclass mirror.
/// A navigation route, the way route-based SwiftUI apps model destinations. Carries an associated
/// value so the tests can prove it never reaches `viewName`.
enum TestRoute {
    case listing(id: String)
    case tour
}

/// Not a `View` -- a `ViewModifier` -- so it can carry a route into the content graph without the
/// route's *carrier* being mistaken for the screen. This reproduces how the real graph exposes a
/// route: `ParameterizedLazyView` holds the route value as a plain child.
struct RouteCarryingModifier: ViewModifier {
    let route: TestRoute
    func body(content: Content) -> some View { content }
}

/// Stand-in for the agent's own `NRMobileViewModifier`, which suppression matches by name.
/// Declared here because the real one is commented out in NRViewModifier.swift in this tree.
struct NRMobileViewModifier: ViewModifier {
    func body(content: Content) -> some View { content }
}

/// Stand-in for SwiftUI's `LazyView<Content>`, the wrapper a `.popover` puts its content in.
///
/// Matters because the real one stores a *closure* (`() -> Content`), not the content, so the
/// destination view is never a value in the graph -- it exists only as this wrapper's generic
/// parameter. A runtime probe of NRTestApp caught `.popover` reporting nothing at all for exactly
/// this reason: `SwiftUI.LazyView<NRTestApp.(unknown context at $105e08e98).PopoverDetailView>`.
///
/// Named to match because the resolver matches SwiftUI's private wrappers by name, the same way
/// `NRMobileViewModifier` suppression is matched by name.
struct LazyView<Content: View>: View {
    let build: () -> Content
    var body: some View { build() }
}

/// Stand-in for SwiftUI's `ParameterizedLazyView<Route, Content>`, which is what
/// `navigationDestination(for:)` produces. Same closure-storage problem as `LazyView`, and the
/// reason struct- and String-routed destinations reported nothing: the probe found
/// `SwiftUI.ParameterizedLazyView<NRTestApp.NavItem, NRTestApp.NavItemDetailView>`.
struct ParameterizedLazyView<Route, Content: View>: View {
    let build: (Route) -> Content
    var body: some View { Text("lazy") }
}

/// Non-generic over AnyView because that is what the real classes are: the probe found every
/// erasing idiom producing a host over `AnyView`, never over a concrete type.
@available(iOS 13, tvOS 13, *)
final class StubNavigationStackHostingController: UIHostingController<AnyView> {
    /// Deliberately nil and deliberately declared before anything else, mirroring the real decoy.
    private var pendingContent: AnyView?
}

@available(iOS 13, tvOS 13, *)
final class SwiftUIScreenResolverTests: XCTestCase {

    // MARK: - Name resolution through type erasure

    // The decisive case for the whole feature. A NavigationStack destination and a sheet both
    // reach us as a host over `AnyView`, so if the concrete view type cannot be recovered from
    // inside that box, automatic instrumentation can only ever name the erasure box itself.
    func testResolvesConcreteViewTypeThroughAnyView() {
        let host = UIHostingController(rootView: AnyView(CheckoutScreen()))

        let identity = SwiftUIScreenResolver.screenIdentity(for: host)

        XCTAssertEqual(identity?.viewName, "CheckoutScreen")
    }

    // viewClass is the module-qualified counterpart of viewName, matching what the UIKit
    // producer reports via NRMA_DemangledName(cls, YES). Asserted on the suffix rather than
    // the whole string because the test module name is not this file's business.
    func testResolvedViewClassIsModuleQualified() {
        let host = UIHostingController(rootView: AnyView(CheckoutScreen()))

        let identity = SwiftUIScreenResolver.screenIdentity(for: host)

        XCTAssertTrue(identity?.viewClass.hasSuffix(".CheckoutScreen") == true,
                      "expected a module-qualified name, got \(identity?.viewClass ?? "nil")")
    }

    // A private or function-scope view type reflects with a compiler context in the middle of
    // its name: "Agent_Tests.(unknown context at $10945b7b4).PrivateSettingsScreen". The address
    // changes between builds, so leaving it in viewName would fan one screen out into a fresh
    // view name every release.
    func testStripsCompilerContextFromPrivateTypeNames() {
        let host = UIHostingController(rootView: AnyView(PrivateSettingsScreen()))

        let identity = SwiftUIScreenResolver.screenIdentity(for: host)

        XCTAssertEqual(identity?.viewName, "PrivateSettingsScreen")
    }

    // A statically-typed host keeps its real type in the class name, but it must resolve
    // through the same path so viewName does not depend on which idiom presented the screen.
    func testResolvesConcreteViewTypeWithoutErasure() {
        let host = UIHostingController(rootView: ProductScreen())

        let identity = SwiftUIScreenResolver.screenIdentity(for: host)

        XCTAssertEqual(identity?.viewName, "ProductScreen")
    }

    // Real screens arrive wrapped in modifiers applied by the app (.padding(), .navigationTitle()).
    // Those wrappers are SwiftUI-internal generic types, so the resolver has to look past them
    // rather than reporting "ModifiedContent".
    func testLooksPastSwiftUIModifierWrappers() {
        let host = UIHostingController(rootView: AnyView(CheckoutScreen().padding()))

        let identity = SwiftUIScreenResolver.screenIdentity(for: host)

        XCTAssertEqual(identity?.viewName, "CheckoutScreen")
    }

    // MARK: - SwiftUI's private hosting-controller subclasses
    //
    // The regression that made automatic collection emit nothing at all in a real app. Every
    // erasing idiom -- NavigationStack destination, sheet, TabView tab -- is a *subclass* of
    // UIHostingController, and `Mirror.children` does not include inherited stored properties. So
    // the root view was unreachable, while a nil `Optional<AnyView>` decoy declared on the subclass
    // did satisfy `is any View` and was selected instead.

    func testResolvesScreenOnAHostingControllerSubclass() {
        let host = StubNavigationStackHostingController(rootView: AnyView(CheckoutScreen()))

        let identity = SwiftUIScreenResolver.screenIdentity(for: host)

        XCTAssertEqual(identity?.viewName, "CheckoutScreen",
                       "the root view of a UIHostingController subclass is reachable only through "
                       + "superclassMirror; without it every SwiftUI navigation idiom resolves to nothing")
    }

    // Guards the decoy specifically: a nil Optional<AnyView> must never be mistaken for the root
    // view just because Optional conforms to View when Wrapped does.
    func testNilOptionalViewPropertyIsNotMistakenForTheRootView() {
        let host = StubNavigationStackHostingController(rootView: AnyView(ProductScreen()))

        let identity = SwiftUIScreenResolver.screenIdentity(for: host)

        XCTAssertEqual(identity?.viewName, "ProductScreen")
    }

    // MARK: - Naming from route / tag enums
    //
    // Why this exists: in a real app (HomeSearch) the screen's own view struct is simply not in the
    // host's stored graph. A tab host holds only the tab's tag enum; a `navigationDestination`
    // host holds a `ParameterizedLazyView` plus the route value, because the destination view is
    // built lazily and does not exist yet. Requiring a `View`-conforming app type therefore named
    // nothing at all across an entire app. An app-module enum reachable in the content graph is
    // the identity that IS present.

    func testNamesScreenFromRouteEnumWhenNoAppViewTypeIsStored() {
        let host = UIHostingController(
            rootView: AnyView(Text("lazy destination")
                .modifier(RouteCarryingModifier(route: .listing(id: "L-1006")))))

        let identity = SwiftUIScreenResolver.screenIdentity(for: host)

        XCTAssertEqual(identity?.viewName, "TestRoute.listing")
    }

    // The cardinality guard, and the reason the case name is used rather than the value: naming a
    // screen after `listing(id: "L-1006")` would mint a new viewName per listing and make every
    // aggregate over viewName useless.
    func testRouteAssociatedValuesNeverReachTheViewName() {
        let host = UIHostingController(
            rootView: AnyView(Text("lazy destination")
                .modifier(RouteCarryingModifier(route: .listing(id: "L-1006")))))

        let name = SwiftUIScreenResolver.screenIdentity(for: host)?.viewName ?? ""

        XCTAssertFalse(name.contains("L-1006"), "associated values must not reach viewName, got \(name)")
    }

    // A case with no associated value reflects differently (Mirror reports no children), so it needs
    // its own coverage or half the enum cases in an app would resolve to nothing.
    func testNamesScreenFromRouteCaseWithoutAssociatedValue() {
        let host = UIHostingController(
            rootView: AnyView(Text("lazy destination")
                .modifier(RouteCarryingModifier(route: .tour))))

        XCTAssertEqual(SwiftUIScreenResolver.screenIdentity(for: host)?.viewName, "TestRoute.tour")
    }

    // Precedence: a real stored app view type is a better identity than a route, so it must win.
    func testStoredAppViewTypeWinsOverRouteEnum() {
        let host = UIHostingController(
            rootView: AnyView(CheckoutScreen()
                .modifier(RouteCarryingModifier(route: .listing(id: "L-1006")))))

        XCTAssertEqual(SwiftUIScreenResolver.screenIdentity(for: host)?.viewName, "CheckoutScreen")
    }

    // MARK: - Emit nothing when the type cannot be resolved
    //
    // The chosen semantics are precision over coverage: an unresolvable screen emits no event
    // at all rather than a synthetic name, so viewName never contains a placeholder.

    func testReturnsNilWhenContentIsOnlySwiftUIPrimitives() {
        let host = UIHostingController(rootView: AnyView(Text("just text")))

        XCTAssertNil(SwiftUIScreenResolver.screenIdentity(for: host))
    }

    // MARK: - Agent-injected types are never screens
    //
    // Session Replay wraps app content in MaskedContainerView / NRConditionalMaskView, and the
    // runtime probe found those inside real host class names. Naming a screen after the agent's
    // own wrapper would be a self-inflicted cardinality bug.

    func testIgnoresAgentInjectedWrapperTypes() {
        let host = UIHostingController(
            rootView: AnyView(MaskedContainerView(EnvironmentValues()) { Text("x") }))

        XCTAssertNil(SwiftUIScreenResolver.screenIdentity(for: host))
    }

    // MARK: - Modifier suppression
    //
    // Coexistence rule: where `.NRMobileView(...)` is present it wins, because it carries an
    // explicit name and custom attributes the resolver cannot know. The automatic producer must
    // stand down for that host or the screen reports twice.

    // Uses a locally declared stand-in rather than the real `.NRMobileView(...)` because the public
    // SwiftUI modifier API in NRViewModifier.swift is currently commented out in this working tree.
    // The rule under test is name-based -- `isExplicitInstrumentationMarker` looks for
    // "NRMobileViewModifier" anywhere in a visited type's name -- so a stand-in with that name
    // exercises the same code path. It does NOT prove the real modifier is detected; restore the
    // agent API and this should assert against `.NRMobileView()` directly.
    func testSuppressesHostAlreadyCarryingTheMobileViewModifier() {
        let host = UIHostingController(
            rootView: AnyView(CheckoutScreen().modifier(NRMobileViewModifier())))

        XCTAssertNil(SwiftUIScreenResolver.screenIdentity(for: host),
                     "a host instrumented with .NRMobileView must be left to the modifier")
    }

    // MARK: - Navigation participation
    //
    // A host is only a screen if it plays a navigation role. The probe found hosting
    // controllers at sub-screen granularity -- a navigation title's Text gets its own
    // UIHostingController<MaskedContainerView<Text>> -- so promoting every host would
    // over-count badly.

    func testDetachedHostIsNotAScreen() {
        // No parent, not presented, no window: nothing has navigated to this.
        let host = UIHostingController(rootView: AnyView(CheckoutScreen()))

        XCTAssertFalse(SwiftUIScreenResolver.isNavigationParticipating(host))
    }

    func testChildOfNavigationControllerIsAScreen() {
        let host = UIHostingController(rootView: AnyView(CheckoutScreen()))
        _ = UINavigationController(rootViewController: host)

        XCTAssertTrue(SwiftUIScreenResolver.isNavigationParticipating(host))
    }

    func testChildOfTabBarControllerIsAScreen() {
        let host = UIHostingController(rootView: AnyView(CheckoutScreen()))
        let tabs = UITabBarController()
        tabs.viewControllers = [host]

        XCTAssertTrue(SwiftUIScreenResolver.isNavigationParticipating(host))
    }

    // A sheet arrives as a presented controller rather than a child, so the parent chain alone
    // would miss every modal. Exercised through the rule's pure form: a real presentation never
    // completes in a test bundle with no active scene, so driving one here would test the
    // harness rather than the resolver. The app-level check for this path is
    // AutoInstrumentedDemoView's sheet.
    func testPresentedHostIsAScreen() {
        XCTAssertTrue(SwiftUIScreenResolver.isNavigationParticipating(parent: nil,
                                                                     presenter: UIViewController()))
    }

    // Neither navigated to nor presented.
    func testHostWithNoParentAndNoPresenterIsNotAScreen() {
        XCTAssertFalse(SwiftUIScreenResolver.isNavigationParticipating(parent: nil, presenter: nil))
    }

    // A plain container is not navigation: SwiftUI gives decorative sub-hosts an ordinary
    // UIViewController parent, and those must not be promoted to screens.
    func testChildOfPlainViewControllerIsNotAScreen() {
        XCTAssertFalse(SwiftUIScreenResolver.isNavigationParticipating(parent: UIViewController(),
                                                                      presenter: nil))
    }

    // MARK: - Naming a lazily-built destination from its wrapper's generic parameter
    //
    // The gap these close: `navigationDestination(for:)` and `.popover` both hand the agent a host
    // whose content is a *lazy* wrapper storing a closure. Reflection cannot see through a closure,
    // so requiring a stored `View`-conforming app value named nothing at all -- a walk of NRTestApp
    // found `NavItemDetailView`, `AutoStackDestinationScreen` and `PopoverDetailView` all displayed
    // on screen with zero MobileView events. The type is present, but only in the wrapper's generic
    // parameter, which is why these tests read a type name rather than a value.

    func testNamesScreenFromParameterizedLazyViewGenericParameter() {
        let host = UIHostingController(
            rootView: AnyView(ParameterizedLazyView { (_: TestRoute) in CheckoutScreen() }))

        XCTAssertEqual(SwiftUIScreenResolver.screenIdentity(for: host)?.viewName, "CheckoutScreen")
    }

    func testNamesScreenFromLazyViewGenericParameter() {
        let host = UIHostingController(rootView: AnyView(LazyView { CheckoutScreen() }))

        XCTAssertEqual(SwiftUIScreenResolver.screenIdentity(for: host)?.viewName, "CheckoutScreen")
    }

    // The route being a non-enum is the whole point: NRTestApp routes on `NavItem` (a struct) and
    // AutoInstrumentedDemoView routes on `String`, so the route/tag fallback could never name
    // either. The destination generic does not care what the route is.
    func testNamesScreenFromLazyDestinationWithNonEnumRoute() {
        let host = UIHostingController(
            rootView: AnyView(ParameterizedLazyView { (_: String) in ProductScreen() }))

        XCTAssertEqual(SwiftUIScreenResolver.screenIdentity(for: host)?.viewName, "ProductScreen")
    }

    // A real stored app view is a better identity than a generic parameter, so it must still win.
    func testStoredAppViewTypeWinsOverLazyDestinationGeneric() {
        let host = UIHostingController(
            rootView: AnyView(CheckoutScreen().modifier(RouteCarryingModifier(route: .tour))))

        XCTAssertEqual(SwiftUIScreenResolver.screenIdentity(for: host)?.viewName, "CheckoutScreen")
    }

    // MARK: - Lazy destination generic: what must NOT be named

    // `_ConditionalContent<A, B>` is what a destination closure with an `if` compiles to. It names
    // both branches and cannot say which one is on screen, so naming it would attribute a screen to
    // whichever branch was written first. Emit nothing instead.
    func testConditionalLazyDestinationIsNotNamed() {
        XCTAssertNil(SwiftUIScreenResolver.lazyDestinationTypeName(
            from: "SwiftUI.ParameterizedLazyView<MyApp.Route, SwiftUI._ConditionalContent<MyApp.A, MyApp.B>>"))
    }

    // A lazy wrapper over a SwiftUI primitive is decoration -- a navigation title's Text arrives
    // this way -- not a screen.
    func testLazyDestinationOverSwiftUIPrimitiveIsNotNamed() {
        XCTAssertNil(SwiftUIScreenResolver.lazyDestinationTypeName(from: "SwiftUI.LazyView<SwiftUI.Text>"))
    }

    // The trap this guards: `ModifiedContent<ParameterizedLazyView<Route, Screen>, SomeModifier>`
    // *contains* the wrapper's name, but its own last generic argument is the modifier. Matching by
    // substring would name every such screen "SomeModifier".
    func testModifiedContentWrappingALazyViewIsNotItselfALazyDestination() {
        XCTAssertNil(SwiftUIScreenResolver.lazyDestinationTypeName(
            from: "SwiftUI.ModifiedContent<SwiftUI.ParameterizedLazyView<MyApp.Route, MyApp.Screen>, SwiftUI.ClearNavigationContextModifier>"))
    }

    // Generic arguments are split at the top level only, or a route that is itself generic would
    // truncate the destination -- `Array<Int>` contains the comma that separates the two arguments.
    func testLazyDestinationSplitsGenericArgumentsAtTopLevelOnly() {
        XCTAssertEqual(SwiftUIScreenResolver.lazyDestinationTypeName(
            from: "SwiftUI.ParameterizedLazyView<Swift.Dictionary<Swift.String, Swift.Int>, MyApp.Screen>"),
                       "MyApp.Screen")
    }

    // The reflected form of a destination declared at private or function scope. The address is
    // build-specific, so it must not survive into the name.
    func testLazyDestinationStripsCompilerContextFromViewName() {
        let host = UIHostingController(rootView: AnyView(LazyView { PrivateSettingsScreen() }))

        XCTAssertEqual(SwiftUIScreenResolver.screenIdentity(for: host)?.viewName, "PrivateSettingsScreen")
    }

    // MARK: - Foreign modules are not app screens

    // The bug: a TabView tab's content lives in SwiftUI's attribute graph, unreachable by
    // reflection, so the route/tag scan kept walking and named every tab after the first foreign
    // enum it stumbled into -- `__C.CoreSystem.CoreSystem`, an imported C declaration. Every tab in
    // a TabView got the same wrong name, making tabs indistinguishable.
    func testImportedCTypesAreNotAppModuleTypes() {
        XCTAssertFalse(SwiftUIScreenResolver.isAppModuleType("__C.CoreSystem.CoreSystem"))
    }

    func testAppleFrameworkTypesAreNotAppModuleTypes() {
        XCTAssertFalse(SwiftUIScreenResolver.isAppModuleType("UIKit.UIUserInterfaceStyle"))
        XCTAssertFalse(SwiftUIScreenResolver.isAppModuleType("Foundation.ComparisonResult"))
        XCTAssertFalse(SwiftUIScreenResolver.isAppModuleType("CoreGraphics.CGLineCap"))
    }

    // The gate must stay open for app code, including app code that lives in a Swift package or
    // framework rather than the main bundle -- that is the common shape of a modularised app.
    func testAppAndThirdPartyModuleTypesAreAppModuleTypes() {
        XCTAssertTrue(SwiftUIScreenResolver.isAppModuleType("MyApp.TestRoute"))
        XCTAssertTrue(SwiftUIScreenResolver.isAppModuleType("DesignSystem.Route"))
    }

    // Precedence, not just rejection: the route scan walks SwiftUI's own bookkeeping and reaches
    // several acceptable enums, so without a preference the winner is whichever the breadth-first
    // traversal happened to reach first. Asserted on the predicate rather than end to end because a
    // test bundle cannot host a type in a second module -- both fixtures would reflect as
    // "Agent_Tests" and the assertion would pass on traversal order alone, proving nothing.
    func testAppsOwnModuleIsDistinguishedFromALinkedModule() {
        let previous = SwiftUIScreenResolver.mainBundleModule
        SwiftUIScreenResolver.mainBundleModule = "MyApp"
        defer { SwiftUIScreenResolver.mainBundleModule = previous }

        XCTAssertTrue(SwiftUIScreenResolver.isMainBundleModuleType("MyApp.TestRoute"))
        XCTAssertFalse(SwiftUIScreenResolver.isMainBundleModuleType("DesignSystem.Route"))
    }

    // MARK: - viewClass stability

    // `viewName` was already stripped; `viewClass` was not, so one screen's viewClass changed every
    // launch -- observed as "NRTestApp.(unknown context at $103c6ce48).SheetDetailView". IDD §6.1
    // wants viewClass to be the stable qualified type name.
    func testViewClassHasNoBuildSpecificCompilerContext() {
        let host = UIHostingController(rootView: AnyView(PrivateSettingsScreen()))

        let viewClass = SwiftUIScreenResolver.screenIdentity(for: host)?.viewClass ?? ""

        XCTAssertFalse(viewClass.contains("unknown context"),
                       "viewClass must not carry a build-specific address, got \(viewClass)")
        XCTAssertEqual(viewClass, "Agent_Tests.PrivateSettingsScreen")
    }

    // MARK: - Applies only to SwiftUI hosts

    // The UIKit producer already handles plain view controllers correctly. The resolver must not
    // claim them, or every UIKit screen would be re-decided by SwiftUI rules.
    func testPlainViewControllerIsNotASwiftUIHost() {
        XCTAssertFalse(SwiftUIScreenResolver.isSwiftUIHost(UIViewController()))
    }

    func testHostingControllerIsASwiftUIHost() {
        XCTAssertTrue(SwiftUIScreenResolver.isSwiftUIHost(UIHostingController(rootView: Text("x"))))
    }
}
