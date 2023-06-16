//
//  iOSAgentCatalystTestApp.swift
//  iOSAgentCatalystTest
//
//  Created by Chris Dillard on 6/15/23.
//

import SwiftUI
import NewRelic

@main
struct iOSAgentCatalystTestApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        NRLogger.setLogLevels(NRLogLevelVerbose.rawValue)

        NewRelic.start(withApplicationToken: "TOKEN", andCollectorAddress: "staging-mobile-crash.newrelic.com", andCrashCollectorAddress: "staging-mobile-collector.newrelic.com")
        return true
    }
}
