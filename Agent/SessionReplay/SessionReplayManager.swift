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
    private let sessionReplayReporter: SessionReplayReporter
    
    public var harvestPeriod: Int64 = 60
    public var harvestTimer: Timer?
        
    public var isFirstChunck = true

    @objc public init(reporter: SessionReplayReporter) {
        self.sessionReplay = NRMASessionReplay()
        self.sessionReplayReporter = reporter
        super.init()
        
    }

    public func start() {
        sessionReplay.start()
        guard !isRunning() else {
            NRLOG_WARNING("Session replay harvest timer attempting to start while already running.")
            return
        }

        NRLOG_DEBUG("Session replay harvest timer starting with a period of \(harvestPeriod) ms")

        self.harvestTimer = Timer(timeInterval: TimeInterval(self.harvestPeriod), target: self, selector: #selector(self.harvest), userInfo: nil, repeats: true)

        RunLoop.current.add(self.harvestTimer!, forMode: .default)
    }
    
    public func stop() {
        sessionReplay.stop()
        guard isRunning() else {
            NRLOG_WARNING("Session replay harvest timer attempting to stop when not running.")
            return
        }
        
        harvestTimer?.invalidate()
        harvestTimer = nil
    }

    func isRunning() -> Bool {
        return self.harvestTimer != nil && self.harvestTimer!.isValid
    }

    @objc public func harvest() {
        guard let url = sessionReplayReporter.uploadURL(isFirstChunk: true) else {
            return
        }
        Task {
            // Fetch processed frames and processed touches concurrently
            let processedFrames = sessionReplay.getSessionReplayFrames()
            let processedTouches = sessionReplay.getSessionReplayTouches()
            
            // Create meta event data
            let metaEventData = await RRWebMetaData(
                href: "http://newrelic.com",
                width: Int(getWindow()?.frame.width ?? 0),
                height: Int(getWindow()?.frame.height ?? 0)
            )
            let metaEvent = MetaEvent(timestamp: TimeInterval(Date().timeIntervalSince1970 * 1000), data: metaEventData)

            // Initialize container with meta event
            var container: [AnyRRWebEvent] = [AnyRRWebEvent(metaEvent)]
            
            // Process frames and touches
            container.append(contentsOf: (processedFrames).map {
                AnyRRWebEvent($0)
            })
            container.append(contentsOf: (processedTouches).map {
                AnyRRWebEvent($0)
            })
            
            // Encode container to JSON
            let encoder = JSONEncoder ()
            encoder.outputFormatting = .withoutEscapingSlashes

            if let jsonData = try? encoder.encode(container),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                NRLOG_DEBUG(jsonString)
                sessionReplayReporter.enqueueSessionReplayUpload(upload: SessionReplayData.init(sessionReplayFramesData: jsonData, url: url))
            }
        }
    }
    
    // maybe move this into something else?
    @MainActor
    private func getWindow() -> UIWindow? {
        UIApplication
            .shared
            .connectedScenes
            .compactMap {$0 as? UIWindowScene}
            .flatMap { $0.windows }
            .last { $0.isKeyWindow }
    }
}
