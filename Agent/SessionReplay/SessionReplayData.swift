//
//  SessionReplayUpload.swift
//  Agent
//
//  Created by Mike Bruin on 5/28/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

class SessionReplayData {
    var sessionReplayFramesData: Data
    let url: URL
    
    init (sessionReplayFramesData: Data, url: URL) {
        self.sessionReplayFramesData = sessionReplayFramesData
        self.url = url
    }
}
