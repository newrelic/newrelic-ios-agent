//
//  NRMobileViewFeatureFlagGateTests.swift
//  NewRelicAgent
//
//  Verifies that the SwiftUI MobileView modifiers honor the AutomaticMobileViews feature flag,
//  making the flag a true master switch. Previously the SwiftUI path
//  (NRViewModifier.swift) emitted "MobileView" events with no flag check, so simply attaching
//  .NRMobileView(...) started sending data even with the flag off.
//
//  See Agent/Instrumentation/MethodProfiling/NRViewModifier.swift.
//
//  Copyright © 2026 New Relic. All rights reserved.
//

import XCTest
@testable import NewRelic

final class NRMobileViewFeatureFlagGateTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // AutomaticMobileViews is opt-in (disabled by default). Start from a known-off state.
        NewRelic.disableFeatures(NRMAFeatureFlags.NRFeatureFlag_AutomaticMobileViews)
    }

    override func tearDown() {
        // Restore the default (off) so we don't leak flag state into other tests.
        NewRelic.disableFeatures(NRMAFeatureFlags.NRFeatureFlag_AutomaticMobileViews)
        super.tearDown()
    }

    // The bug: with the feature flag OFF, the SwiftUI modifier still recorded MobileView events.
    func testSwiftUIViewIsNotRecordedWhenAutomaticMobileViewsDisabled() {
        NewRelic.disableFeatures(NRMAFeatureFlags.NRFeatureFlag_AutomaticMobileViews)

        XCTAssertFalse(NRMobileViewGate.isFeatureEnabled,
                       "AutomaticMobileViews must be reported disabled after disableFeatures:")
        XCTAssertFalse(NRMobileViewGate.shouldRecord(viewName: "CheckoutView"),
                       "SwiftUI MobileView must NOT record while AutomaticMobileViews is disabled")
    }

    func testSwiftUIViewIsRecordedWhenAutomaticMobileViewsEnabled() {
        NewRelic.enableFeatures(NRMAFeatureFlags.NRFeatureFlag_AutomaticMobileViews)

        XCTAssertTrue(NRMobileViewGate.isFeatureEnabled,
                      "AutomaticMobileViews must be reported enabled after enableFeatures:")
        XCTAssertTrue(NRMobileViewGate.shouldRecord(viewName: "CheckoutView"),
                      "SwiftUI MobileView must record while AutomaticMobileViews is enabled")
    }

    // The flag is the only switch. There is no per-view opt-out to override it: the `ignored:`
    // parameter on .NRMobileView(...) is gone, because an attached-but-silent modifier is
    // indistinguishable in the data from a modifier that was never attached. Not tracking a screen
    // means not attaching the modifier.
    func testSystemContainersAreStillSkippedWhenEnabled() {
        NewRelic.enableFeatures(NRMAFeatureFlags.NRFeatureFlag_AutomaticMobileViews)

        XCTAssertFalse(NRMobileViewGate.shouldRecord(viewName: "UITabBarController"),
                       "the agent's own class-prefix skip list is not a customer-facing opt-out, and stays")
    }
}
