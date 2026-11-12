//
//  AppDelegate.swift
//  ExpensesTracker
//
//  Launch-time wiring, in the order it has to happen.
//
//  The Android app started the agent from MainActivity.onCreate, which meant the agent came up after
//  the first screen already existed. iOS documents application(_:didFinishLaunchingWithOptions:) as
//  the place to start, and that is also strictly better for this app: the splash screen and login
//  screen are then themselves instrumented, which on Android they were not.
//
//  The stub server starts before the agent so the first request the agent instruments is a real
//  ledger fetch rather than a connection failure.
//

import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        LedgerStubServer.shared.start()

        NewRelicConfig.start()

        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration",
                             sessionRole: connectingSceneSession.role)
    }
}
