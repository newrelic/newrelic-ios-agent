//
//  AppDelegate.swift
//  SessionReplayTest
//
//  Created by Steve Malsam on 4/12/24.
//

import UIKit

import NewRelic


@main
class AppDelegate: UIResponder, UIApplicationDelegate {



    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
//#if DEBUG
        // The New Relic agent is set to log at NRLogLevelInfo by default, verbose logging should only be used for debugging.
        NRLogger.setLogLevels(NRLogLevelAudit.rawValue)
//#endif
        NewRelic.enableFeatures([.NRFeatureFlag_NewEventSystem, .NRFeatureFlag_GestureInstrumentation])
//        NewRelic.start(withApplicationToken:"AA49a8e151d4e77acbeb11b04f1d5e0fd57d805a77-NRMA")
        NewRelic.start(withApplicationToken:"AA49a8e151d4e77acbeb11b04f1d5e0fd57d805a77-NRMA",
                       andCollectorAddress: "staging-mobile-collector.newrelic.com",
                       andCrashCollectorAddress: "staging-mobile-crash.newrelic.com")
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

