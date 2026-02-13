//
//  NewRelicSDK.swift
//  ManulifeMobile
//
//  Created by Jean-Francois Leblanc on 2023-08-29.
//

import NewRelic

class NewRelicSDK : NSObject {
    
    // MARK: - Initializer
    static var shared = NewRelicSDK()
    
    func setup(
        newRelicApplicationToken: String)
    {
        /// NewRelic
        
        NewRelic.enableFeatures(NRMAFeatureFlags.NRFeatureFlag_NetworkRequestEvents)
        NewRelic.start(withApplicationToken: newRelicApplicationToken)
        NewRelic.setUserId("SessionRecordingTest")
    }
}
