//
//  AppDelegate.swift
//  NRTestApp
//
//  Created by Mike Bruin on 1/11/23.
//

import UIKit
import NewRelic

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
#if DEBUG
        NRLogger.setLogLevels(NRLogLevelVerbose.rawValue)
#endif
        
        // To enable or disable  feature flags in New Relic iOS Agent.
#if DISABLE_FEATURES
        NewRelic.disableFeatures([
            NRMAFeatureFlags.NRFeatureFlag_CrashReporting,
            NRMAFeatureFlags.NRFeatureFlag_WebViewInstrumentation
        ])
#endif
#if Enable_SWIFT_INTERACTION_TRACING
        NewRelic.enableFeatures([
            NRMAFeatureFlags.NRFeatureFlag_SwiftInteractionTracing,
        ])
#endif
        
        NewRelic.start(withApplicationToken:"TEST-TOKEN")
        
        // These must be called after Agent.start() aka NewRelic.start(withApplicationToken)
        NewRelic.setMaxEventPoolSize(5000)
        NewRelic.setMaxEventBufferTime(60)
        
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


}

