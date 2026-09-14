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
        XCTAssertFalse(NRMobileViewGate.shouldRecord(ignored: false, viewName: "CheckoutView"),
                       "SwiftUI MobileView must NOT record while AutomaticMobileViews is disabled")
    }

    func testSwiftUIViewIsRecordedWhenAutomaticMobileViewsEnabled() {
        NewRelic.enableFeatures(NRMAFeatureFlags.NRFeatureFlag_AutomaticMobileViews)

        XCTAssertTrue(NRMobileViewGate.isFeatureEnabled,
                      "AutomaticMobileViews must be reported enabled after enableFeatures:")
        XCTAssertTrue(NRMobileViewGate.shouldRecord(ignored: false, viewName: "CheckoutView"),
                      "SwiftUI MobileView must record while AutomaticMobileViews is enabled")
    }

    // Even with the flag on, an explicitly ignored view must never record.
    func testIgnoredSwiftUIViewIsNotRecordedEvenWhenEnabled() {
        NewRelic.enableFeatures(NRMAFeatureFlags.NRFeatureFlag_AutomaticMobileViews)

        XCTAssertFalse(NRMobileViewGate.shouldRecord(ignored: true, viewName: "CheckoutView"),
                       "A view marked ignored must not record even when the flag is on")
    }
}
