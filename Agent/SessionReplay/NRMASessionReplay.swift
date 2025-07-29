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
    private var sessionReplayTouchCapture: SessionReplayTouchCapture!
    private let sessionReplayTouchProcessor = TouchEventProcessor()
    private var rawFrames = [SessionReplayFrame]()
    
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

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.framesDirectory = documentsPath.appendingPathComponent("SessionReplayFrames")

        super.init()

        try? FileManager.default.createDirectory(at: framesDirectory, withIntermediateDirectories: true)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(didBecomeActive),
                                               name: UIApplication.didBecomeActiveNotification,
                                               object: nil)
    }

    public func start() {

        sessionReplayFrameProcessor.lastFullFrame = nil // We want to start a new session with no last Frame tracked
    }

    public func stop() {

    }
    
    public func clearAllData() {
        rawFrames.removeAll()
        sessionReplayTouchCapture.resetEvents()
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
                NRLOG_ERROR("Failed to clear frames directory: \(error)")
            }
        }
    }

    func swizzleSendEvent() {
        DispatchQueue.once(token: "com.newrelic.swizzleSendEvent") {
            guard let clazz = objc_getClass("UIApplication") else {
                NRLOG_ERROR("ERROR: Unable to swizzle send event. Not able to track touches")
                return
            }

            let originalSelector = #selector(UIApplication.sendEvent(_:))

            let block: @convention(block)(UIApplication, UIEvent) -> Void = { app, event in
                self.sessionReplayTouchCapture.captureSendEventTouches(event: event)
                typealias Func = @convention(c)(AnyObject, Selector, UIEvent) -> Void
                let function = unsafeBitCast(self.NRMAOriginal__sendEvent, to: Func.self)
                function(app, originalSelector, event)
            }

            let newImp = imp_implementationWithBlock(block)

            self.NRMAOriginal__sendEvent = NRMAReplaceInstanceMethod(clazz as? AnyClass, originalSelector, newImp)
        }
    }

    @MainActor
    @objc func didBecomeActive() {
        //NRLOG_DEBUG("[SESSION REPLAY] - App did become active")
        guard let window = getWindow() else {
            NRLOG_DEBUG("No key window found on didBecomeActive")
            return
        }
        self.sessionReplayTouchCapture = SessionReplayTouchCapture(window: window)
        swizzleSendEvent()
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
        self.rawFrames.append(frame)


        // BEGIN PROCESSING FRAME TO FILE
        // Process frame to file
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }

            self.processFrameToFile(frame)
        }

        // END PROCESSING FRAME TO FILE
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
                    NRLOG_ERROR("Failed to clear frames directory: \(error)")
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
            sessionReplayTouchCapture.resetEvents()
        }
        return touches
    }


    /// REPLAY PERSISTENCE


    func processFrameToFile(_ frame: SessionReplayFrame) {
        // Fetch processed frame and touches during frame
        let processedFrame = self.sessionReplayFrameProcessor.processFrame(frame)
        let processedTouches = self.getSessionReplayTouches(clear: false)

        guard let firstFrame = rawFrames.first else {
            return
        }
        let firstTimestamp: TimeInterval = TimeInterval(firstFrame.date.timeIntervalSince1970 * 1000).rounded()
        let lastTimestamp: TimeInterval = TimeInterval(processedFrame.timestamp)

        var container: [AnyRRWebEvent] = []

        let metaEventData = RRWebMetaData(
            href: "http://newrelic.com",
            width: Int(frame.size.width),
            height: Int(frame.size.height)
        )
        let metaEvent = MetaEvent(timestamp: TimeInterval(firstTimestamp), data: metaEventData)
        container.append(AnyRRWebEvent(metaEvent))

        container.append(AnyRRWebEvent(processedFrame))

        container.append(contentsOf: (processedTouches).map {
            AnyRRWebEvent($0)
        })

        // Extract URL generation logic from createReplayUpload
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes

        // Encode container to get data size for URL generation
        guard let jsonData = try? encoder.encode(container) else {
            NRLOG_ERROR("Failed to encode events for URL generation")
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
            NRLOG_ERROR("Failed to construct upload URL for session replay.")
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

            if frameCounter % 10 == 0 {
                NRLOG_DEBUG("SessionReplay - Frame \(frameCounter) processed and written to \(frameURL.path)")
            }

            frameCounter += 1
        } catch {
            NRLOG_ERROR("Failed to append frame to filesystem: \(error)")
        }
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

