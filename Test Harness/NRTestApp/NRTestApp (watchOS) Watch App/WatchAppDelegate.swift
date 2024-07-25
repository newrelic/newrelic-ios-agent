//
//  WatchAppDelegate.swift
//  NRTestApp (watchOS) Watch App
//
//  Created by Mike Bruin on 4/26/24.
//

import WatchKit
import NewRelic

class WatchAppDelegate: NSObject, WKApplicationDelegate {
    
    func applicationDidFinishLaunching() {
#if DEBUG
        // The New Relic agent is set to log at NRLogLevelInfo by default, debug logging should only be used for debugging when all agent logs are desired.
        NRLogger.setLogLevels(NRLogLevelDebug.rawValue)
#endif

        NewRelic.addHTTPHeaderTracking(for: ["Test"])
        NewRelic.enableFeatures([NRMAFeatureFlags.NRFeatureFlag_SwiftAsyncURLSessionSupport,
                                 NRMAFeatureFlags.NRFeatureFlag_OfflineStorage])

        NewRelic.replaceDeviceIdentifier("myDeviceId")

        NewRelic.setMaxEventBufferTime(60)

        // Generate your own api key to see data get sent to your app's New Relic web services.
        guard let apiKey = plistHelper.objectFor(key: "NRAPIKey", plist: "NRAPI-Info") as? String else {return}

        // Changing the collector and crash collector addresses is not necessary to use New Relic production servers.
        guard let collectorAddress = plistHelper.objectFor(key: "collectorAddress", plist: "NRAPI-Info") as? String, let crashCollectorAddress = plistHelper.objectFor(key: "crashCollectorAddress", plist: "NRAPI-Info") as? String else {return}

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

        NewRelic.setMaxEventPoolSize(5000)
        NewRelic.setMaxEventBufferTime(60)

        NewRelic.logVerbose("NewRelic.start was called.")
    }

}
