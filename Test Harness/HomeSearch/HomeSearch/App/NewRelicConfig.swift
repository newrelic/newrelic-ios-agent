//
//  NewRelicConfig.swift
//  HomeSearch
//
//  Agent startup and MobileViews feature-flag enablement, in one place.
//
//  Two modes:
//
//    capture — the agent reports to NRCollectorStub on localhost, which prints every MobileView
//              event from each harvest to the console. Fast feedback, no account needed. Default.
//
//    live    — the agent reports to the real collector using your application token, so the data can
//              be queried with NRQL. Set the token with the NR_APP_TOKEN environment variable in the
//              scheme (Product ▸ Scheme ▸ Edit Scheme ▸ Run ▸ Arguments ▸ Environment Variables), or
//              fall back to editing `fallbackApplicationToken` below.
//
//  Choose with NR_MODE=capture|live. With no NR_MODE set, live is used when a token is available and
//  capture otherwise, so a fresh clone does something useful without configuration.
//
//  Both MobileViews flags default to OFF in the agent and are enabled here — automatic tracking for
//  the SwiftUI modifiers, manual tracking for NewRelic.setCurrentView on the Saved tab.
//

import Foundation
import NewRelic

enum NewRelicConfig {

    /// Used when NR_APP_TOKEN is not set in the environment. Replace to run in live mode without
    /// editing the scheme.

    enum Mode: String {
        case capture
        case live
    }

    static var applicationToken: String {
        let fromEnvironment = ProcessInfo.processInfo.environment["NR_APP_TOKEN"] ?? ""
        return fromEnvironment.isEmpty ? fallbackApplicationToken : fromEnvironment
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

        enableMobileViews()

        // Harvest often so MobileView events reach the collector while you are still looking at the
        // screen that produced them. The agent's default buffer is 1000 events / 600s.
        NewRelic.setMaxEventBufferTime(30)
        NewRelic.setMaxEventPoolSize(2000)
        
        switch mode {
        case .capture:
            NRCollectorStub.shared.start()
            // Must be the literal "localhost:8080" — that exact string is what makes the agent drop
            // to plain HTTP. See NRCollectorStub.
            let address = NRCollectorStub.address
            NewRelic.start(withApplicationToken: "APP-TOKEN-HOMESEARCH-CAPTURE",
                           andCollectorAddress: address,
                           andCrashCollectorAddress: address)
            appLog("""
            [HomeSearch] Agent started in CAPTURE mode → \(address)
                         MobileView events will be printed here on every harvest.
            """)

        case .live:
            // NewRelic.start(withApplicationToken: applicationToken)

             NewRelic.start(withApplicationToken: applicationToken,
                            andCollectorAddress: "staging-mobile-collector.newrelic.com",
                            andCrashCollectorAddress: "staging-mobile-crash.newrelic.com")
            appLog("""
            [HomeSearch] Agent started in LIVE mode.
                         Query with:  SELECT * FROM MobileView SINCE 30 MINUTES AGO
            """)
        }
    }

    /// Both flags are disabled by default in the agent, so the app has to ask for them.
    private static func enableMobileViews() {
        NewRelic.enableFeatures([
            NRMAFeatureFlags.NRFeatureFlag_NewEventSystem,

            // Automatic UIKit + SwiftUI view tracking. Gates every .NRMobileView* modifier.
            NRMAFeatureFlags.NRFeatureFlag_AutomaticMobileViews,
            // The manual NewRelic.setCurrentView(_:attributes:) API, used by the Saved tab.
            NRMAFeatureFlags.NRFeatureFlag_ManualMobileViews
        ])
    }
}
