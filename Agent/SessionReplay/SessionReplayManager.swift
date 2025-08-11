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
    private var harvestseconds = 0
    public var sessionReplayTimer: Timer?

    private let url: NSString
    
    private let sessionReplayQueue = DispatchQueue(label: "com.newrelic.sessionReplayQueue", attributes: .concurrent)

    @objc public init(reporter: SessionReplayReporter, url: NSString) {
        self.url = url
        self.sessionReplay = NRMASessionReplay(url: self.url)
        self.sessionReplayReporter = reporter
        super.init()
        
        self.sessionReplay.delegate = self

    }

    public func start() {
        sessionReplayQueue.async { [self] in
            guard !isRunning() else {
                NRLOG_WARNING("Session replay harvest timer attempting to start while already running.")
                return
            }
            sessionReplay.start()
            self.harvestseconds = 0

            self.sessionReplay.isFirstChunk = true

            NewRelicAgentInternal.sharedInstance()?.analyticsController.setNRSessionAttribute(kNRMA_RA_hasReplay, value: NRMABool(bool: true))

            NRLOG_DEBUG("Session replay harvest timer starting with a period of \(harvestPeriod) s")
            self.sessionReplayTimer = Timer(timeInterval: 1.0, target: self, selector: #selector(self.sessionReplayTick), userInfo: nil, repeats: true)

            RunLoop.current.add(self.sessionReplayTimer!, forMode: .default)
            RunLoop.current.run()
        }
    }

    public func stop() {
        sessionReplayQueue.async { [self] in
            guard isRunning() else {
                NRLOG_WARNING("Session replay harvest timer attempting to stop when not running.")
                return
            }
            
            sessionReplay.stop()
            
            sessionReplayTimer?.invalidate()
            sessionReplayTimer = nil
            
            NRLOG_DEBUG("Session replay has shut down and is no longer running.")
        }
    }

    @objc public func isRunning() -> Bool {
        return self.sessionReplayTimer != nil && self.sessionReplayTimer!.isValid
    }

    // This function is to handle a session change created by a change in userId
    @objc public func newSession() {
        stop()
        harvest()
        start()
    }
    
    @objc public func clearAllData() {
        sessionReplayQueue.sync { [self] in
            sessionReplay.clearAllData()
        }
    }
    
    @objc func sessionReplayTick() {
        harvestseconds += 1
        sessionReplay.takeFrame()
        
        if harvestseconds == harvestPeriod {
            harvest()
        }
    }

    @objc public func harvest() {
        sessionReplayQueue.sync { [self] in
            let frames = sessionReplay.getSessionReplayFrames()
            let touches = sessionReplay.getSessionReplayTouches()
            
            if frames.isEmpty && touches.isEmpty {
                NRLOG_DEBUG("No session replay frames or touches to harvest.")
                return
            }
            
            // Build combined list then sort by timestamp
            var container = frames.map(AnyRRWebEvent.init)
            container.append(contentsOf: touches.map(AnyRRWebEvent.init))
            container.sort { $0.timestamp < $1.timestamp }
            
            // Derive first / last from sorted result
            let firstTimestamp = TimeInterval(container.first?.timestamp ?? 0)
            let lastTimestamp  = TimeInterval(container.last?.timestamp ?? 0)
            
            guard let upload = createReplayUpload(container: container,
                                                  firstTimestamp: firstTimestamp,
                                                  lastTimestamp: lastTimestamp) else {
                return
            }
            sessionReplayReporter.enqueueSessionReplayUpload(upload: upload)
            self.sessionReplay.isFirstChunk = false
            harvestseconds = 0
        }
    }

    private func createReplayUpload(container: [AnyRRWebEvent], firstTimestamp: TimeInterval, lastTimestamp: TimeInterval) -> SessionReplayData? {
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
            NRLOG_ERROR("Failed to construct upload URL for session replay.")
            return nil
        }
        NRLOG_DEBUG(url.absoluteString)

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
                
            } catch {
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
            NRLOG_DEBUG(url.absoluteString)

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

            // Read and combine all frame files
            var frameContents: [String] = []
            for frameFile in frameFiles {
                do {
                    // remove outer [] from frameFile if they exist
                    let frameContent = try String(contentsOf: frameFile).trimmingCharacters(in: .whitespacesAndNewlines)

                    var frameContentWithOuterBracketsRemoved = frameContent
                    if frameContent.hasPrefix("[") && frameContent.hasSuffix("]") {
                        frameContentWithOuterBracketsRemoved = String(frameContent.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    if !frameContentWithOuterBracketsRemoved.isEmpty {
                        frameContents.append(frameContentWithOuterBracketsRemoved)
                    }
                } catch {
                    NRLOG_DEBUG("Failed to read frame file \(frameFile.lastPathComponent): \(error)")
                }
            }

            if frameContents.isEmpty {
                NRLOG_DEBUG("No valid frame content found for session ID: \(sessionId)")
                try FileManager.default.removeItem(at: sessionDirectory)
                try? FileManager.default.removeItem(at: urlFile)
                return
            }

            // Construct JSON array from frame contents

            let jsonArrayString = "[" + frameContents.joined(separator: ",") + "]"

            guard let jsonData = jsonArrayString.data(using: .utf8) else {
                NRLOG_ERROR("Failed to convert JSON string to data for session ID: \(sessionId)")
                return
            }
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                NRLOG_DEBUG(jsonString)
            }

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
}

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
