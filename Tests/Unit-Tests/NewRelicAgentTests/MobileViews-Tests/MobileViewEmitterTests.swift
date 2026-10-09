//
//  MobileViewEmitterTests.swift
//  NewRelicAgent
//
//  Covers the schema MobileViewEmitter.swift owns. Before it existed, each of the nine
//  emission sites assembled its own attribute dictionary, and they disagreed:
//  `navigationKind` reached only the tab producers, `agentName` only some, and the
//  loadTime-vs-loadTimeUnavailable rule was reimplemented four times.
//
//  A record describes one whole visit, emitted when the view goes away. There is no appear/disappear
//  pair and no `appeared` flag: `loadTime` and the referrer are captured at appear time by the
//  producer and handed to the record it builds at the end.
//
//  Copyright © 2026 New Relic. All rights reserved.
//

import XCTest
@testable import NewRelic

final class MobileViewEmitterTests: XCTestCase {

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

    private func visitRecord(load: NRViewLoadOutcome? = nil,
                             custom: [String: Any]? = nil) -> MobileViewRecord {
        MobileViewRecord(viewName: "CheckoutView",
                         viewClass: "MyApp.CheckoutView",
                         instanceId: "instance-1",
                         framework: .swiftUI,
                         load: load,
                         custom: custom)
    }

    // MARK: - Identity

    func testARecordWritesTheIdentityAttributes() {
        let attrs = visitRecord().attributes()

        XCTAssertEqual(attrs["viewName"] as? String, "CheckoutView")
        XCTAssertEqual(attrs["viewClass"] as? String, "MyApp.CheckoutView")
        XCTAssertEqual(attrs["viewInstanceId"] as? String, "instance-1")
        XCTAssertEqual(attrs["uiFramework"] as? String, "SwiftUI")
    }

    // MobileView is one event per visit now, emitted when the view goes away. `appeared` was the
    // flag that told the two halves apart; with one event it carries no information, so it is not
    // written at all rather than written as a constant.
    func testNoRecordWritesTheAppearedFlag() {
        var record = visitRecord(load: .measured(10))
        record.timeVisibleMs = 500

        XCTAssertNil(record.attributes()["appeared"],
                     "one event per visit means `appeared` carries no information")
    }

    // `restarted` is retired for the same reason plus one of its own: it described the view
    // *instance*, so it answered "has this object been on screen before" rather than "has the user
    // seen this screen before", which is what anyone reading it assumed.
    func testNoRecordWritesTheRestartedFlag() {
        var record = visitRecord(load: .measured(10))
        record.timeVisibleMs = 500

        XCTAssertNil(record.attributes()["restarted"])
    }

    // An absent platform must read as absent, not as an empty string.
    func testNilPlatformOmitsUiPlatformRatherThanEmittingEmptyString() {
        var record = visitRecord()
        record.framework = nil

        XCTAssertNil(record.attributes()["uiFramework"])
    }

    // MARK: - The loadTime rule

    func testMeasuredLoadWritesLoadTimeAndNotTheReason() {
        let attrs = visitRecord(load: .measured(123.5)).attributes()

        XCTAssertEqual(attrs["loadTime"] as? NSNumber, NSNumber(value: 123.5))
        XCTAssertNil(attrs["loadTimeUnavailable"],
                     "loadTime and loadTimeUnavailable are mutually exclusive")
    }

    func testUnavailableLoadWritesTheReasonAndNotLoadTime() {
        let attrs = visitRecord(load: .unavailable(.notRebuilt)).attributes()

        XCTAssertEqual(attrs["loadTimeUnavailable"] as? String, "notRebuilt")
        XCTAssertNil(attrs["loadTime"],
                     "loadTime is omitted rather than zeroed, so it cannot drag percentiles to 0")
    }

    func testNoLoadOutcomeOmitsBothKeys() {
        let attrs = visitRecord(load: nil).attributes()

        XCTAssertNil(attrs["loadTime"])
        XCTAssertNil(attrs["loadTimeUnavailable"])
    }

    func testEveryUnavailableReasonKeepsItsWireString() {
        // These strings are already in customers' NRQL, so they are part of the contract.
        XCTAssertEqual(NRViewLoadOutcome.Reason.constructedBeforeAppear.rawValue, "constructedBeforeAppear")
        XCTAssertEqual(NRViewLoadOutcome.Reason.noConstructionObserved.rawValue, "noConstructionObserved")
        XCTAssertEqual(NRViewLoadOutcome.Reason.notRebuilt.rawValue, "notRebuilt")
    }

    // MARK: - timeVisible

    // The emitter used to classify a visit shorter than a 100ms minimum dwell as `churn`, so
    // consumers could exclude it with `WHERE churn IS NULL`. That threshold is gone: a brief
    // visit is reported with its real duration and nothing else, and whether it counts as a
    // screen view is the consumer's decision rather than one the agent makes.
    func testAShortLifetimeIsReportedVerbatimAndNotClassified() {
        for framework in [NRViewFramework.uiKit, .swiftUI, .manual] {
            var record = visitRecord()
            record.framework = framework
            record.timeVisibleMs = 1

            let attrs = record.attributes()
            XCTAssertEqual(attrs["timeVisible"] as? NSNumber, NSNumber(value: 1.0),
                           "\(framework.rawValue) must report the lifetime it observed")
            XCTAssertNil(attrs["churn"],
                         "\(framework.rawValue) must not reintroduce a churn classification")
        }
    }

    // A zero-millisecond visit is the extreme of the same rule: still an event, still no
    // threshold applied. Distinguishable from "not measured" because the key is present.
    func testAZeroLifetimeStillReportsTimeVisible() {
        var record = visitRecord()
        record.timeVisibleMs = 0

        let attrs = record.attributes()
        XCTAssertEqual(attrs["timeVisible"] as? NSNumber, NSNumber(value: 0.0))
        XCTAssertNil(attrs["churn"])
    }

    func testNoTimeVisibleOmitsTimeVisible() {
        let attrs = visitRecord().attributes()

        XCTAssertNil(attrs["timeVisible"])
        XCTAssertNil(attrs["churn"])
    }

    // MARK: - Optional facts

    func testNavigationKindIsWrittenOnlyWhenPresent() {
        var record = visitRecord()
        XCTAssertNil(record.attributes()["navigationKind"])

        record.navigationKind = "tab"
        XCTAssertEqual(record.attributes()["navigationKind"] as? String, "tab")
    }

    // MARK: - Referrer

    func testExplicitReferrerIsWritten() {
        var record = visitRecord()
        record.referrer = .explicit(name: "CartView", instanceId: "instance-0")

        let attrs = record.attributes()
        XCTAssertEqual(attrs["previousView"] as? String, "CartView")
        XCTAssertEqual(attrs["previousViewInstanceId"] as? String, "instance-0")
    }

    func testEmptyExplicitReferrerIsOmitted() {
        var record = visitRecord()
        record.referrer = .explicit(name: "", instanceId: "")

        let attrs = record.attributes()
        XCTAssertNil(attrs["previousView"])
        XCTAssertNil(attrs["previousViewInstanceId"])
    }

    func testNoReferrerWritesNeitherKey() {
        let attrs = visitRecord().attributes()

        XCTAssertNil(attrs["previousView"])
        XCTAssertNil(attrs["previousViewInstanceId"])
    }

    // MARK: - Customer attributes

    func testCustomerAttributesArePreserved() {
        let attrs = visitRecord(custom: ["cartValue": 42, "tier": "gold"]).attributes()

        XCTAssertEqual(attrs["cartValue"] as? Int, 42)
        XCTAssertEqual(attrs["tier"] as? String, "gold")
    }

    // The schema has to be stable no matter what an app returns from nrMobileViewAttributes.
    func testCustomerAttributesCannotOverrideReservedKeys() {
        let hostile: [String: Any] = [
            "viewName":       "spoofed",
            "viewClass":      "spoofed",
            "viewInstanceId": "spoofed",
            "uiFramework":     "spoofed",
            "loadTime":       NSNumber(value: 999),
        ]
        let attrs = visitRecord(load: .measured(10), custom: hostile).attributes()

        XCTAssertEqual(attrs["viewName"] as? String, "CheckoutView")
        XCTAssertEqual(attrs["viewClass"] as? String, "MyApp.CheckoutView")
        XCTAssertEqual(attrs["viewInstanceId"] as? String, "instance-1")
        XCTAssertEqual(attrs["uiFramework"] as? String, "SwiftUI")
        XCTAssertEqual(attrs["loadTime"] as? NSNumber, NSNumber(value: 10))
    }

    // MARK: - Gate

    func testAutomaticProducersAreGatedByTheAutomaticFlag() {
        XCTAssertFalse(NRMobileViewEmitter.isEnabled(for: .uiKit))
        XCTAssertFalse(NRMobileViewEmitter.isEnabled(for: .swiftUI))

        NewRelic.enableFeatures(NRMAFeatureFlags.NRFeatureFlag_AutomaticMobileViews)
        XCTAssertTrue(NRMobileViewEmitter.isEnabled(for: .uiKit))
        XCTAssertTrue(NRMobileViewEmitter.isEnabled(for: .swiftUI))
        // The manual API is a separate opt-in and must not ride along.
        XCTAssertFalse(NRMobileViewEmitter.isEnabled(for: .manual))
    }

    func testManualProducerIsGatedByTheManualFlag() {
        XCTAssertFalse(NRMobileViewEmitter.isEnabled(for: .manual))

        NewRelic.enableFeatures(NRMAFeatureFlags.NRFeatureFlag_ManualMobileViews)
        XCTAssertTrue(NRMobileViewEmitter.isEnabled(for: .manual))
        XCTAssertFalse(NRMobileViewEmitter.isEnabled(for: .uiKit))
    }

    // A record with no platform can only have come from an automatic producer.
    func testPlatformlessRecordIsGatedByTheAutomaticFlag() {
        XCTAssertFalse(NRMobileViewEmitter.isEnabled(for: nil))

        NewRelic.enableFeatures(NRMAFeatureFlags.NRFeatureFlag_AutomaticMobileViews)
        XCTAssertTrue(NRMobileViewEmitter.isEnabled(for: nil))
    }

    func testViewTrackingIsEnabledByEitherFlag() {
        XCTAssertFalse(NRMobileViewEmitter.isViewTrackingEnabled)

        NewRelic.enableFeatures(NRMAFeatureFlags.NRFeatureFlag_ManualMobileViews)
        XCTAssertTrue(NRMobileViewEmitter.isViewTrackingEnabled,
                      "Timing rows describe a view, so either producer being on is enough")
    }

    // MARK: - Timing records

    func testTimingRecordWritesNameAndValue() {
        let attrs = ViewTimingRecord(timingName: "timeToInitialDisplay",
                                     timingValueMs: 250.5,
                                     viewName: "CheckoutView",
                                     viewInstanceId: "instance-1",
                                     previousView: "CartView").attributes()

        XCTAssertEqual(attrs["timingName"] as? String, "timeToInitialDisplay")
        XCTAssertEqual(attrs["timingValue"] as? NSNumber, NSNumber(value: 250.5))
        XCTAssertEqual(attrs["viewName"] as? String, "CheckoutView")
        XCTAssertEqual(attrs["viewInstanceId"] as? String, "instance-1")
        XCTAssertEqual(attrs["previousView"] as? String, "CartView")
        XCTAssertEqual(attrs["agentName"] as? String, "iOS")
    }

    // MobileView dropped agentName at 6 of its 8 sites before this change; MobileViewTiming had a
    // single site that kept it. The asymmetry is preserved deliberately -- see the report.
    func testMobileViewRecordDoesNotCarryAgentName() {
        XCTAssertNil(visitRecord().attributes()["agentName"])
    }

    // An absent view must read as absent, not as an empty string.
    func testTimingRecordOmitsEmptyOptionalFields() {
        let attrs = ViewTimingRecord(timingName: "custom",
                                     timingValueMs: 1,
                                     viewName: "",
                                     viewInstanceId: nil,
                                     previousView: "").attributes()

        XCTAssertNil(attrs["viewName"])
        XCTAssertNil(attrs["viewInstanceId"])
        XCTAssertNil(attrs["previousView"])
        XCTAssertEqual(attrs["timingName"] as? String, "custom")
    }

    // MARK: - Objective-C facade

    // The facade is the only surface that can drift from the record, so it gets its own
    // coverage: it must map onto exactly the same schema.
    func testObjCFacadeMapsOntoTheSameSchema() {
        let fields = NRMAMobileViewFields()
        fields.viewName = "CheckoutView"
        fields.viewClass = "MyApp.CheckoutViewController"
        fields.instanceId = "instance-1"
        fields.uiFramework = "UIKit"
        fields.loadTimeMs = NSNumber(value: 88)
        fields.custom = ["tier": "gold"]

        guard let record = fields.record() else {
            return XCTFail("fields with a view name must produce a record")
        }
        let attrs = record.attributes()

        XCTAssertEqual(attrs["viewName"] as? String, "CheckoutView")
        XCTAssertEqual(attrs["viewClass"] as? String, "MyApp.CheckoutViewController")
        XCTAssertEqual(attrs["uiFramework"] as? String, "UIKit")
        XCTAssertEqual(attrs["loadTime"] as? NSNumber, NSNumber(value: 88))
        XCTAssertEqual(attrs["tier"] as? String, "gold")
    }

    func testObjCFacadeRejectsAnEmptyViewName() {
        let fields = NRMAMobileViewFields()
        fields.instanceId = "instance-1"

        XCTAssertNil(fields.record(),
                     "a view with no name must not produce an event")
    }

    // An unrecognized platform string omits uiFramework rather than writing it through.
    func testObjCFacadeTreatsAnUnknownPlatformAsAbsent() {
        let fields = NRMAMobileViewFields()
        fields.viewName = "CheckoutView"
        fields.uiFramework = ""

        XCTAssertNil(fields.record()?.attributes()["uiFramework"])
    }

    func testObjCFacadeLoadTimeWinsOverAReasonWhenBothAreSet() {
        let fields = NRMAMobileViewFields()
        fields.viewName = "CheckoutView"
        fields.loadTimeMs = NSNumber(value: 5)
        fields.loadTimeUnavailable = "notRebuilt"

        let attrs = fields.record()!.attributes()
        XCTAssertEqual(attrs["loadTime"] as? NSNumber, NSNumber(value: 5))
        XCTAssertNil(attrs["loadTimeUnavailable"])
    }

    func testObjCFacadePrefersAnExplicitReferrerOverTheContextOne() {
        let fields = NRMAMobileViewFields()
        fields.viewName = "CheckoutView"
        fields.useContextReferrer = true
        fields.previousView = "CartView"
        fields.previousViewInstanceId = "instance-0"

        let attrs = fields.record()!.attributes()
        XCTAssertEqual(attrs["previousView"] as? String, "CartView")
        XCTAssertEqual(attrs["previousViewInstanceId"] as? String, "instance-0")
    }
}
