//
//  SessionReplayReporterReferrerAttributesTests.swift
//  NewRelicAgent
//
//  Covers the current/previous view a SessionReplay chunk is decorated with, the same four referrer
//  attributes MobileRequest, MobileRequestError, MobileBreadcrumb and handled exceptions carry.
//  Exercises addReferrerAttributes(to:) rather than uploadURL(), which also needs a resolvable
//  harvester configuration (see SessionReplayHarvestEndToEndTests).
//
//  Copyright © 2026 New Relic. All rights reserved.
//

import XCTest
@testable import NewRelic

final class SessionReplayReporterReferrerAttributesTests: XCTestCase {

    override func setUp() {
        super.setUp()
        NewRelic.disableFeatures(NRMAFeatureFlags.NRFeatureFlag_AutomaticMobileViews)
        NewRelic.disableFeatures(NRMAFeatureFlags.NRFeatureFlag_ManualMobileViews)
    }

    override func tearDown() {
        NewRelic.disableFeatures(NRMAFeatureFlags.NRFeatureFlag_AutomaticMobileViews)
        NewRelic.disableFeatures(NRMAFeatureFlags.NRFeatureFlag_ManualMobileViews)
        super.tearDown()
    }

    /// Unique per test, so a view a previous test left current can't satisfy the assertions.
    private func navigate(from previous: String, to current: String) {
        NewRelic.enableFeatures(NRMAFeatureFlags.NRFeatureFlag_ManualMobileViews)
        NewRelic.setCurrentView(previous, viewClass: previous, uiFramework: "Manual", attributes: nil)
        NewRelic.setCurrentView(current, viewClass: current, uiFramework: "Manual", attributes: nil)
    }

    func testStampsCurrentAndPreviousViewWhenMobileViewsEnabled() {
        navigate(from: "SRCartScreen", to: "SRCheckoutScreen")

        var attributes: [String: String] = ["entityGuid": "guid"]
        SessionReplayReporter.addReferrerAttributes(to: &attributes)

        XCTAssertEqual(attributes["currentView"], "SRCheckoutScreen")
        XCTAssertEqual(attributes["previousView"], "SRCartScreen")
        XCTAssertFalse(attributes["currentViewInstanceId"]?.isEmpty ?? true)
        XCTAssertFalse(attributes["previousViewInstanceId"]?.isEmpty ?? true)
        XCTAssertNotEqual(attributes["currentViewInstanceId"], attributes["previousViewInstanceId"])
        XCTAssertEqual(attributes["entityGuid"], "guid")
    }

    func testAddsNothingWhenBothMobileViewsFlagsAreDisabled() {
        navigate(from: "SRGatedCartScreen", to: "SRGatedCheckoutScreen")
        NewRelic.disableFeatures(NRMAFeatureFlags.NRFeatureFlag_ManualMobileViews)

        var attributes: [String: String] = ["entityGuid": "guid"]
        SessionReplayReporter.addReferrerAttributes(to: &attributes)

        XCTAssertEqual(attributes, ["entityGuid": "guid"])
    }

    /// Session attributes are copied into the chunk first, so a customer attribute named
    /// `currentView` must not mask the agent's own.
    func testAgentReferrerWinsOverSessionAttributeOfTheSameName() {
        navigate(from: "SROverrideCartScreen", to: "SROverrideCheckoutScreen")

        var attributes: [String: String] = ["currentView": "customer-supplied"]
        SessionReplayReporter.addReferrerAttributes(to: &attributes)

        XCTAssertEqual(attributes["currentView"], "SROverrideCheckoutScreen")
    }
}
