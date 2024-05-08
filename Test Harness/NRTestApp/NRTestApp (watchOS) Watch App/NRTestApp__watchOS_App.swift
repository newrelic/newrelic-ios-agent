//
//  NRTestApp__watchOS_App.swift
//  NRTestApp (watchOS) Watch App
//
//  Created by Mike Bruin on 4/29/24.
//

import SwiftUI

@main
struct NRTestApp__watchOS__Watch_AppApp: App {
    @WKApplicationDelegateAdaptor var appDelegate: WatchAppDelegate
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
