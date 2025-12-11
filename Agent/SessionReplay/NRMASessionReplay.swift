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
    
    public var recordingMode: SessionReplayRecordingMode = .off
    /// Circular buffer for error mode - stores last 15 seconds of frames
    private var errorModeBuffer: [BufferedReplayFrame] = []

    /// Maximum duration of frames to keep in error mode buffer (15 seconds)
    private let errorModeBufferDuration: TimeInterval = 15.0

    /// Lock for thread-safe access to the buffer
    private let bufferLock = NSLock()

    /// Tracks the last time a full snapshot was forced (for 15-second full snapshot requirement)
    private var lastFullSnapshotTime: Date?
    
    
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

        try? FileManager.default.createDirectory(at: framesDirectory, withIntermediateDirectories: true)
    }

    public func start() {

        sessionReplayFrameProcessor.lastFullFrame = nil // We want to start a new session with no last Frame tracked
        Task{
            await MainActor.run {
                guard let window = getWindow() else {
                    NRLOG_DEBUG("No key window found on didBecomeActive")
                    return
                }
                self.sessionReplayTouchCapture = SessionReplayTouchCapture(window: window)
                swizzleSendEvent()
            }
        }
    }

    public func stop() {

    }
    
    public func clearAllData() {
        rawFrames.removeAll()
        if let touchCapture = sessionReplayTouchCapture {
            touchCapture.resetEvents()
        }
        // should remove frames from file system after processing

        // Clear the session replay file after processing
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            
            self.frameCounter = 0
            self.uncompressedDataSize = 0
            // clear the frames directory
            guard FileManager.default.fileExists(atPath: self.framesDirectory.path) else {
                return
            }
            do {
                try FileManager.default.removeItem(at: self.framesDirectory)
            } catch {
                NRLOG_DEBUG("Failed to clear frames directory: \(error)")
            }
        }
    }

    func swizzleSendEvent() {
        DispatchQueue.once(token: "com.newrelic.swizzleSendEvent") {
            guard let clazz = objc_getClass("UIApplication") else {
                NRLOG_DEBUG("ERROR: Unable to swizzle send event. Not able to track touches")
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
                NRLOG_DEBUG("No key window found while trying to take a frame")
                return
            }

            let frame = await sessionReplayCapture.recordFrom(rootView: window)
            addFrame(frame)
        }
    }

    func addFrame(_ frame: SessionReplayFrame) {
        
        bufferLock.lock()
        defer { bufferLock.unlock() }

        // Check if we need to force a full snapshot every 15 seconds
        checkAndForceFullSnapshot(for: frame)
        
        self.rawFrames.append(frame)


        // BEGIN PROCESSING FRAME TO FILE
        // Process frame to file
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }

            self.processFrameToFile(frame)
        }

        // END PROCESSING FRAME TO FILE
        
        if recordingMode == .error {
            pruneRawFrames()
        }
    }
    
    private func pruneRawFrames() {
        let now = Date()
        let maxBufferTime: TimeInterval = 15.0
        rawFrames.removeAll { frame in
            return now.timeIntervalSince(frame.date) > maxBufferTime
        }
    }
    
    func getAndClearFrames(clear: Bool = true) -> [SessionReplayFrame] {
        var frames = [SessionReplayFrame]()
        frames = self.rawFrames
        if clear {
            self.rawFrames.removeAll()

            // should remove frames from file system after processing

            // Clear the session replay file after processing
            DispatchQueue.global(qos: .background).async { [weak self] in
                guard let self = self else { return }

                self.frameCounter = 0
                self.uncompressedDataSize = 0
                // clear the frames directory
                do {
                    try FileManager.default.removeItem(at: self.framesDirectory)
                    try FileManager.default.createDirectory(at: self.framesDirectory, withIntermediateDirectories: true)
                } catch {
                    NRLOG_DEBUG("Failed to clear frames directory: \(error)")
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
        var processedFrames: [RRWebEventCommon] = []

        var currentSize:CGSize = .zero
        let frames = getAndClearFrames(clear: clear)
        sessionReplayFrameProcessor.lastFullFrame = nil // We want the first frame to be a full frame

        for frame in frames {
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
            processedFrames.append(sessionReplayFrameProcessor.processFrame(frame))
        }

        return processedFrames
    }

    func getSessionReplayTouches(clear: Bool = true) -> [IncrementalEvent] {
        guard let touchCapture = sessionReplayTouchCapture else {
            NRLOG_DEBUG("sessionReplayTouchCapture is nil in getSessionReplayTouches")
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
            NRLOG_DEBUG("sessionReplayTouchCapture is nil in getUnpersistedTouches")
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
        // Fetch processed frame and only unpersisted touches
        let lastFrameSize = sessionReplayFrameProcessor.lastFullFrame?.size ?? .zero
        let processedFrame = self.sessionReplayFrameProcessor.processFrame(frame)
        let processedTouches = self.getUnpersistedTouches()
        
        guard let firstFrame = rawFrames.first else {
            return
        }
        let firstTimestamp: TimeInterval = TimeInterval(firstFrame.date.timeIntervalSince1970 * 1000).rounded()
        let lastTimestamp: TimeInterval = TimeInterval(processedFrame.timestamp)

        var container: [AnyRRWebEvent] = []

        // Only add meta event for first frame or when frame size changes
        if lastFrameSize != frame.size {
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

        // Extract URL generation logic from createReplayUpload
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes

        // Encode container to get data size for URL generation
        guard let jsonData = try? encoder.encode(container) else {
            NRLOG_DEBUG("Failed to encode events for URL generation")
            return
        }

        uncompressedDataSize += jsonData.count

    // BEGIN URL GENERATION
        // Generate upload URL that would be used if accumulated frames uploaded directly
        guard let uploadUrl = delegate?.generateUploadURL(
            uncompressedDataSize: uncompressedDataSize,
            firstTimestamp: firstTimestamp,
            lastTimestamp: lastTimestamp,
            isFirstChunk: isFirstChunk,
            isGZipped: true
        ) else {
            NRLOG_DEBUG("Failed to construct upload URL for session replay.")
            return
        }
        // END URL GENERATION


        // Save frame data and URL separately
        let agent = NewRelicAgentInternal.sharedInstance()
        let sessionId = agent?.currentSessionId() ?? "unknown_session"
        let frameFolder = self.framesDirectory.appendingPathComponent("\(sessionId)/")

        let urlFile = self.framesDirectory.appendingPathComponent("\(sessionId)_upload_url.txt")

        do {
            try FileManager.default.createDirectory(at: frameFolder, withIntermediateDirectories: true);
            let frameURL = frameFolder.appendingPathComponent("frame_\(frameCounter).json")
            try jsonData.write(to: frameURL)

            // Save/update URL separately
            try uploadUrl.absoluteString.write(to: urlFile, atomically: true, encoding: .utf8)
            
            // In Error mode, we need to track the file creation time for pruning
            if recordingMode == .error {
                let attributes = [FileAttributeKey.creationDate: Date()]
                try FileManager.default.setAttributes(attributes, ofItemAtPath: frameURL.path)
                
                // Prune old files if in ERROR mode
                pruneBufferedFiles(in: frameFolder)
            }

            frameCounter += 1
        } catch {
            NRLOG_DEBUG("Failed to append frame to filesystem: \(error)")
        }
    }
    
    // MARK: - Error Sampling Mode Management

    /// Sets the recording mode for session replay
    /// - Parameter mode: The new recording mode to use
    public func transistionToRecordingMode(_ mode: SessionReplayRecordingMode) {
        bufferLock.lock()
        defer { bufferLock.unlock() }

        let oldMode = recordingMode
        recordingMode = mode

        NRLOG_DEBUG("Session Replay recording mode changed from \(oldMode) to \(mode)")

        // Clear buffers when transitioning modes
        if mode == .off {
            errorModeBuffer.removeAll()
            lastFullSnapshotTime = nil
        }
        else if mode == .error {
            // When entering error mode, clear any existing frames
            lastFullSnapshotTime = Date()
        }
    }

    /// Transitions from error mode to full mode when an error is detected
    /// This flushes the 15-second error buffer to the main frame buffer
    public func transitionToFullModeOnError() {
        bufferLock.lock()
        defer { bufferLock.unlock() }

        guard recordingMode == .error else {
            NRLOG_DEBUG("transitionToFullModeOnError called but not in error mode")
            return
        }

        NRLOG_DEBUG("Session Replay transitioning to full mode due to error detection")

        // Flush the error buffer to the main frame buffer
        for bufferedFrame in errorModeBuffer {
            rawFrames.append(bufferedFrame.frame)

            // Process buffered frames to file for persistence
            DispatchQueue.global(qos: .background).async { [weak self] in
                guard let self = self else { return }
                self.processFrameToFile(bufferedFrame.frame)
            }
        }

        // Clear the error buffer as it's been flushed
        errorModeBuffer.removeAll()

        // Transition to full mode
        recordingMode = .full

        // Force next frame to be a full snapshot for clean transition
        sessionReplayFrameProcessor.takeFullSnapshotNext = true
    }

    /// Adds a frame to the error mode circular buffer, maintaining only the last 15 seconds
    private func addFrameToErrorBuffer(_ frame: SessionReplayFrame) {
        let bufferedFrame = BufferedReplayFrame(frame: frame, timestamp: frame.date)
        errorModeBuffer.append(bufferedFrame)

        // Remove frames older than 15 seconds
        let cutoffTime = frame.date.addingTimeInterval(-errorModeBufferDuration)
        errorModeBuffer.removeAll { $0.timestamp < cutoffTime }

        NRLOG_DEBUG("Error mode buffer: \(errorModeBuffer.count) frames (last \(errorModeBufferDuration)s)")
    }

    /// Checks if a full snapshot should be forced (every 15 seconds)
    private func checkAndForceFullSnapshot(for frame: SessionReplayFrame) {
        guard let lastSnapshot = lastFullSnapshotTime else {
            lastFullSnapshotTime = frame.date
            sessionReplayFrameProcessor.takeFullSnapshotNext = true
            return
        }

        let timeSinceLastSnapshot = frame.date.timeIntervalSince(lastSnapshot)
        if timeSinceLastSnapshot >= errorModeBufferDuration {
            NRLOG_DEBUG("Forcing full snapshot after 15 seconds")
            sessionReplayFrameProcessor.takeFullSnapshotNext = true
            lastFullSnapshotTime = frame.date
        }
    }

    
    private func pruneBufferedFiles(in folder: URL) {
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles)
            
            let now = Date()
            let maxBufferTime: TimeInterval = 15.0 // 15 seconds buffer
            
            for fileURL in fileURLs {
                if let creationDate = try fileURL.resourceValues(forKeys: [.creationDateKey]).creationDate {
                    if now.timeIntervalSince(creationDate) > maxBufferTime {
                        try FileManager.default.removeItem(at: fileURL)
                        NRLOG_DEBUG("Pruned old session replay file: \(fileURL.lastPathComponent)")
                    }
                }
            }
        }
        catch {
            NRLOG_DEBUG("Failed to prune buffered files: \(error)")
        }
    }
    
    // END Error Sampling Mode Management
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
