//
//  MobileViewEmitterTests.swift
//  NewRelicAgent
//
//  Covers the schema MobileViewEmitter.swift owns. Before it existed, each of the nine
//  emission sites assembled its own attribute dictionary, and they disagreed: `churn`
//  reached only the SwiftUI producers, `navigationKind` only the tab ones, `agentName`
//  only some, and the loadTime-vs-loadTimeUnavailable rule was reimplemented four times.
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

    private func appearRecord(load: NRViewLoadOutcome? = nil,
                              custom: [String: Any]? = nil) -> MobileViewRecord {
        MobileViewRecord(viewName: "CheckoutView",
                         viewClass: "MyApp.CheckoutView",
                         instanceId: "instance-1",
                         platform: .swiftUI,
                         phase: .appeared,
                         load: load,
                         custom: custom)
    }

    // MARK: - Identity and phase

    func testAppearedWritesTheIdentityAttributesAndAppearedTrue() {
        let attrs = appearRecord().attributes()

        XCTAssertEqual(attrs["viewName"] as? String, "CheckoutView")
        XCTAssertEqual(attrs["viewClass"] as? String, "MyApp.CheckoutView")
        XCTAssertEqual(attrs["viewInstanceId"] as? String, "instance-1")
        XCTAssertEqual(attrs["uiPlatform"] as? String, "SwiftUI")
        XCTAssertEqual(attrs["appeared"] as? NSNumber, NSNumber(value: true))
    }

    func testDisappearedWritesAppearedFalse() {
        var record = appearRecord()
        record.phase = .disappeared

        XCTAssertEqual(record.attributes()["appeared"] as? NSNumber, NSNumber(value: false))
    }

    // An absent platform must read as absent, not as an empty string. The synthesized
    // re-appearance is the producer that has none, when the uncovered entry was recorded
    // without one.
    func testNilPlatformOmitsUiPlatformRatherThanEmittingEmptyString() {
        var record = appearRecord()
        record.platform = nil

        XCTAssertNil(record.attributes()["uiPlatform"])
    }

    // MARK: - The loadTime rule

    func testMeasuredLoadWritesLoadTimeAndNotTheReason() {
        let attrs = appearRecord(load: .measured(123.5)).attributes()

        XCTAssertEqual(attrs["loadTime"] as? NSNumber, NSNumber(value: 123.5))
        XCTAssertNil(attrs["loadTimeUnavailable"],
                     "loadTime and loadTimeUnavailable are mutually exclusive")
    }

    func testUnavailableLoadWritesTheReasonAndNotLoadTime() {
        let attrs = appearRecord(load: .unavailable(.notRebuilt)).attributes()

        XCTAssertEqual(attrs["loadTimeUnavailable"] as? String, "notRebuilt")
        XCTAssertNil(attrs["loadTime"],
                     "loadTime is omitted rather than zeroed, so it cannot drag percentiles to 0")
    }

    func testNoLoadOutcomeOmitsBothKeys() {
        let attrs = appearRecord(load: nil).attributes()

        XCTAssertNil(attrs["loadTime"])
        XCTAssertNil(attrs["loadTimeUnavailable"])
    }

    func testEveryUnavailableReasonKeepsItsWireString() {
        // These strings are already in customers' NRQL, so they are part of the contract.
        XCTAssertEqual(NRViewLoadOutcome.Reason.constructedBeforeAppear.rawValue, "constructedBeforeAppear")
        XCTAssertEqual(NRViewLoadOutcome.Reason.noConstructionObserved.rawValue, "noConstructionObserved")
        XCTAssertEqual(NRViewLoadOutcome.Reason.notRebuilt.rawValue, "notRebuilt")
    }

    // MARK: - timeVisible and churn

    // churn used to be set only by the SwiftUI disappear site, so a UIKit or manual view with
    // the same sub-dwell lifetime went unmarked and inflated screen-view counts.
    func testShortLifetimeIsMarkedAsChurnForEveryPlatform() {
        for platform in [NRViewPlatform.uiKit, .swiftUI, .manual] {
            var record = appearRecord()
            record.phase = .disappeared
            record.platform = platform
            record.timeVisibleMs = NRMobileViewEmitter.minimumDwellMs - 1

            let attrs = record.attributes()
            XCTAssertEqual(attrs["churn"] as? NSNumber, NSNumber(value: true),
                           "\(platform.rawValue) must mark churn like every other producer")
            XCTAssertEqual(attrs["timeVisible"] as? NSNumber,
                           NSNumber(value: NRMobileViewEmitter.minimumDwellMs - 1))
        }
    }

    func testLifetimeAtOrAboveTheDwellThresholdIsNotChurn() {
        var record = appearRecord()
        record.phase = .disappeared
        record.timeVisibleMs = NRMobileViewEmitter.minimumDwellMs

        XCTAssertNil(record.attributes()["churn"],
                     "churn must be absent so `WHERE churn IS NULL` selects real visits")
    }

    func testNoTimeVisibleOmitsBothTimeVisibleAndChurn() {
        let attrs = appearRecord().attributes()

        XCTAssertNil(attrs["timeVisible"])
        XCTAssertNil(attrs["churn"])
    }

    // MARK: - Optional facts

    func testRestartedIsOmittedWhenTheProducerCannotKnowIt() {
        var record = appearRecord()
        record.restarted = nil
        XCTAssertNil(record.attributes()["restarted"])

        record.restarted = true
        XCTAssertEqual(record.attributes()["restarted"] as? NSNumber, NSNumber(value: true))
    }

    func testReappearedIsWrittenOnlyForASynthesizedAppearance() {
        var record = appearRecord()
        XCTAssertNil(record.attributes()["reappeared"])

        record.reappeared = true
        XCTAssertEqual(record.attributes()["reappeared"] as? NSNumber,
                       NSNumber(value: true))
    }

    func testNavigationKindIsWrittenOnlyWhenPresent() {
        var record = appearRecord()
        XCTAssertNil(record.attributes()["navigationKind"])

        record.navigationKind = "tab"
        XCTAssertEqual(record.attributes()["navigationKind"] as? String, "tab")
    }

    // MARK: - Referrer

    func testExplicitReferrerIsWritten() {
        var record = appearRecord()
        record.referrer = .explicit(name: "CartView", instanceId: "instance-0")

        let attrs = record.attributes()
        XCTAssertEqual(attrs["previousView"] as? String, "CartView")
        XCTAssertEqual(attrs["previousViewInstanceId"] as? String, "instance-0")
    }

    func testEmptyExplicitReferrerIsOmitted() {
        var record = appearRecord()
        record.referrer = .explicit(name: "", instanceId: "")

        let attrs = record.attributes()
        XCTAssertNil(attrs["previousView"])
        XCTAssertNil(attrs["previousViewInstanceId"])
    }

    func testNoReferrerWritesNeitherKey() {
        let attrs = appearRecord().attributes()

        XCTAssertNil(attrs["previousView"])
        XCTAssertNil(attrs["previousViewInstanceId"])
    }

    // MARK: - Customer attributes

    func testCustomerAttributesArePreserved() {
        let attrs = appearRecord(custom: ["cartValue": 42, "tier": "gold"]).attributes()

        XCTAssertEqual(attrs["cartValue"] as? Int, 42)
        XCTAssertEqual(attrs["tier"] as? String, "gold")
    }

    // The schema has to be stable no matter what an app returns from nrMobileViewAttributes.
    func testCustomerAttributesCannotOverrideReservedKeys() {
        let hostile: [String: Any] = [
            "viewName":       "spoofed",
            "viewClass":      "spoofed",
            "viewInstanceId": "spoofed",
            "appeared":       NSNumber(value: false),
            "uiPlatform":     "spoofed",
            "loadTime":       NSNumber(value: 999),
        ]
        let attrs = appearRecord(load: .measured(10), custom: hostile).attributes()

        XCTAssertEqual(attrs["viewName"] as? String, "CheckoutView")
        XCTAssertEqual(attrs["viewClass"] as? String, "MyApp.CheckoutView")
        XCTAssertEqual(attrs["viewInstanceId"] as? String, "instance-1")
        XCTAssertEqual(attrs["appeared"] as? NSNumber, NSNumber(value: true))
        XCTAssertEqual(attrs["uiPlatform"] as? String, "SwiftUI")
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

    // A synthesized re-appearance has no platform, and only the automatic producers can
    // trigger one.
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
                                     previousView: "CartView",
                                     platform: .uiKit).attributes()

        XCTAssertEqual(attrs["timingName"] as? String, "timeToInitialDisplay")
        XCTAssertEqual(attrs["timingValue"] as? NSNumber, NSNumber(value: 250.5))
        XCTAssertEqual(attrs["viewName"] as? String, "CheckoutView")
        XCTAssertEqual(attrs["viewInstanceId"] as? String, "instance-1")
        XCTAssertEqual(attrs["previousView"] as? String, "CartView")
        XCTAssertEqual(attrs["uiPlatform"] as? String, "UIKit")
        XCTAssertEqual(attrs["agentName"] as? String, "iOS")
    }

    // MobileView dropped agentName at 6 of its 8 sites before this change; MobileViewTiming had a
    // single site that kept it. The asymmetry is preserved deliberately -- see the report.
    func testMobileViewRecordDoesNotCarryAgentName() {
        XCTAssertNil(appearRecord().attributes()["agentName"])
    }

    // An absent view must read as absent, not as an empty string.
    func testTimingRecordOmitsEmptyOptionalFields() {
        let attrs = ViewTimingRecord(timingName: "custom",
                                     timingValueMs: 1,
                                     viewName: "",
                                     viewInstanceId: nil,
                                     previousView: "",
                                     platform: nil).attributes()

        XCTAssertNil(attrs["viewName"])
        XCTAssertNil(attrs["viewInstanceId"])
        XCTAssertNil(attrs["previousView"])
        XCTAssertNil(attrs["uiPlatform"])
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
        fields.platform = "UIKit"
        fields.loadTimeMs = NSNumber(value: 88)
        fields.restarted = NSNumber(value: true)
        fields.custom = ["tier": "gold"]

        guard let record = fields.record(phase: .appeared) else {
            return XCTFail("fields with a view name must produce a record")
        }
        let attrs = record.attributes()

        XCTAssertEqual(attrs["viewName"] as? String, "CheckoutView")
        XCTAssertEqual(attrs["viewClass"] as? String, "MyApp.CheckoutViewController")
        XCTAssertEqual(attrs["uiPlatform"] as? String, "UIKit")
        XCTAssertEqual(attrs["loadTime"] as? NSNumber, NSNumber(value: 88))
        XCTAssertEqual(attrs["restarted"] as? NSNumber, NSNumber(value: true))
        XCTAssertEqual(attrs["tier"] as? String, "gold")
        XCTAssertEqual(attrs["appeared"] as? NSNumber, NSNumber(value: true))
    }

    func testObjCFacadeRejectsAnEmptyViewName() {
        let fields = NRMAMobileViewFields()
        fields.instanceId = "instance-1"

        XCTAssertNil(fields.record(phase: .appeared),
                     "a view with no name must not produce an event")
    }

    // An unrecognized platform string omits uiPlatform rather than writing it through, which
    // is what the synthesized re-appearance depends on when it has no platform to report.
    func testObjCFacadeTreatsAnUnknownPlatformAsAbsent() {
        let fields = NRMAMobileViewFields()
        fields.viewName = "CheckoutView"
        fields.platform = ""

        XCTAssertNil(fields.record(phase: .appeared)?.attributes()["uiPlatform"])
    }

    func testObjCFacadeLoadTimeWinsOverAReasonWhenBothAreSet() {
        let fields = NRMAMobileViewFields()
        fields.viewName = "CheckoutView"
        fields.loadTimeMs = NSNumber(value: 5)
        fields.loadTimeUnavailable = "notRebuilt"

        let attrs = fields.record(phase: .appeared)!.attributes()
        XCTAssertEqual(attrs["loadTime"] as? NSNumber, NSNumber(value: 5))
        XCTAssertNil(attrs["loadTimeUnavailable"])
    }

    func testObjCFacadePrefersAnExplicitReferrerOverTheContextOne() {
        let fields = NRMAMobileViewFields()
        fields.viewName = "CheckoutView"
        fields.useContextReferrer = true
        fields.previousView = "CartView"
        fields.previousViewInstanceId = "instance-0"

        let attrs = fields.record(phase: .appeared)!.attributes()
        XCTAssertEqual(attrs["previousView"] as? String, "CartView")
        XCTAssertEqual(attrs["previousViewInstanceId"] as? String, "instance-0")
    }
}
