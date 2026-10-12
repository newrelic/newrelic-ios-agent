//
//  NewRelicConfig.swift
//  ExpensesTracker
//
//  Agent startup, feature-flag enablement, and the startup instrumentation the Android app performed
//  in MainActivity.onCreate — all in one place instead of scattered through the first screen.
//
//  Why it moved: on Android the agent was started from MainActivity, so `NewRelic.withApplicationToken(…)
//  .start(context)` sat in the middle of the login screen's setup code. On iOS the documented place is
//  application(_:didFinishLaunchingWithOptions:), and this app's job is to report faithfully on what
//  the agent recorded — it should not add a startup-ordering question of its own.
//
//  Two modes, chosen with the NR_MODE environment variable:
//
//    live    — reports to the New Relic staging collector, matching the Android app's
//              usingCollectorAddress("staging-mobile-collector.newrelic.com"). Data is queryable
//              with NRQL. Set the token with NR_APP_TOKEN in the scheme (Product ▸ Scheme ▸ Edit
//              Scheme ▸ Run ▸ Arguments ▸ Environment Variables), or fill in NRAPIKey in
//              NRAPI-Info.plist. The plist is what CI writes: uploadApp-expensestracker.yml sets it
//              from a repository secret before building the LambdaTest upload, since an app
//              launched by LambdaTest has no scheme environment. Same file and keys as NRTestApp.
//
//    capture — reports to NRCollectorStub on localhost, which prints every MobileView, breadcrumb
//              and interaction event from each harvest to the console. No account needed.
//
//  With no NR_MODE set, live is used when a token is available and capture otherwise, so a fresh
//  clone does something useful without configuration. Same shape as HomeSearch's NewRelicConfig.
//

import Foundation
import UIKit
import NewRelic

enum NewRelicConfig {

    /// Used when NR_APP_TOKEN is not set. Empty in the committed plist — never commit a token —
    /// which makes a fresh clone fall through to capture mode.
    private static var fallbackApplicationToken: String {
        apiInfo("NRAPIKey")
    }

    /// Collector overrides from NRAPI-Info.plist; empty means the staging collectors below.
    private static var collectorAddress: String {
        let fromPlist = apiInfo("collectorAddress")
        return fromPlist.isEmpty ? "staging-mobile-collector.newrelic.com" : fromPlist
    }

    private static var crashCollectorAddress: String {
        let fromPlist = apiInfo("crashCollectorAddress")
        return fromPlist.isEmpty ? "staging-mobile-crash.newrelic.com" : fromPlist
    }

    private static func apiInfo(_ key: String) -> String {
        guard let url = Bundle.main.url(forResource: "NRAPI-Info", withExtension: "plist"),
              let values = NSDictionary(contentsOf: url) else {
            return ""
        }
        return (values[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    /// Mirrors the Android app's BuildConfig.TEST_USER_ID, which it fed to NewRelic.setUserId so
    /// sessions could be found by user in session replay.
    private static let fallbackUserID = "expenses-tracker-ios-test-user"

    enum Mode: String {
        case capture
        case live
    }

    static var applicationToken: String {
        let fromEnvironment = ProcessInfo.processInfo.environment["NR_APP_TOKEN"] ?? ""
        return fromEnvironment.isEmpty ? fallbackApplicationToken : fromEnvironment
    }

    static var userID: String {
        let fromEnvironment = ProcessInfo.processInfo.environment["NR_USER_ID"] ?? ""
        return fromEnvironment.isEmpty ? fallbackUserID : fromEnvironment
    }

    static var mode: Mode {
        if let raw = ProcessInfo.processInfo.environment["NR_MODE"],
           let explicit = Mode(rawValue: raw.lowercased()) {
            return explicit
        }
        return applicationToken.isEmpty ? .capture : .live
    }

    // MARK: - Startup

    static func start() {
        NRLogger.setLogLevels(NRLogLevelDebug.rawValue)

        enableFeatures()

        // Harvest often, so events reach the collector while you are still looking at the screen that
        // produced them. The agent's defaults are 1000 events / 600s.
        NewRelic.setMaxEventBufferTime(30)
        NewRelic.setMaxEventPoolSize(2000)

        switch mode {
        case .capture:
            NRCollectorStub.shared.start()
            // Must be the literal "localhost:8080" — that exact string is what makes the agent drop
            // to plain HTTP. See NRCollectorStub.
            let address = NRCollectorStub.address
            NewRelic.start(withApplicationToken: "APP-TOKEN-EXPENSESTRACKER-CAPTURE",
                           andCollectorAddress: address,
                           andCrashCollectorAddress: address)
            appLog("""
            [ExpensesTracker] Agent started in CAPTURE mode → \(address)
                              Harvested events will be printed here.
            """)

        case .live:
            NewRelic.start(withApplicationToken: applicationToken,
                           andCollectorAddress: collectorAddress,
                           andCrashCollectorAddress: crashCollectorAddress)
            appLog("""
            [ExpensesTracker] Agent started in LIVE mode → \(collectorAddress)
                              Query with:  SELECT * FROM MobileView SINCE 30 MINUTES AGO
            """)
        }

        recordStartupContext()
    }

    /// The Android app's onCreate did four things after starting the agent: logged device
    /// attributes, logged an info line, set a user id, and opened and immediately closed an
    /// interaction named after the screen. All four are reproduced here.
    private static func recordStartupContext() {
        let device = UIDevice.current
        NewRelic.logAttributes([
            "device_model": deviceModelIdentifier(),
            "device_name": device.name,
            "ios_version": device.systemVersion
        ])
        NewRelic.logInfo("New Relic initialized with device info logged")

        NewRelic.setUserId(userID)

        // Android: String id = NewRelic.startInteraction("MainActivity"); NewRelic.endInteraction(id);
        // The iOS equivalent pair is startInteractionWithName/stopCurrentInteraction. It is as
        // degenerate here as it was there — an interaction that ends immediately — but it exercises
        // the same API and produces the same shape of data.
        let interactionID = NewRelic.startInteraction(withName: ViewName.login.rawValue)
        NewRelic.stopCurrentInteraction(interactionID)
    }

    /// "iPhone17,3" style identifier — the closest analogue to Android's Build.MODEL, which the
    /// Android app reported as `device_model`. UIDevice.model only ever says "iPhone".
    private static func deviceModelIdentifier() -> String {
        var info = utsname()
        uname(&info)
        return withUnsafePointer(to: &info.machine) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
    }

    /// MobileViews is the feature this branch adds, and both of its flags are off by default in the
    /// agent, so the app has to ask for them. The Android app has no equivalent — this is the part
    /// of the port that is deliberately more than a translation.
    ///
    /// LogReporting is asked for too: the Android app leans on NewRelic.logInfo/logDebug/logAttributes
    /// throughout, and on iOS those only ship anywhere with this flag on.
    private static func enableFeatures() {
        NewRelic.enableFeatures([
            NRMAFeatureFlags.NRFeatureFlag_NewEventSystem,
            NRMAFeatureFlags.NRFeatureFlag_LogReporting,

            // Automatic UIKit + SwiftUI view tracking. Gates every .NRMobile* modifier and the
            // automatic view events for the UIKit half of the app.
            NRMAFeatureFlags.NRFeatureFlag_AutomaticMobileViews,
            // NewRelic.setCurrentView(_:attributes:), used by the three Home tabs, which are
            // container children the automatic instrumentation would otherwise all attribute to
            // HomeViewController.
            NRMAFeatureFlags.NRFeatureFlag_ManualMobileViews,
            NRMAFeatureFlags.NRFeatureFlag_AutomaticSwiftUIViews
        ])
    }
}
