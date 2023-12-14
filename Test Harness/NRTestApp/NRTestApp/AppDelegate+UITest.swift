//
//  AppDelegate+UITest.swift
//  NRTestApp
//
//  Created by Chris Dillard on 10/20/23.
//

import Foundation

extension AppDelegate {
    func clearConnectUserDefaults() {
        UserDefaults.standard.removeObject(forKey: "com.newrelic.connectionInformation")
        UserDefaults.standard.removeObject(forKey: "com.newrelic.harvesterConfiguration")
        UserDefaults.standard.removeObject(forKey: "com.newrelic.applicationIdentifier")
        UserDefaults.standard.synchronize()
    }
}
