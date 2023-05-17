//
//  plistHelper.swift
//  NRTestApp
//
//  Created by Mike Bruin on 1/17/23.
//

import Foundation

// Generate your own api key to see data get sent to your app's New Relic web services. Also be sure to put your key in the `Run New Relic dSYM Upload Tool` build phase.
var apiKey: String! {
    get {
        return plistHelper.objectFor(key: "NRAPIKey", plist: "NRAPI-Info") as? String
    }
}

// Changing the collector and crash collector addresses is not necessary to use New Relic production servers.
var collectorAddress: String! {
    get {
        return plistHelper.objectFor(key: "collectorAddress", plist: "NRAPI-Info") as? String
    }
}

var crashCollectorAddress: String! {
    get {
        return plistHelper.objectFor(key: "crashCollectorAddress", plist: "NRAPI-Info") as? String
    }
}

class plistHelper {
    
    static func objectFor(key: String, plist: String) -> Any? {
        if let plistPath = Bundle.main.url(forResource: plist, withExtension: ".plist") {
            do {
                let plistData = try Data(contentsOf: plistPath)
                if let dict = try PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] {
                    return dict[key]
                }
            } catch {
                print(error)
            }
        }
        return nil
    }
}
