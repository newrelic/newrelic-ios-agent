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
    
#if os(iOS) || os(tvOS)
    
    private let sessionReplay: NRMASessionReplay
    private let sessionReplayReporter: SessionReplayReporter
    
    public var harvestPeriod: Int64 = 60
    private var harvestseconds = 0
    public var sessionReplayTimer: Timer?
    
    private let url: NSString
    
    private let sessionReplayQueue = DispatchQueue(label: "com.newrelic.sessionReplayQueue", attributes: .concurrent)
    private static let queueKey = DispatchSpecificKey<String>()
    
    private var isManuallyRecording: Bool = false
    
    
    // TWO SESSION REPLAY MODEs
    public var sessionReplayMode: SessionReplayRecordingMode = .off {
        didSet {
            sessionReplay.recordingMode = sessionReplayMode
        }
    }
    
    @objc public init(reporter: SessionReplayReporter, url: NSString) {
        self.url = url
        self.sessionReplay = NRMASessionReplay(url: self.url)
        self.sessionReplayReporter = reporter
        sessionReplayQueue.setSpecific(key: SessionReplayManager.queueKey, value: "com.newrelic.sessionReplayQueue")
        super.init()
        
        self.sessionReplay.delegate = self
        self.sessionReplayMode = .off
    }
    
    // ERROR MODE
    
    // MARK: - Error Sampling Mode Management
    
    /// Sets the recording mode for session replay
    /// - Parameter mode: The recording mode to use
    @objc public func setRecordingMode(_ mode: SessionReplayRecordingMode) {
        sessionReplayQueue.async { [self] in
            self.sessionReplayMode = mode
            sessionReplay.transistionToRecordingMode(mode)
        }
    }
    
    /// Gets the current recording mode
    /// - Returns: The current recording mode
    @objc public func getCurrentRecordingMode() -> SessionReplayRecordingMode {
        return sessionReplay.recordingMode
    }
    
    /// Transitions from error mode to full mode, including the 15-second buffer
    @objc public func onError(_ error: Error?) {
        sessionReplayQueue.async { [weak self] in
            guard let self = self else { return }
            
            if self.sessionReplayMode == .error {
                
                // ensure the buffered data is marked for upload.
                // The current implementation of processFrameToFile writes to disk.
                // If we switch to FULL, subsequent frames will just be written.
                // The currentMode update to .FULL will stop the pruning in processFrameToFile.
                self.sessionReplayMode = .full
                
                NRLOG_DEBUG("Error detected - transitioning session replay to full mode")
                sessionReplay.transitionToFullModeOnError()
            }
        }
    }
    
    @objc private func handleErrorNotification(_ notification: Notification) {
        onError(nil)
    }
    // END ERROR MODE
    
    public func start(fromManual: Bool = false, with newMode: SessionReplayRecordingMode) {
        sessionReplayQueue.async { [self] in
            
            
            // SESSION REPLAY ERRORED SESSION SAMPLING HANDLING
            
            self.setRecordingMode(newMode)
            
            // END SESSION REPLAY ERRORED SESSION SAMPLING HANDLING
            
            
            guard !isRunning() else {
                NRLOG_DEBUG("Session replay harvest timer attempting to start while already running.")
                return
            }
            
            sessionReplay.start()
            self.harvestseconds = 0
            
            self.isManuallyRecording = fromManual
            
            NRLOG_DEBUG("Session replay harvest timer starting with a period of \(harvestPeriod) s")
            self.sessionReplayTimer = Timer(timeInterval: 1.0, target: self, selector: #selector(self.sessionReplayTick), userInfo: nil, repeats: true)
            
            RunLoop.current.add(self.sessionReplayTimer!, forMode: .default)
            RunLoop.current.run()
        }
    }
    
    public func stop() {
        let stopBlock = { [self] in
            guard isRunning() else {
                NRLOG_DEBUG("Session replay harvest timer attempting to stop when not running.")
                return
            }
            
            sessionReplay.stop()
            sessionReplayTimer?.invalidate()
            sessionReplayTimer = nil
            
            NRLOG_DEBUG("Session replay has shut down and is no longer running.")
        }
        
        // If we're already on the sessionReplayQueue, execute immediately
        // Otherwise, sync to the queue
        if DispatchQueue.getSpecific(key: SessionReplayManager.queueKey) != nil {
            stopBlock()
        } else {
            sessionReplayQueue.sync(execute: stopBlock)
        }
    }
    
    @objc public func isRunning() -> Bool {
        return self.sessionReplayTimer != nil && self.sessionReplayTimer!.isValid
    }
    
    // This function is to handle a session change created by a change in userId
    @objc public func endSession(harvest: Bool = true) {
        stop()
        if harvest {
            self.harvest()
        }
        // Reset isManuallyRecording for new session
        isManuallyRecording = false
        
        // Reset the isFirstChunk for new session
        self.sessionReplay.isFirstChunk = true
    }
    
    @objc public func manualRecordReplay() -> Bool {
        return sessionReplayQueue.sync {
            
            if isRunning() {
                NRLOG_DEBUG("Attempted to manually start session replay but it is already recording")
                return false
            }
            
            start(fromManual: true, with: .full)
            
            NRLOG_DEBUG("Session replay started via manual recordReplay() API")
            return true
        }
    }
    
    @objc public func manualPauseReplay() -> Bool {
        return sessionReplayQueue.sync {
            
            isManuallyRecording = false
            
            if !isRunning() {
                NRLOG_DEBUG("Attempted to pause session replay but it is not currently recording")
                return false
            }
            
            stop()
            harvest()
            NRLOG_DEBUG("Session replay paused via manual pauseReplay() API")
            return true
        }
    }
    
    public func isManuallyActive() -> Bool {
        return sessionReplayQueue.sync { isManuallyRecording }
    }
    
    @objc public func clearAllData() {
        sessionReplayQueue.sync { [self] in
            sessionReplay.clearAllData()
        }
    }
    
    @objc func sessionReplayTick() {
        if isRunning() &&
            (NewRelicAgentInternal.sharedInstance() != nil &&
             NewRelicAgentInternal.sharedInstance()?.isSessionReplayEnabled() ?? false == false)
        {
            NRLOG_DEBUG("Session replay harvest timer stopping because New Relic agent is not started.")
            stop()
            return
        }
        
        harvestseconds += 1
        sessionReplay.takeFrame()
        
        if harvestseconds == harvestPeriod {
            harvest()
        }
    }
    
    @objc public func harvest() {
        // sync is required here or session replay upload fails.
        sessionReplayQueue.sync { [weak self] in
            guard let self = self else { return }
            
            self.harvestSessionReplayFramesAndTouches()
        }
    }
    
    private func harvestSessionReplayFramesAndTouches() {
        if sessionReplayMode == .error {
            NRLOG_DEBUG("Skipping harvest in ERROR mode.")
            return
        }
        
        let frames = self.sessionReplay.getSessionReplayFrames()
        let touches = self.sessionReplay.getSessionReplayTouches()
        
        if frames.isEmpty && touches.isEmpty {
            NRLOG_DEBUG("No session replay frames or touches to harvest.")
            return
        }
        
        var container: [AnyRRWebEvent] = frames.map(AnyRRWebEvent.init)
        container.append(contentsOf: touches.map(AnyRRWebEvent.init))
        container.sort { (lhs: AnyRRWebEvent, rhs: AnyRRWebEvent) -> Bool in
            lhs.base.timestamp < rhs.base.timestamp
        }
        
        let firstTimestamp = TimeInterval(container.first?.base.timestamp ?? 0)
        let lastTimestamp  = TimeInterval(container.last?.base.timestamp ?? 0)
        
        guard let upload = self.createReplayUpload(container: container,
                                                   firstTimestamp: firstTimestamp,
                                                   lastTimestamp: lastTimestamp) else {
            return
        }
        self.sessionReplayReporter.enqueueSessionReplayUpload(upload: upload)
        self.sessionReplay.isFirstChunk = false
        self.harvestseconds = 0
    }
    
    private func createReplayUpload(container: [AnyRRWebEvent], firstTimestamp: TimeInterval, lastTimestamp: TimeInterval) -> SessionReplayData? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes
        
        // Encode container to JSON
        var jsonData: Data
        do {
            jsonData = try encoder.encode(container)
            //            if let jsonString = String(data: jsonData, encoding: .utf8) {
            //                NRLOG_DEBUG(jsonString)
            //            }
        } catch {
            NRLOG_DEBUG("Failed to encode session replay events to JSON: \(error)")
            return nil
        }
        
        let uncompressedDataSize = jsonData.count
        
        do {
            let gzippedData = try jsonData.gzipped()
            jsonData = gzippedData
        } catch {
            NRLOG_DEBUG("Failed to gzip session replay data: \(error.localizedDescription)")
        }
        
        // Construct upload URL
        guard let url = sessionReplayReporter.uploadURL(
            uncompressedDataSize: uncompressedDataSize,
            firstTimestamp: firstTimestamp,
            lastTimestamp: lastTimestamp,
            isFirstChunk: self.sessionReplay.isFirstChunk,
            isGZipped: jsonData.isGzipped
        ) else {
            NRLOG_DEBUG("Failed to construct upload URL for session replay.")
            return nil
        }
        
        // NRLOG_DEBUG(url.absoluteString)
        
        return SessionReplayData(sessionReplayFramesData: jsonData, url: url)
    }
    
    // REPLAY PERSISTENCE
    
    public func checkForPreviousSessionFiles() {
        sessionReplayQueue.async { [self] in
            // CHECK FOR MSR DIRECTORIES FROM PREVIOUSLY CRASHED SESSIONS
            NRLOG_DEBUG("CHECK FOR MSR DIRECTORIES FROM PREVIOUSLY CRASHED SESSIONS")
            
            guard let sessionReplayDirectory = getSessionReplayDirectory() else {
                NRLOG_DEBUG("Could not access session replay directory")
                return
            }
            
            do {
                let fileURLs = try FileManager.default.contentsOfDirectory(at: sessionReplayDirectory, includingPropertiesForKeys: nil)
                
                // Extract unique session IDs from session replay files
                let sessionIds = Set(fileURLs.compactMap { fileURL -> String? in
                    let fileName = fileURL.lastPathComponent
                    if fileName.hasSuffix("_upload_url.txt") {
                        return fileName.replacingOccurrences(of: "_upload_url.txt", with: "")
                    }
                    return nil
                })
                NRLOG_DEBUG("MSR DIRECTORIES FOUND \(sessionIds)")
                
                // Process each session
                for sessionId in sessionIds {
                    processSessionReplayFile(sessionId: sessionId, directory: sessionReplayDirectory)
                }
                
            }
            catch {
                NRLOG_DEBUG("Failed to read session replay directory: \(error)")
            }
        }
    }
    
    private func processSessionReplayFile(sessionId: String, directory: URL) {
        let urlFile = directory.appendingPathComponent("\(sessionId)_upload_url.txt")
        
        do {
            NRLOG_DEBUG("Processing session replay for session ID: \(sessionId)")
            
            // BEGIN URL CONSTRUCTION
            
            guard let urlString = try? String(contentsOf: urlFile),
                  let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                NRLOG_DEBUG("No valid URL found for session replay file with session ID: \(sessionId)")
                return
            }
            //NRLOG_AGENT_DEBUG(url.absoluteString)
            
            // END URL CONSTRUCTION
            
            // BEGIN DATA CONSTRUCTION
            
            // Find all frame files for this session
            let sessionDirectory = directory.appendingPathComponent(sessionId)
            guard FileManager.default.fileExists(atPath: sessionDirectory.path) else {
                NRLOG_DEBUG("Session directory not found for session ID: \(sessionId)")
                return
            }
            
            let frameFiles = try FileManager.default.contentsOfDirectory(at: sessionDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "json" && $0.lastPathComponent.hasPrefix("frame_") }
                .sorted { (url1, url2) -> Bool in
                    let name1 = url1.deletingPathExtension().lastPathComponent
                    let name2 = url2.deletingPathExtension().lastPathComponent
                    
                    let number1 = Int(name1.replacingOccurrences(of: "frame_", with: "")) ?? 0
                    let number2 = Int(name2.replacingOccurrences(of: "frame_", with: "")) ?? 0
                    
                    return number1 < number2
                }
            
            if frameFiles.isEmpty {
                NRLOG_DEBUG("No frame files found for session ID: \(sessionId)")
                try? FileManager.default.removeItem(at: urlFile)
                try? FileManager.default.removeItem(at: sessionDirectory)
                return
            }
            
            // Read and combine all frame files, starting from the first full frame
            var frameContents: [String] = []
            var foundFirstFullFrame = false

            for frameFile in frameFiles {
                do {
                    // remove outer [] from frameFile if they exist
                    let frameContent = try String(contentsOf: frameFile).trimmingCharacters(in: .whitespacesAndNewlines)

                    var frameContentWithOuterBracketsRemoved = frameContent
                    if frameContent.hasPrefix("[") && frameContent.hasSuffix("]") {
                        frameContentWithOuterBracketsRemoved = String(frameContent.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
                    }

                    if !frameContentWithOuterBracketsRemoved.isEmpty {
                        // Check if this is a full frame (type = 2) if we haven't found one yet
                        if !foundFirstFullFrame {
                            // Parse the original content (with brackets) to check for full frames
                            if let data = frameContent.data(using: .utf8),
                               let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                                // Check if any frame in this file is a full snapshot (type = 2)
                                let hasFullFrame = jsonArray.contains { frame in
                                    if let type = frame["type"] as? Int {
                                        return type == 4 // meta OR fullSnapshot
                                    }
                                    return false
                                }

                                if hasFullFrame {
                                    foundFirstFullFrame = true
                                    frameContents.append(frameContentWithOuterBracketsRemoved)
                                } else {
                                    NRLOG_DEBUG("Skipping frame file \(frameFile.lastPathComponent) - no full snapshot found yet")
                                }
                            } else {
                                NRLOG_DEBUG("Failed to parse frame file \(frameFile.lastPathComponent) to check type")
                            }
                        } else {
                            // We've found a full frame, include all subsequent frames
                            frameContents.append(frameContentWithOuterBracketsRemoved)
                        }
                    }
                } catch {
                    NRLOG_DEBUG("Failed to read frame file \(frameFile.lastPathComponent): \(error)")
                }
            }
            
            if frameContents.isEmpty {
                if !foundFirstFullFrame {
                    NRLOG_DEBUG("No full snapshot frame found for session ID: \(sessionId)")
                } else {
                    NRLOG_DEBUG("No valid frame content found for session ID: \(sessionId)")
                }
                try FileManager.default.removeItem(at: sessionDirectory)
                try? FileManager.default.removeItem(at: urlFile)
                return
            }
            
            // Construct JSON array from frame contents
            
            let jsonArrayString = "[" + frameContents.joined(separator: ",") + "]"
            
            guard let jsonData = jsonArrayString.data(using: .utf8) else {
                NRLOG_DEBUG("Failed to convert JSON string to data for session ID: \(sessionId)")
                return
            }
            //if let jsonString = String(data: jsonData, encoding: .utf8) {
            //    NRLOG_DEBUG(jsonString)
            //\
            //}
            
            // END DATA CONSTRUCTION
            
            var finalData = jsonData
            do {
                let gzippedData = try jsonData.gzipped()
                finalData = gzippedData
            } catch {
                NRLOG_DEBUG("Failed to gzip session replay data for session ID \(sessionId): \(error.localizedDescription)")
            }
            
            let upload = SessionReplayData(sessionReplayFramesData: finalData, url: url)
            sessionReplayReporter.enqueueSessionReplayUpload(upload: upload)
            NRLOG_DEBUG("Enqueued previous session replay for session ID: \(sessionId)")
            
            // Remove processed files
            try FileManager.default.removeItem(at: sessionDirectory)
            try? FileManager.default.removeItem(at: urlFile)
            
        } catch {
            NRLOG_DEBUG("Failed to process session replay file for session ID \(sessionId): \(error)")
        }
    }
    
    private func getSessionReplayDirectory() -> URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsDirectory.appendingPathComponent("SessionReplayFrames")
    }
    
#endif
}

#if os(iOS) || os(tvOS)

@available(iOS 13.0, *)
extension SessionReplayManager: NRMASessionReplayDelegate {
    public func generateUploadURL(
        uncompressedDataSize: Int,
        firstTimestamp: TimeInterval,
        lastTimestamp: TimeInterval,
        isFirstChunk: Bool,
        isGZipped: Bool
    ) -> URL? {
        return self.sessionReplayReporter.uploadURL(uncompressedDataSize: uncompressedDataSize, firstTimestamp: firstTimestamp, lastTimestamp: lastTimestamp, isFirstChunk: isFirstChunk, isGZipped: isGZipped)
    }
}
#endif
