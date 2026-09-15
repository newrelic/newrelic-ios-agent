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

    func testSuppressesHostAlreadyCarryingTheMobileViewModifier() {
        let host = UIHostingController(rootView: AnyView(CheckoutScreen().NRMobileView()))

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
