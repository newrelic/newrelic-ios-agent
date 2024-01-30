//
//  CocoapodsExampleApp.swift
//  CocoapodsExample
//
//  Created by Chris Dillard on 9/20/23.
//

import SwiftUI

@main
struct CocoapodsExampleApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
