//
//  NRMASessionReplay.swift
//  Agent_iOS
//
//  Created by Steve Malsam on 1/30/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation

@objcMembers
public class NRMASessionReplay: NSObject {
    
    let sessionReplayCapture: SessionReplayCapture
    
    public override init() {
        self.sessionReplayCapture = SessionReplayCapture()
    }
}
