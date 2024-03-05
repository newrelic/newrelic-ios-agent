//
//  AppDelegate.swift
//  NRTestApp
//
//  Created by Mike Bruin on 1/11/23.
//

import UIKit
import NewRelic

// For more info on installing the New Relic agent go to https://docs.newrelic.com/docs/mobile-monitoring/new-relic-mobile-ios/installation/spm-installation/#configure-using-swift-package-manager

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
#if DEBUG
        // The New Relic agent is set to log at NRLogLevelInfo by default, verbose logging should only be used for debugging.
        NRLogger.setLogLevels(NRLogLevelVerbose.rawValue)
#endif

        // To enable or disable feature flags in New Relic iOS Agent.
#if DISABLE_FEATURES
        NewRelic.disableFeatures([
            NRMAFeatureFlags.NRFeatureFlag_CrashReporting,
            NRMAFeatureFlags.NRFeatureFlag_WebViewInstrumentation
        ])
#endif
#if Enable_SWIFT_INTERACTION_TRACING
        NewRelic.enableFeatures(NRMAFeatureFlags.NRFeatureFlag_SwiftInteractionTracing)
#endif
        NewRelic.addHTTPHeaderTracking(for: ["Test"])
        NewRelic.enableFeatures([NRMAFeatureFlags.NRFeatureFlag_SwiftAsyncURLSessionSupport,
                                 NRMAFeatureFlags.NRFeatureFlag_NewEventSystem,
                                 NRMAFeatureFlags.NRFeatureFlag_OfflineStorage])

        NewRelic.enableFeatures([NRMAFeatureFlags.NRFeatureFlag_BackgroundInstrumentation])

        NewRelic.replaceDeviceIdentifier("myDeviceId")

        NewRelic.setMaxEventPoolSize(5000)
        NewRelic.setMaxEventBufferTime(60)

        if ProcessInfo.processInfo.environment["UITesting"] != nil {
            if ProcessInfo.processInfo.environment["DeleteConnect"] != nil {
                clearConnectUserDefaults()
            }

            NewRelic.start(withApplicationToken: "APP-TOKEN-NRMA",
                           andCollectorAddress: "localhost:8080",
                           andCrashCollectorAddress: "localhost:8080")
        }
        else {
            // Generate your own api key to see data get sent to your app's New Relic web services. Also be sure to put your key in the `Run New Relic dSYM Upload Tool` build phase.
            guard let apiKey = plistHelper.objectFor(key: "NRAPIKey", plist: "NRAPI-Info") as? String else {return true}

            // Changing the collector and crash collector addresses is not necessary to use New Relic production servers.
            guard let collectorAddress = plistHelper.objectFor(key: "collectorAddress", plist: "NRAPI-Info") as? String, let crashCollectorAddress = plistHelper.objectFor(key: "crashCollectorAddress", plist: "NRAPI-Info") as? String else { return true }

            // If the entries for collectorAddress or crashCollectorAddress are empty in NRAPI-Info.plist, start the New Relic agent with default production endpoints.
            if collectorAddress.isEmpty || crashCollectorAddress.isEmpty {
                // Start the agent using default endpoints.
                NewRelic.start(withApplicationToken:apiKey)
            } else {
                // Start the agent with custom endpoints.
                NewRelic.start(withApplicationToken:apiKey,
                               andCollectorAddress: collectorAddress,
                               andCrashCollectorAddress: crashCollectorAddress)
            }
        }

        NewRelic.setMaxEventPoolSize(5000)
        NewRelic.setMaxEventBufferTime(60)

        NewRelic.logVerbose("NewRelic.start was called.")
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }


    // Background fetch handling\

    // TODO: Must add this and then we will capture in NewRelicAgentInternal
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {

        NewRelic.logVerbose("performFetchWithCompletionHandler called")
        completionHandler(.newData)
    }
}
