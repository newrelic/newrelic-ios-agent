//
//  SessionReplayManager.swift
//  Agent_iOS
//
//  Created by Mike Bruin on 3/26/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation
import UIKit

@available(iOS 13.0, *)
@objcMembers
public class SessionReplayManager: NSObject {
    
    private let sessionReplay: NRMASessionReplay
    private var sessionReplayReporter: SessionReplayReporter
    
    public var harvestPeriod: Int64 = 60 * 1000 // milliseconds
    public var harvestTimer: Timer?
    
    private let sessionReplayFrameProcessor = SessionReplayFrameProcessor()
    
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
        sessionReplay.start()
        guard !isRunning() else {
            print("Session replay harvest timer attempting to start while already running.")
            return
        }

        print("Session replay harvest timer starting with a period of \(harvestPeriod) ms")

        self.harvestTimer = Timer(timeInterval: TimeInterval(self.harvestPeriod) / 1000.0, target: self, selector: #selector(self.harvest), userInfo: nil, repeats: true)

        RunLoop.current.add(self.harvestTimer!, forMode: .default)
        RunLoop.current.run()
    }
    
    public func stop() {
        sessionReplay.stop()
        guard isRunning() else {
            print("Session replay harvest timer attempting to stop when not running.")
            return
        }
        
        harvestTimer?.invalidate()
        harvestTimer = nil
    }

    func isRunning() -> Bool {
        return self.harvestTimer != nil && self.harvestTimer!.isValid
    }

    @objc public func harvest() {
            let rawFrames = self.sessionReplay.getSessionReplayFrames()
            let metaEventData = RRWebMetaData(href: "http://newrelic.com", width: Int(getWindow()?.frame.width ?? 0), height: Int(getWindow()?.frame.height ?? 0))
            let metaEvent = MetaEvent(timestamp: Date().timeIntervalSince1970 * 1000, data: metaEventData)
            var container: [AnyRRWebEvent] = [AnyRRWebEvent(metaEvent)]
            
            container.append(contentsOf: rawFrames.map {
                AnyRRWebEvent(self.sessionReplayFrameProcessor.processFrame($0))
                
            })
        
            let processedTouches = sessionReplay.getSessionReplayTouches()
            container.append(contentsOf: processedTouches.map { AnyRRWebEvent($0)})
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = []
            let jsonData = try? encoder.encode(container)
            
            if let data = jsonData,
               let jsonString = String(data: data, encoding: .utf8){
                NSLog(jsonString)
                sessionReplayReporter.enqueueSessionReplayUpload(sessionReplayFramesData: data)
                
            }
    }
    
   /* func checkCompressedDataSize(frame: SessionReplayFrame) {
        guard let self = self else { return }
        
        // Check the size of compressed data
        guard let jsonData = self.currentFramesData().gzipped() else {
            return
        }
        
        guard let newFrameJSONData = try? JSONSerialization.data(withJSONObject: self.sessionReplayFrameProcessor.processFrame(frame), options: []) else {
            return
        }
        
        let sizeInBytes = jsonData.count + newFrameJSONData.count
        let sizeInMB = Double(sizeInBytes) / (1024.0 * 1024.0)
        print(sizeInMB)
        
        if sizeInMB >= 1.0 {
            self.delegate?.didReachDataSizeLimit()
        }
        
        self.processedFrames.add(self.sessionReplayFrameProcessor.processFrame(frame))
    }*/
    
    // maybe move this into something else?
    private func getWindow() -> UIWindow? {
        UIApplication
            .shared
            .connectedScenes
            .compactMap {$0 as? UIWindowScene}
            .flatMap { $0.windows }
            .last { $0.isKeyWindow }
    }
}

@available(iOS 13.0, *)
extension SessionReplayManager: NRMASessionReplayDelegate {
    func didReachDataSizeLimit() {
        harvest()
    }
}
