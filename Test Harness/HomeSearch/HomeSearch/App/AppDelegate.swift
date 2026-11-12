//
//  AppDelegate.swift
//  HomeSearch
//
//  The app is otherwise pure SwiftUI; this exists only to start the agent at the point the agent
//  documents — application(_:didFinishLaunchingWithOptions:). Starting from
//  `HomeSearchApp.init()` would run before the app finishes launching, and this app's whole job is
//  reporting faithfully on what the agent recorded, so it should not introduce a startup-ordering
//  question of its own. `examples/spm/SPMExample` uses the same @UIApplicationDelegateAdaptor shape.
//

import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Serve the fixture before the agent starts, so the first request the agent sees is a real
        // one from the Search screen rather than a connection failure.
        ListingStubServer.shared.start()

        NewRelicConfig.start()

        return true
    }
}
