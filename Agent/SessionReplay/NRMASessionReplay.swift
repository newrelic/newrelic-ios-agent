//
//  NRMASessionReplay.swift
//  Agent_iOS
//
//  Created by Steve Malsam on 1/30/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation
import UIKit
@_implementationOnly import NewRelicPrivate

import OSLog

@available(iOS 13.0, *)
@objcMembers
public class NRMASessionReplay: NSObject {
    public weak var delegate: NRMASessionReplayDelegate?
    
    private let sessionReplayCapture: SessionReplayCapture
    private let sessionReplayFrameProcessor = SessionReplayFrameProcessor()
    private var sessionReplayTouchCapture: SessionReplayTouchCapture?
    private let sessionReplayTouchProcessor = TouchEventProcessor()
    private var rawFrames = [SessionReplayFrame]()
    
    
    // ONE RECORDING MODE
    public var recordingMode: SessionReplayRecordingMode = .off
    
    /// Maximum duration of frames to keep in error mode buffer (15 seconds)
    private let errorModeBufferDuration: TimeInterval = 15.0
    
    /// Interval for forcing full snapshots (15 seconds)
    /// This ensures a full snapshot is always available within the 15-second buffer
    private let fullSnapshotInterval: TimeInterval = 15.0
    
    /// Interval for pruning old files (30 seconds)
    private let pruneInterval: TimeInterval = 30.0
    
    /// Lock for thread-safe access to the buffer
    private let bufferLock = NSLock()
    
    /// Tracks the last time a full snapshot was forced (for 15-second full snapshot requirement)
    private var lastFullSnapshotTime: Date?
    
    /// Tracks the last time we pruned buffered files
    private var lastPruneTime: Date?
    
    /// Maximum number of frames to keep in circular buffer (30 seconds at ~1fps = 30 frames)
    private let maxBufferFrames: Int = 32
    
    /// Tracks which frame counter values contain full snapshots
    private var fullSnapshotFrameIndices: Set<Int> = []
    
    private let frameQueue = DispatchQueue(label: "com.newrelic.sessionreplay.frames")
    private let fileIOQueue = DispatchQueue(label: "com.newrelic.sessionreplay.fileio")
    
    public var isFirstChunk = true
    var uncompressedDataSize: Int = 0
    
    private var frameCounter: Int = 0
    private let framesDirectory: URL
    
    private var NRMAOriginal__sendEvent: UnsafeMutableRawPointer?
    
    private let url: NSString
    
    public init(url: NSString, delegate: NRMASessionReplayDelegate? = nil) {
        self.delegate = delegate
        self.url = url
        self.sessionReplayCapture = SessionReplayCapture()
        
        // sessionReplayFrameProcessor.useIncrementalDiffs = false // Only take full snapshots, not incremental diffs
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.framesDirectory = documentsPath.appendingPathComponent("SessionReplayFrames")
        
        super.init()
        
        try? FileManager.default.createDirectory(
            at: framesDirectory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        )
    }
    
    public func start() {
        NRLOG_AGENT_DEBUG("▶️ [start] ==================== SESSION REPLAY START ====================")
        //NRLOG_AGENT_DEBUG("▶️ [start] Recording mode: \(recordingMode)")
        //NRLOG_AGENT_DEBUG("▶️ [start] Max buffer frames: \(maxBufferFrames)")
        //NRLOG_AGENT_DEBUG("▶️ [start] Error mode buffer duration: \(errorModeBufferDuration)s")
        //NRLOG_AGENT_DEBUG("▶️ [start] Full snapshot interval: \(fullSnapshotInterval)s")
        //NRLOG_AGENT_DEBUG("▶️ [start] Prune interval: \(pruneInterval)s")
        //NRLOG_AGENT_DEBUG("▶️ [start] ====================================================")
        
        sessionReplayFrameProcessor.lastFullFrame = nil // We want to start a new session with no last Frame tracked

        Task{
            await MainActor.run {
                guard let window = getWindow() else {
                    NRLOG_AGENT_DEBUG("▶️ [start] ⚠️ No key window found on didBecomeActive")
                    return
                }
                self.sessionReplayTouchCapture = SessionReplayTouchCapture(window: window)
                swizzleSendEvent()
                //NRLOG_AGENT_DEBUG("▶️ [start] ✅ Touch capture initialized and event swizzling complete")
            }
        }
    }
    
    public func stop() {
        NRLOG_AGENT_DEBUG("⏹️ [stop] ==================== SESSION REPLAY STOP ====================")
        //NRLOG_AGENT_DEBUG("⏹️ [stop] Final buffer count: \(rawFrames.count)")
        //NRLOG_AGENT_DEBUG("⏹️ [stop] Final frameCounter: \(frameCounter)")
        //NRLOG_AGENT_DEBUG("⏹️ [stop] Final uncompressedDataSize: \(uncompressedDataSize) bytes")
        //NRLOG_AGENT_DEBUG("⏹️ [stop] ====================================================")
    }
    
    public func clearAllData() {
        let frameCount = rawFrames.count
        let oldFrameCounter = frameCounter
        let oldUncompressedSize = uncompressedDataSize
        
        NRLOG_AGENT_DEBUG("🧹 [clearAllData] ==================== CLEARING ALL DATA ====================")
        //NRLOG_AGENT_DEBUG("🧹 [clearAllData] Clearing \(frameCount) frames from buffer")
        //NRLOG_AGENT_DEBUG("🧹 [clearAllData] frameCounter: \(oldFrameCounter), uncompressedDataSize: \(oldUncompressedSize) bytes")
        
        rawFrames.removeAll()
        fullSnapshotFrameIndices.removeAll()
        
        if let touchCapture = sessionReplayTouchCapture {
            let touchCount = touchCapture.touchEvents.count
            //NRLOG_AGENT_DEBUG("🧹 [clearAllData] Resetting \(touchCount) touch events")
            touchCapture.resetEvents()
        }
        
        // should remove frames from file system after processing
        
        // Clear the session replay file after processing
        fileIOQueue.async { [weak self] in
            guard let self = self else { return }

            self.frameCounter = 0
            self.uncompressedDataSize = 0

            // clear the frames directory
            do {
                try self.clearFramesDirectory()
//                NRLOG_AGENT_DEBUG("🧹 [clearAllData] ✅ Cleared frames directory")
//                NRLOG_AGENT_DEBUG("🧹 [clearAllData] ====================================================")
            } catch {
                NRLOG_AGENT_DEBUG("🧹 [clearAllData] ❌ Failed to clear frames directory: \(error)")
            }
        }
    }
    
    func swizzleSendEvent() {
        DispatchQueue.once(token: "com.newrelic.swizzleSendEvent") {
            guard let clazz = objc_getClass("UIApplication") else {
                NRLOG_AGENT_DEBUG("ERROR: Unable to swizzle send event. Not able to track touches")
                return
            }
            
            let originalSelector = #selector(UIApplication.sendEvent(_:))
            
            let block: @convention(block)(UIApplication, UIEvent) -> Void = { app, event in
                // Always call original
                typealias Func = @convention(c)(AnyObject, Selector, UIEvent) -> Void
                let function = unsafeBitCast(self.NRMAOriginal__sendEvent, to: Func.self)
                let callOriginal = { function(app, originalSelector, event) }
                
                // If we don't have a capture instance, just forward
                guard let touchCapture = self.sessionReplayTouchCapture else {
                    callOriginal()
                    return
                }
                
                // Only process actual touch events with touches
                if event.type == .touches, let touches = event.allTouches, !touches.isEmpty {
                    touchCapture.captureSendEventTouches(event: event)
                }
                
                callOriginal()
            }
            
            let newImp = imp_implementationWithBlock(block)
            self.NRMAOriginal__sendEvent = NRMAReplaceInstanceMethod(clazz as? AnyClass, originalSelector, newImp)
        }
    }
    
    func takeFrame() {
        Task{
            guard let window = await getWindow() else {
                NRLOG_AGENT_DEBUG("No key window found while trying to take a frame")
                return
            }
            
            let frame = await sessionReplayCapture.recordFrom(rootView: window)
            addFrame(frame)
        }
    }
    
    func addFrame(_ frame: SessionReplayFrame) {
        
        frameQueue.async { [weak self] in
            guard let self = self else { return }
            self.rawFrames.append(frame)
            
            // BEGIN PROCESSING FRAME TO FILE
            // Process frame to file
            self.fileIOQueue.async { [weak self] in
                guard let self = self else { return }

                self.processFrameToFile(frame)

                // END PROCESSING FRAME TO FILE
            }
            
            if self.recordingMode == .error {
                self.pruneRawFrames()
            }
            
        }
    }
    
    /// Implements circular buffer behavior for rawFrames
    /// Maintains a fixed-size buffer with the most recent frames
    private func pruneRawFrames() {
        let beforeCount = rawFrames.count
        //NRLOG_AGENT_DEBUG("🔄 [pruneRawFrames] Starting prune - Buffer count: \(beforeCount), Max allowed: \(maxBufferFrames)")
        
        // Also ensure we don't keep frames older than the buffer duration
        let now = Date()
        let beforeTimeBasedPrune = rawFrames.count
        rawFrames.removeAll { frame in
            return now.timeIntervalSince(frame.date) > errorModeBufferDuration
        }
        let timeBasedRemoved = beforeTimeBasedPrune - rawFrames.count
        
        let afterCount = rawFrames.count
        let totalRemoved = beforeCount - afterCount
        
        if totalRemoved > 0 {
            //NRLOG_AGENT_DEBUG("🔄 [pruneRawFrames] Removed \(totalRemoved) frames total (time-based: \(timeBasedRemoved)) - Buffer now: \(afterCount)")
            if let oldestFrame = rawFrames.first, let newestFrame = rawFrames.last {
                let bufferSpan = newestFrame.date.timeIntervalSince(oldestFrame.date)
              //  NRLOG_AGENT_DEBUG("🔄 [pruneRawFrames] Time span after prune: \(String(format: "%.2f", bufferSpan))s")
            }
        } else {
            //NRLOG_AGENT_DEBUG("🔄 [pruneRawFrames] No frames removed - Buffer: \(afterCount)")
        }
    }
    
    func getAndClearFrames(clear: Bool = true) -> [SessionReplayFrame] {
        //NRLOG_AGENT_DEBUG("📤 [getAndClearFrames] Called with clear=\(clear)")
        //NRLOG_AGENT_DEBUG("📤 [getAndClearFrames] Current buffer count: \(rawFrames.count)")
        
        var frames = [SessionReplayFrame]()
        frames = self.rawFrames
        
        if frames.count > 0, let oldestFrame = frames.first, let newestFrame = frames.last {
            let bufferSpan = newestFrame.date.timeIntervalSince(oldestFrame.date)
            //NRLOG_AGENT_DEBUG("📤 [getAndClearFrames] Returning \(frames.count) frames spanning \(String(format: "%.2f", bufferSpan))s")
            //NRLOG_AGENT_DEBUG("📤 [getAndClearFrames] Frame range: \(oldestFrame.date) to \(newestFrame.date)")
        }
        
        if clear {
            //NRLOG_AGENT_DEBUG("📤 [getAndClearFrames] Clearing buffer and files")
            self.rawFrames.removeAll()
            self.fullSnapshotFrameIndices.removeAll()
            
            // should remove frames from file system after processing
            
            // Clear the session replay file after processing
            fileIOQueue.async { [weak self] in
                guard let self = self else { return }

               // let oldFrameCounter = self.frameCounter
               // let oldUncompressedSize = self.uncompressedDataSize

                self.frameCounter = 0
                self.uncompressedDataSize = 0

                //NRLOG_AGENT_DEBUG("📤 [getAndClearFrames] Resetting counters - frameCounter: \(oldFrameCounter)→0, uncompressedDataSize: \(oldUncompressedSize)→0")

                // clear the frames directory
                do {
                    try self.clearFramesDirectory()
                    //NRLOG_AGENT_DEBUG("📤 [getAndClearFrames] ✅ Cleared frames directory")
                } catch {
                    NRLOG_AGENT_DEBUG("📤 [getAndClearFrames] ❌ Failed to clear frames directory: \(error)")
                }
            }
        }
        return frames
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
    
    func getSessionReplayFrames(clear: Bool = true) -> [RRWebEventCommon] {
        return frameQueue.sync { [weak self] in
            guard let self = self else { return [] }

            var processedFrames: [RRWebEventCommon] = []
            var currentSize: CGSize = .zero

            // Get frames in a thread-safe manner
            let frames = self.getAndClearFrames(clear: clear)

            // Guard against empty frames to prevent unnecessary processing
            guard !frames.isEmpty else {
                return []
            }

            // Reset processor state safely
            self.sessionReplayFrameProcessor.lastFullFrame = nil // We want the first frame to be a full frame

            // Reserve capacity for better performance
            processedFrames.reserveCapacity(frames.count * 2) // Estimate for frames + meta events

            for frame in frames {
                // Check for size changes and add meta event if needed
                if currentSize != frame.size {
                    currentSize = frame.size
                    let metaEventData = RRWebMetaData(
                        href: "http://newrelic.com",
                        width: Int(currentSize.width),
                        height: Int(currentSize.height)
                    )
                    let metaEvent = MetaEvent(timestamp: (frame.date.timeIntervalSince1970 * 1000).rounded(), data: metaEventData)
                    processedFrames.append(metaEvent)
                }

                // Process frame safely
                if let newFrame = self.sessionReplayFrameProcessor.processFrame(frame) {
                    processedFrames.append(newFrame)
                }
            }

            return processedFrames
        }
    }
    
    func getSessionReplayTouches(clear: Bool = true) -> [IncrementalEvent] {
        guard let touchCapture = sessionReplayTouchCapture else {
            NRLOG_AGENT_DEBUG("sessionReplayTouchCapture is nil in getSessionReplayTouches")
            return []
        }
        let touches = sessionReplayTouchProcessor.processTouches(touchCapture.touchEvents)
        if clear {
            touchCapture.resetEvents()
        }
        return touches
    }
    
    // Get only touches that haven't been persisted yet for file persistence
    func getUnpersistedTouches() -> [IncrementalEvent] {
        guard let touchCapture = sessionReplayTouchCapture else {
            NRLOG_AGENT_DEBUG("sessionReplayTouchCapture is nil in getUnpersistedTouches")
            return []
        }
        
        // Filter to only unpersisted touches
        let unpersistedTouchEvents = touchCapture.touchEvents.filter { !$0.isPersisted }
        
        // Process only the unpersisted touches
        let processedTouches = sessionReplayTouchProcessor.processTouches(unpersistedTouchEvents)
        
        // Mark these touches as persisted
        unpersistedTouchEvents.forEach { $0.isPersisted = true }
        
        return processedTouches
    }
    
    /// REPLAY PERSISTENCE
    
    func processFrameToFile(_ frame: SessionReplayFrame) {
        
        
        //let beforeCount = rawFrames.count
        
        //NRLOG_AGENT_DEBUG("📹 [addFrame] Adding frame - Mode: \(recordingMode), Buffer size before: \(beforeCount)")
        //NRLOG_AGENT_DEBUG("📹 [addFrame] Frame timestamp: \(frame.date), Size: \(frame.size)")
        
        // Check if we need to force a full snapshot every 15 seconds
        // THIS IS REQUIRED FOR CRASHED SESSION SUPPORT
        checkAndForceFullSnapshot(for: frame)
        
        //NRLOG_AGENT_DEBUG("💾 [processFrameToFile] ========== Processing frame to file ==========")
        //NRLOG_AGENT_DEBUG("💾 [processFrameToFile] Frame date: \(frame.date), Size: \(frame.size)")
        
        // Fetch processed frame and only unpersisted touches
        let lastFrameSize = sessionReplayFrameProcessor.lastFullFrame?.size ?? .zero
        let isFullSnapshot = sessionReplayFrameProcessor.takeFullSnapshotNext
        let processedFrame = self.sessionReplayFrameProcessor.processFrame(frame)
        let processedTouches = self.getUnpersistedTouches()
        
        //NRLOG_AGENT_DEBUG("💾 [processFrameToFile] Frame type: \(isFullSnapshot ? "FULL SNAPSHOT" : "Incremental")")
        //NRLOG_AGENT_DEBUG("💾 [processFrameToFile] Unpersisted touches: \(processedTouches.count)")
        
        guard let firstFrame = rawFrames.first else {
            NRLOG_AGENT_DEBUG("💾 [processFrameToFile] No frames in buffer, skipping")
            return
        }
        
        guard let processedFrame = processedFrame else {
            return
        }
        
        let firstTimestamp: TimeInterval = TimeInterval(firstFrame.date.timeIntervalSince1970 * 1000).rounded()
        let lastTimestamp: TimeInterval = TimeInterval(processedFrame.timestamp)
        
        var container: [AnyRRWebEvent] = []
        
        // Only add meta event for first frame or when frame size changes
        if lastFrameSize != frame.size || isFullSnapshot {
            NRLOG_AGENT_DEBUG("💾 [processFrameToFile] Size change detected - Adding meta event")
            let metaEventData = RRWebMetaData(
                href: "http://newrelic.com",
                width: Int(frame.size.width),
                height: Int(frame.size.height)
            )
            let metaEvent = MetaEvent(timestamp: TimeInterval(lastTimestamp), data: metaEventData)
            container.append(AnyRRWebEvent(metaEvent))
        }
        
        container.append(AnyRRWebEvent(processedFrame))
        container.append(contentsOf: processedTouches.map(AnyRRWebEvent.init))
        container.sort { (lhs: AnyRRWebEvent, rhs: AnyRRWebEvent) -> Bool in
            lhs.base.timestamp < rhs.base.timestamp
        }
        
        //        NRLOG_AGENT_DEBUG("💾 [processFrameToFile] Container events: \(container.count)")
        
        // Extract URL generation logic from createReplayUpload
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes
        
        // Encode container to get data size for URL generation
        guard let jsonData = try? encoder.encode(container) else {
            NRLOG_AGENT_DEBUG("💾 [processFrameToFile] ❌ Failed to encode events for URL generation")
            return
        }
        // DEBUGGING FOR jsonData to strring
//        print("json data text = \(String(data: jsonData, encoding: .utf8) ?? "nil")")
        
        let beforeSize = uncompressedDataSize
        uncompressedDataSize += jsonData.count
        //
        //        NRLOG_AGENT_DEBUG("💾 [processFrameToFile] JSON data size: \(jsonData.count) bytes")
        //        NRLOG_AGENT_DEBUG("💾 [processFrameToFile] Cumulative uncompressed size: \(beforeSize) → \(uncompressedDataSize) bytes")
        
        // BEGIN URL GENERATION
        // Generate upload URL that would be used if accumulated frames uploaded directly
        guard let uploadUrl = delegate?.generateUploadURL(
            uncompressedDataSize: uncompressedDataSize,
            firstTimestamp: firstTimestamp,
            lastTimestamp: lastTimestamp,
            isFirstChunk: isFirstChunk,
            isGZipped: true
        ) else {
            NRLOG_AGENT_DEBUG("💾 [processFrameToFile] ❌ Failed to construct upload URL for session replay.")
            return
        }
        // END URL GENERATION
        
        // NRLOG_AGENT_DEBUG("💾 [processFrameToFile] Upload URL generated: \(uploadUrl.absoluteString)")
        
        // Save frame data and URL separately
        let agent = NewRelicAgentInternal.sharedInstance()
        let sessionId = agent?.currentSessionId() ?? "unknown_session"
        let frameFolder = self.framesDirectory.appendingPathComponent("\(sessionId)/")
        
        let urlFile = self.framesDirectory.appendingPathComponent("\(sessionId)_upload_url.txt")
        
        do {
            try FileManager.default.createDirectory(
                at: frameFolder,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
            )
            let frameURL = frameFolder.appendingPathComponent("frame_\(frameCounter).json")
            try jsonData.write(to: frameURL)
            
            // NRLOG_AGENT_DEBUG("💾 [processFrameToFile] ✅ Wrote frame_\(frameCounter).json (\(jsonData.count) bytes)")
            
            // Save/update URL separately
            try uploadUrl.absoluteString.write(to: urlFile, atomically: true, encoding: .utf8)
            
            // Track if this frame contains a full snapshot
            if isFullSnapshot {
                fullSnapshotFrameIndices.insert(frameCounter)
                // NRLOG_AGENT_DEBUG("💾 [processFrameToFile] ✅ Recorded full snapshot at frame \(frameCounter)")
            }
            
            // In Error mode, we need to track the file creation time for pruning
            if recordingMode == .error {
                let attributes = [FileAttributeKey.creationDate: Date()]
                try FileManager.default.setAttributes(attributes, ofItemAtPath: frameURL.path)
                
                //NRLOG_AGENT_DEBUG("💾 [processFrameToFile] Mode: ERROR - Checking if pruning needed")
                // Prune old files if in ERROR mode
                pruneBufferedFiles(in: frameFolder)
            }
            
            frameCounter += 1
            
//            // Count files in directory
//            if let fileCount = try? FileManager.default.contentsOfDirectory(at: frameFolder, includingPropertiesForKeys: nil).count {
//                NRLOG_AGENT_DEBUG("💾 [processFrameToFile] Total files in folder: \(fileCount)")
//            }
            
            //NRLOG_AGENT_DEBUG("💾 [processFrameToFile] ================================================")
        } catch {
            NRLOG_AGENT_DEBUG("💾 [processFrameToFile] ❌ Failed to append frame to filesystem: \(error)")
        }
    }
    
    // MARK: - Error Sampling Mode Management
    
    /// Sets the recording mode for session replay
    /// - Parameter mode: The new recording mode to use
    public func transistionToRecordingMode(_ mode: SessionReplayRecordingMode) {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        
        let oldMode = recordingMode
        let bufferCountBefore = rawFrames.count
        let uncompressedSizeBefore = uncompressedDataSize
        let frameCounterBefore = frameCounter
        
        recordingMode = mode
        
        NRLOG_AGENT_DEBUG("🎬 [transistionToRecordingMode] ==================== MODE CHANGE ====================")
        NRLOG_AGENT_DEBUG("🎬 [transistionToRecordingMode] Old mode: \(oldMode) → New mode: \(mode)")
        NRLOG_AGENT_DEBUG("🎬 [transistionToRecordingMode] Buffer stats before transition:")
        NRLOG_AGENT_DEBUG("🎬 [transistionToRecordingMode]   - rawFrames count: \(bufferCountBefore)")
        NRLOG_AGENT_DEBUG("🎬 [transistionToRecordingMode]   - frameCounter: \(frameCounterBefore)")
        NRLOG_AGENT_DEBUG("🎬 [transistionToRecordingMode]   - uncompressedDataSize: \(uncompressedSizeBefore) bytes")
        
        if bufferCountBefore > 0, let oldestFrame = rawFrames.first, let newestFrame = rawFrames.last {
            let bufferSpan = newestFrame.date.timeIntervalSince(oldestFrame.date)
            NRLOG_AGENT_DEBUG("🎬 [transistionToRecordingMode]   - Buffer time span: \(String(format: "%.2f", bufferSpan))s")
            NRLOG_AGENT_DEBUG("🎬 [transistionToRecordingMode]   - Oldest frame: \(oldestFrame.date)")
            NRLOG_AGENT_DEBUG("🎬 [transistionToRecordingMode]   - Newest frame: \(newestFrame.date)")
        }
        
        // Clear buffers when transitioning modes
        if mode == .off {
            NRLOG_AGENT_DEBUG("🎬 [transistionToRecordingMode] Transitioning to OFF - Clearing snapshots")
            lastFullSnapshotTime = nil
        }
        else if mode == .error {
            // When entering error mode, clear any existing frames
            NRLOG_AGENT_DEBUG("🎬 [transistionToRecordingMode] Transitioning to ERROR mode - Setting snapshot time")
            lastFullSnapshotTime = Date()
            NRLOG_AGENT_DEBUG("🎬 [transistionToRecordingMode] Buffer duration: \(errorModeBufferDuration)s, Full snapshot interval: \(fullSnapshotInterval)s")
        }
        else if mode == .full {
            NRLOG_AGENT_DEBUG("🎬 [transistionToRecordingMode] Transitioning to FULL mode")
        }
        
        NRLOG_AGENT_DEBUG("🎬 [transistionToRecordingMode] ====================================================")
    }
    
    /// Transitions from error mode to full mode when an error is detected
    /// This flushes the 15-second error buffer to the main frame buffer
    public func transitionToFullModeOnError() {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        
        
        let bufferCount = rawFrames.count
        NRLOG_AGENT_DEBUG("🚨 [transitionToFullModeOnError] ==================== ERROR DETECTED ====================")
        NRLOG_AGENT_DEBUG("🚨 [transitionToFullModeOnError]   - rawFrames count: \(bufferCount)")
        NRLOG_AGENT_DEBUG("🚨 [transitionToFullModeOnError]   - frameCounter: \(frameCounter)")
        NRLOG_AGENT_DEBUG("🚨 [transitionToFullModeOnError]   - uncompressedDataSize: \(uncompressedDataSize) bytes")
        
        if bufferCount > 0, let oldestFrame = rawFrames.first, let newestFrame = rawFrames.last {
            let bufferSpan = newestFrame.date.timeIntervalSince(oldestFrame.date)
            NRLOG_AGENT_DEBUG("🚨 [transitionToFullModeOnError]   - Buffer time span: \(String(format: "%.2f", bufferSpan))s")
            NRLOG_AGENT_DEBUG("🚨 [transitionToFullModeOnError]   - Frames will be uploaded from error buffer")
        }
        
        // Transition to full mode
        recordingMode = .full
        
        // Force next frame to be a full snapshot for clean transition
        sessionReplayFrameProcessor.takeFullSnapshotNext = true
        NRLOG_AGENT_DEBUG("🚨 [transitionToFullModeOnError] Next frame will be a full snapshot")
        NRLOG_AGENT_DEBUG("🚨 [transitionToFullModeOnError] =========================================================")
    }
    
    /// Checks if a full snapshot should be forced (every 15 seconds)
    /// This ensures a full snapshot is always available within the buffer
    private func checkAndForceFullSnapshot(for frame: SessionReplayFrame) {
        
        bufferLock.lock()
        defer { bufferLock.unlock() }
        
        guard let lastSnapshot = lastFullSnapshotTime else {
            NRLOG_AGENT_DEBUG("📸 [checkAndForceFullSnapshot] First snapshot - forcing full snapshot")
            lastFullSnapshotTime = frame.date
            sessionReplayFrameProcessor.takeFullSnapshotNext = true
            return
        }
        
        let timeSinceLastSnapshot = frame.date.timeIntervalSince(lastSnapshot)
        // NRLOG_AGENT_DEBUG("📸 [checkAndForceFullSnapshot] Time since last snapshot: \(String(format: "%.2f", timeSinceLastSnapshot))s / \(fullSnapshotInterval)s")
        
        if timeSinceLastSnapshot >= fullSnapshotInterval {
            // NRLOG_AGENT_DEBUG("📸 [checkAndForceFullSnapshot] ✅ Forcing full snapshot after \(String(format: "%.2f", timeSinceLastSnapshot))s")
            sessionReplayFrameProcessor.takeFullSnapshotNext = true
            lastFullSnapshotTime = frame.date
        }
    }
    
    
    /// Prunes buffered files to maintain a 14-15 frame rolling window
    /// Only runs every 30 seconds to reduce file system overhead
    /// Ensures the first frame is always a full snapshot
    private func pruneBufferedFiles(in folder: URL) {
        let now = Date()
        
        // Only prune every 30 seconds
        if let lastPrune = lastPruneTime {
            let timeSinceLastPrune = now.timeIntervalSince(lastPrune)
            if timeSinceLastPrune < pruneInterval {
                return // Not time to prune yet
            }
        }
        
        // Update last prune time
        lastPruneTime = now
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
                options: .skipsHiddenFiles
            )
            
            // Parse frame indices from filenames and sort
            struct FileInfo {
                let url: URL
                let frameIndex: Int
                let creationDate: Date
                let size: Int
                let isFullSnapshot: Bool
            }
            
            var fileInfos: [FileInfo] = []
            for fileURL in fileURLs {
                // Extract frame number from filename (frame_123.json -> 123)
                let filename = fileURL.lastPathComponent
                guard let frameIndexString = filename.components(separatedBy: "_").last?.components(separatedBy: ".").first,
                      let frameIndex = Int(frameIndexString) else {
                    continue
                }
                
                guard let resourceValues = try? fileURL.resourceValues(forKeys: [.creationDateKey, .fileSizeKey]),
                      let creationDate = resourceValues.creationDate else {
                    continue
                }
                
                let fileSize = resourceValues.fileSize ?? 0
                let isFullSnapshot = fullSnapshotFrameIndices.contains(frameIndex)
                
                fileInfos.append(FileInfo(
                    url: fileURL,
                    frameIndex: frameIndex,
                    creationDate: creationDate,
                    size: fileSize,
                    isFullSnapshot: isFullSnapshot
                ))
            }
            
            // Sort by frame index (oldest first)
            fileInfos.sort { $0.frameIndex < $1.frameIndex }
            
            // Find the cutoff point: keep 14-15 frames starting from a full snapshot
            let targetFrameCount = 16
            let minFrameCount = 16
            
            var filesToKeep: [FileInfo] = []
            var filesToDelete: [FileInfo] = []
            
            if fileInfos.count <= minFrameCount {
                // Not enough files to prune, keep all
                filesToKeep = fileInfos
                 //NRLOG_AGENT_DEBUG("🗑️ [pruneBufferedFiles] Only \(fileInfos.count) files - keeping all")
            }
            else {
                // Find the most recent full snapshot that allows keeping 14-15 frames
                let startSearchIndex = max(0, fileInfos.count - targetFrameCount)
                
                // Look backwards from the end to find a full snapshot within the keep window
                var fullSnapshotIndex: Int? = nil
                for i in stride(from: fileInfos.count - 1, through: startSearchIndex, by: -1) {
                    if fileInfos[i].isFullSnapshot {
                        fullSnapshotIndex = i
                        break
                    }
                }
                
                // If no full snapshot in last 15 frames, search earlier frames
                if fullSnapshotIndex == nil {
                    for i in stride(from: startSearchIndex - 1, through: 0, by: -1) {
                        if fileInfos[i].isFullSnapshot {
                            fullSnapshotIndex = i
                            break
                        }
                    }
                }
                
                if let snapshotIndex = fullSnapshotIndex {
                    // Keep from the full snapshot onwards
                    filesToKeep = Array(fileInfos[snapshotIndex...])
                    filesToDelete = Array(fileInfos[0..<snapshotIndex])
                    //NRLOG_AGENT_DEBUG("🗑️ [pruneBufferedFiles] Full snapshot at frame_\(fileInfos[snapshotIndex].frameIndex) - keeping \(filesToKeep.count) frames")
                }
                else {
                    // No full snapshot found - keep most recent 14 frames
                    let keepStartIndex = max(0, fileInfos.count - minFrameCount)
                    filesToKeep = Array(fileInfos[keepStartIndex...])
                    filesToDelete = Array(fileInfos[0..<keepStartIndex])
                     //NRLOG_AGENT_DEBUG("🗑️ [pruneBufferedFiles] ⚠️ No full snapshot - keeping \(filesToKeep.count) most recent frames")
                }
            }
            
            // Delete old files and clean up tracking set
            var prunedCount = 0
            var prunedSize = 0
            
            for fileInfo in filesToDelete {
                try FileManager.default.removeItem(at: fileInfo.url)
                fullSnapshotFrameIndices.remove(fileInfo.frameIndex) // Clean up tracking
                prunedCount += 1
                prunedSize += fileInfo.size
                //NRLOG_AGENT_DEBUG("🗑️ [pruneBufferedFiles]   ❌ Removed frame_\(fileInfo.frameIndex)")
            }
        }
        catch {
            NRLOG_AGENT_DEBUG("🗑️ [pruneBufferedFiles] ❌ Failed to prune buffered files: \(error)")
        }
    }
    
    // END Error Sampling Mode Management

    /// Removes the frames directory and recreates it with explicit file protection.
    /// If the atomic remove fails (e.g. a locked file inside), falls back to deleting
    /// each item individually so a single inaccessible file can't block the whole clear.
    private func clearFramesDirectory() throws {
        let fm = FileManager.default

        if fm.fileExists(atPath: framesDirectory.path) {
            do {
                try fm.removeItem(at: framesDirectory)
            } catch {
                // Atomic removal failed — remove contents one-by-one instead.
                let contents = (try? fm.contentsOfDirectory(
                    at: framesDirectory,
                    includingPropertiesForKeys: nil,
                    options: .skipsHiddenFiles
                )) ?? []
                for item in contents {
                    try? fm.removeItem(at: item)
                }
            }
        }

        try fm.createDirectory(
            at: framesDirectory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        )
    }
}

@available(iOS 13.0, *)
public protocol NRMASessionReplayDelegate: AnyObject {
    func generateUploadURL(
        uncompressedDataSize: Int,
        firstTimestamp: TimeInterval,
        lastTimestamp: TimeInterval,
        isFirstChunk: Bool,
        isGZipped: Bool
    ) -> URL?
}

extension DispatchQueue {
    private static var _onceTracker = [String]()
    
    static func once(token: String, block: () -> Void) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        
        if _onceTracker.contains(token) {
            return
        }
        
        _onceTracker.append(token)
        block()
    }
}
