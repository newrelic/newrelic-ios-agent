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
        DispatchQueue.global(qos: .background).async { [self] in
            sessionReplay.start()
            guard !isRunning() else {
                NRLOG_WARNING("Session replay harvest timer attempting to start while already running.")
                return
            }
            isFirstChunck = true
            
            NRLOG_DEBUG("Session replay harvest timer starting with a period of \(harvestPeriod) s")
            self.harvestTimer = Timer(timeInterval: TimeInterval(self.harvestPeriod), target: self, selector: #selector(self.harvestTick), userInfo: nil, repeats: true)
            
            RunLoop.current.add(self.harvestTimer!, forMode: .default)
            RunLoop.current.run()
        }
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
    
    // This function is to handle a session change created by a change in userId
    @objc public func newSession() {
        stop()
        harvest()
        start()
    }
    
    @objc func harvestTick() {
        NRLOG_DEBUG("Session replay harvest timer firing.")
        harvest()
    }

    @objc public func harvest() {
        // Fetch processed frames and touches
        let processedFrames = sessionReplay.getSessionReplayFrames()
        let processedTouches = sessionReplay.getSessionReplayTouches()

        // Early exit if nothing to send
        if processedFrames.isEmpty && processedTouches.isEmpty {
            NRLOG_WARNING("No session replay frames or touches to harvest.")
            return
        }

        let firstTimestamp: TimeInterval = TimeInterval(processedFrames.first?.timestamp ?? 0)
        let lastTimestamp: TimeInterval = TimeInterval(processedFrames.last?.timestamp ?? 0)

        // Create meta event data
        let metaEventData = RRWebMetaData(
            href: "http://newrelic.com",
            width: Int(sessionReplay.windowDimensions.width),
            height: Int(sessionReplay.windowDimensions.height)
        )
        let metaEvent = MetaEvent(timestamp: TimeInterval(firstTimestamp), data: metaEventData)

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
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes

        do {
            let jsonData = try encoder.encode(container)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                NRLOG_DEBUG(jsonString)
            }
            guard let url = sessionReplayReporter.uploadURL(
                uncompressedDataSize: jsonData.count,
                firstTimestamp: firstTimestamp,
                lastTimestamp: lastTimestamp,
                isFirstChunk: isFirstChunck
            ) else {
                NRLOG_ERROR("Failed to construct upload URL for session replay.")
                return
            }
            sessionReplayReporter.enqueueSessionReplayUpload(upload: SessionReplayData(sessionReplayFramesData: jsonData, url: url))
            isFirstChunck = false
        } catch {
            NRLOG_ERROR("Failed to encode session replay events: \(error)")
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
