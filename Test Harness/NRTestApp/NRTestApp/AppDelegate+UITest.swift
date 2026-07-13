//
//  AppDelegate+UITest.swift
//  NRTestApp
//
//  Created by Chris Dillard on 10/20/23.
//

import Foundation

extension AppDelegate {
    /// When launched under UI tests (the `UITesting` launch-environment key is set), returns the
    /// host the agent should use for both the data and crash collectors — a local mock collector
    /// stubbed by the UI test (see NRTestAppUITests/HTTPDynamicStubs). Returns nil for normal
    /// launches so the agent uses its NRAPI-Info.plist / production endpoints.
    ///
    /// Honors two optional launch-environment keys:
    /// - `DeleteConnect`: clears persisted connect state so each test starts from a clean handshake.
    /// - `MockCollectorHost`: overrides the default `localhost:8080` host.
    var uiTestCollectorHost: String? {
        let environment = ProcessInfo.processInfo.environment
        guard environment["UITesting"] != nil else { return nil }

        if environment["DeleteConnect"] != nil {
            clearConnectUserDefaults()
        }

        return environment["MockCollectorHost"] ?? "localhost:8080"
    }

    func clearConnectUserDefaults() {
        UserDefaults.standard.removeObject(forKey: "com.newrelic.connectionInformation")
        UserDefaults.standard.removeObject(forKey: "com.newrelic.harvesterConfiguration")
        UserDefaults.standard.removeObject(forKey: "com.newrelic.applicationIdentifier")
        UserDefaults.standard.synchronize()
    }
}
