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
        
        let uploads = self.createReplayUpload(container: container,
                                              firstTimestamp: firstTimestamp,
                                              lastTimestamp: lastTimestamp)
        
        if uploads.isEmpty {
            NRLOG_DEBUG("No uploads created from session replay data")
            self.harvestseconds = 0
            return
        }
        
        NRLOG_DEBUG("Enqueueing \(uploads.count) session replay upload(s)")
        for upload in uploads {
            self.sessionReplayReporter.enqueueSessionReplayUpload(upload: upload)
        }
        
        self.sessionReplay.isFirstChunk = false
        self.harvestseconds = 0
    }
    
    private func createReplayUpload(container: [AnyRRWebEvent], firstTimestamp: TimeInterval, lastTimestamp: TimeInterval) -> [SessionReplayData] {
        return chunkAndCreateUploads(
            container: container,
            isFirstChunkInBatch: self.sessionReplay.isFirstChunk,
            urlComponents: nil
        )
    }
    
    // Shared chunking logic used by both createReplayUpload and processSessionReplayFile
    private func chunkAndCreateUploads(
        container: [AnyRRWebEvent],
        isFirstChunkInBatch: Bool,
        urlComponents: URLComponents?
    ) -> [SessionReplayData] {
        let maxCompressedSize = Int(kNRMAMaxPayloadSizeLimit)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes

        var uploads: [SessionReplayData] = []
        var currentIndex = 0
        var isFirstChunk = isFirstChunkInBatch
        
        while currentIndex < container.count {
            // Binary search for optimal chunk size
            let bestChunkSize = findOptimalChunkSize(
                container: container,
                startIndex: currentIndex,
                maxCompressedSize: maxCompressedSize,
                encoder: encoder
            )
            
            // Create chunk with best size
            let chunkEnd = currentIndex + bestChunkSize
            let chunk = Array(container[currentIndex..<chunkEnd])
            
            guard let jsonData = try? encoder.encode(chunk) else {
                NRLOG_DEBUG("Failed to encode chunk")
                currentIndex += bestChunkSize
                continue
            }
            
            let uncompressedDataSize = jsonData.count
            var finalData = jsonData
            
            do {
                let gzippedData = try jsonData.gzipped()
                finalData = gzippedData
            } catch {
                NRLOG_DEBUG("Failed to gzip chunk: \(error.localizedDescription)")
            }
            
            let chunkFirstTimestamp = TimeInterval(chunk.first?.base.timestamp ?? 0)
            let chunkLastTimestamp = TimeInterval(chunk.last?.base.timestamp ?? 0)
            
            // Create URL based on whether we're modifying an existing URL or creating a new one
            let url: URL?
            if let urlComponents = urlComponents {
                url = updateURLForChunk(
                    urlComponents: urlComponents,
                    uncompressedDataSize: uncompressedDataSize,
                    firstTimestamp: chunkFirstTimestamp,
                    lastTimestamp: chunkLastTimestamp,
                    isFirstChunk: isFirstChunk,
                    isGZipped: finalData.isGzipped
                )
            } else {
                url = sessionReplayReporter.uploadURL(
                    uncompressedDataSize: uncompressedDataSize,
                    firstTimestamp: chunkFirstTimestamp,
                    lastTimestamp: chunkLastTimestamp,
                    isFirstChunk: isFirstChunk,
                    isGZipped: finalData.isGzipped
                )
            }
            
            guard let validURL = url else {
                NRLOG_ERROR("Failed to construct upload URL")
                currentIndex += bestChunkSize
                continue
            }
            
            let dataSizeInMB = Double(finalData.count) / (1024.0 * 1024.0)
            NRLOG_DEBUG("Created chunk with \(chunk.count) events, compressed size: \(String(format: "%.2f", dataSizeInMB)) MB")
            NRLOG_DEBUG(validURL.absoluteString)
            
            uploads.append(SessionReplayData(sessionReplayFramesData: finalData, url: validURL))
            isFirstChunk = false
            currentIndex += bestChunkSize
        }

        return uploads
    }
    
    // Binary search to find optimal chunk size that fits within maxCompressedSize
    private func findOptimalChunkSize(
        container: [AnyRRWebEvent],
        startIndex: Int,
        maxCompressedSize: Int,
        encoder: JSONEncoder
    ) -> Int {
        var low = 1
        var high = container.count - startIndex
        var bestChunkSize = 1
        
        while low <= high {
            let mid = (low + high) / 2
            let chunkEnd = startIndex + mid
            let chunk = Array(container[startIndex..<chunkEnd])
            
            guard let jsonData = try? encoder.encode(chunk),
                  let gzippedData = try? jsonData.gzipped() else {
                high = mid - 1
                continue
            }
            
            if gzippedData.count <= maxCompressedSize {
                bestChunkSize = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        
        return bestChunkSize
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

            // END DATA CONSTRUCTION

            // Try to decode JSON into events for chunking
            let decoder = JSONDecoder()
            let container = try? decoder.decode([AnyRRWebEvent].self, from: jsonData)
            
            let uploads: [SessionReplayData]
            
            if let container = container,
               let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                // Extract isFirstChunk from the persisted URL
                let isFirstChunkInBatch = extractIsFirstChunkFromURL(urlComponents: urlComponents)
                
                // Successfully decoded - use chunking logic with URL components from persisted file
                uploads = chunkAndCreateUploads(
                    container: container,
                    isFirstChunkInBatch: isFirstChunkInBatch,
                    urlComponents: urlComponents
                )
            } else {
                // Failed to decode or parse URL - upload raw data as-is
                NRLOG_DEBUG("Failed to decode or parse URL for session ID: \(sessionId), uploading raw data")
                
                // Compress the raw JSON data
                var finalData = jsonData
                do {
                    let gzippedData = try jsonData.gzipped()
                    finalData = gzippedData
                } catch {
                    NRLOG_DEBUG("Failed to gzip raw data: \(error.localizedDescription)")
                }
                
                // Create single upload with raw data
                let upload = SessionReplayData(sessionReplayFramesData: finalData, url: url)
                uploads = [upload]
            }
            
            if uploads.isEmpty {
                NRLOG_DEBUG("No uploads created from previous session replay for session ID: \(sessionId)")
                try FileManager.default.removeItem(at: sessionDirectory)
                try? FileManager.default.removeItem(at: urlFile)
                return
            }
            
            NRLOG_DEBUG("Enqueueing \(uploads.count) previous session replay upload(s) for session ID: \(sessionId)")
            for upload in uploads {
                sessionReplayReporter.enqueueSessionReplayUpload(upload: upload)
            }

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
    
    // Helper method to extract isFirstChunk from URL
    private func extractIsFirstChunkFromURL(urlComponents: URLComponents) -> Bool {
        // Find the attributes query item and extract isFirstChunk
        if let queryItems = urlComponents.queryItems,
           let attributesItem = queryItems.first(where: { $0.name == "attributes" }),
           let attributesValue = attributesItem.value {
            
            // Parse attributes
            let pairs = attributesValue.components(separatedBy: "&")
            for pair in pairs {
                let keyValue = pair.components(separatedBy: "=")
                if keyValue.count == 2 && keyValue[0] == "isFirstChunk" {
                    return keyValue[1].lowercased() == "true"
                }
            }
        }
        
        // Default to true if not found
        return true
    }
    
    // Helper method to update URL with chunk-specific parameters
    private func updateURLForChunk(
        urlComponents: URLComponents,
        uncompressedDataSize: Int,
        firstTimestamp: TimeInterval,
        lastTimestamp: TimeInterval,
        isFirstChunk: Bool,
        isGZipped: Bool
    ) -> URL? {
        var components = urlComponents
        
        // Find the attributes query item and update it
        if let queryItems = components.queryItems,
           let attributesIndex = queryItems.firstIndex(where: { $0.name == "attributes" }),
           let attributesValue = queryItems[attributesIndex].value {
            
            // Parse existing attributes
            var attributesDict: [String: String] = [:]
            let pairs = attributesValue.components(separatedBy: "&")
            for pair in pairs {
                let keyValue = pair.components(separatedBy: "=")
                if keyValue.count == 2 {
                    attributesDict[keyValue[0]] = keyValue[1]
                }
            }
            
            // Update chunk-specific attributes
            attributesDict["isFirstChunk"] = String(isFirstChunk)
            attributesDict["decompressedBytes"] = String(uncompressedDataSize)
            attributesDict["replay.firstTimestamp"] = String(Int(firstTimestamp))
            attributesDict["replay.lastTimestamp"] = String(Int(lastTimestamp))
            
            // Update or remove content_encoding based on isGZipped
            if isGZipped {
                attributesDict["content_encoding"] = "gzip"
            } else {
                attributesDict.removeValue(forKey: "content_encoding")
            }
            
            // Reconstruct attributes string
            let newAttributesString = attributesDict.map { key, value in
                return "\(key)=\(value)"
            }.joined(separator: "&")
            
            // Update the query items
            var newQueryItems = queryItems
            newQueryItems[attributesIndex] = URLQueryItem(name: "attributes", value: newAttributesString)
            components.queryItems = newQueryItems
        }
        
        return components.url
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
