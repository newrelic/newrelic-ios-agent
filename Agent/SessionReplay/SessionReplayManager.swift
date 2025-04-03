//
//  SessionReplayManager.swift
//  Agent_iOS
//
//  Created by Mike Bruin on 3/26/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation 
//import NewRelicPrivate

@available(iOS 13.0, *)
@objcMembers
public class SessionReplayManager: NSObject {
    
    private let sessionReplay: NRMASessionReplay
    private var sessionReplayReporter: SessionReplayReporter
    private var thread: Thread!
    
    public var harvestPeriod: Int64 = 60 * 1000 // milliseconds
    public var harvestTimer: Timer!
    
    @objc public init(agentVersion: String, sessionId: String) {
        self.sessionReplay = NRMASessionReplay()
        self.sessionReplayReporter = SessionReplayReporter(agentVersion: agentVersion, sessionId: sessionId)
        super.init()
        
        self.sessionReplay.delegate = self
    }
    
    public func setSessionId(_ sessionID: String) {
        self.sessionReplayReporter.sessionId = sessionID
    }

    public func start() {
        if isRunning() {
            print("Session replay harvest timer attempting to start while already running.")
            return
        }

        print("Session replay harvest timer starting with a period of \(harvestPeriod) ms")
        thread = Thread { [self] in
            self.harvestTimer = Timer(timeInterval: TimeInterval(harvestPeriod) / 1000.0, target: self, selector: #selector(harvest), userInfo: nil, repeats: true)

            RunLoop.current.add(self.harvestTimer, forMode: .default)
            RunLoop.current.run()
        }
        thread.start()
    }
    
   public func stop() {
        sessionReplay.stop()
        if (!isRunning()) {
            print("Session replay harvest timer attempting to stop when not running.")
            return;
        }
        
       self.harvestTimer.invalidate()
       self.harvestTimer = nil
    }

    func isRunning() -> Bool {
        return self.harvestTimer != nil && self.harvestTimer!.isValid
    }

    @objc public func harvest() {
        DispatchQueue.global(qos: .default).async {
            do {
                let sessionReplayData = try self.sessionReplay.getSessionReplayJSONData()
                self.sessionReplayReporter.enqueueSessionReplayUpload(sessionReplayFramesData: sessionReplayData!)
            } catch {
                print("Error fetching session replay JSON data: \(error)")
            }
        }
    }
}

@available(iOS 13.0, *)
extension SessionReplayManager: NRMASessionReplayDelegate {
    func didReachDataSizeLimit() {
        harvest()
    }
}
