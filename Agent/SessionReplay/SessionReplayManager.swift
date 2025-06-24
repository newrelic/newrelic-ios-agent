//
//  SessionReplayManager.swift
//  Agent_iOS
//
//  Created by Mike Bruin on 3/26/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation
import UIKit
@_implementationOnly import NewRelicPrivate

@available(iOS 13.0, *)
@objcMembers
public class SessionReplayManager: NSObject {
    
    private let sessionReplay: NRMASessionReplay
    private let sessionReplayReporter: SessionReplayReporter
    
    public var harvestPeriod: Int64 = 60
    public var harvestTimer: Timer?
        
    public var isFirstChunk = true

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
            isFirstChunk = true
            
            NewRelicAgentInternal.sharedInstance().analyticsController.setNRSessionAttribute(kNRMA_RA_hasReplay, value: NRMABool(bool: true))

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
        
        NewRelicAgentInternal.sharedInstance().analyticsController.removeSessionAttributeNamed(kNRMA_RA_hasReplay)
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
        
        guard let upload = createReplayUpload(container: container, firstTimestamp: firstTimestamp, lastTimestamp: lastTimestamp) else {
            return
        }
        sessionReplayReporter.enqueueSessionReplayUpload(upload: upload)
        isFirstChunk = false

    }
    
    func createReplayUpload(container: [AnyRRWebEvent], firstTimestamp: TimeInterval, lastTimestamp: TimeInterval) -> SessionReplayData? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes

        // Encode container to JSON
        var jsonData: Data
        do {
            jsonData = try encoder.encode(container)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                NRLOG_DEBUG(jsonString)
            }
        } catch {
            NRLOG_ERROR("Failed to encode session replay events to JSON: \(error)")
            return nil
        }

        let uncompressedDataSize = jsonData.count

        do {
            let gzippedData = try jsonData.gzipped()
            jsonData = gzippedData
        } catch {
            NRLOG_WARNING("Failed to gzip session replay data: \(error.localizedDescription)")
        }

        // Construct upload URL
        guard let url = sessionReplayReporter.uploadURL(
            uncompressedDataSize: uncompressedDataSize,
            firstTimestamp: firstTimestamp,
            lastTimestamp: lastTimestamp,
            isFirstChunk: isFirstChunk,
            isGZipped: jsonData.isGzipped
        ) else {
            NRLOG_ERROR("Failed to construct upload URL for session replay.")
            return nil
        }

        return SessionReplayData(sessionReplayFramesData: jsonData, url: url)
    }
}
