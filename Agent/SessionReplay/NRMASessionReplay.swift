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

    private let sessionReplayCapture: SessionReplayCapture
    private let sessionReplayFrameProcessor = SessionReplayFrameProcessor()
    private var sessionReplayTouchCapture: SessionReplayTouchCapture!
    private let sessionReplayTouchProcessor = TouchEventProcessor()
    private var frameTimer: Timer!
    private var rawFrames = [SessionReplayFrame]()
    public var windowDimensions = CGSize(width: 0, height: 0)

    private let rawFramesQueue = DispatchQueue(label: "com.newrelic.rawFramesQueue", attributes: .concurrent)

    private var NRMAOriginal__sendEvent: UnsafeMutableRawPointer?
        
    public override init() {
        self.sessionReplayCapture = SessionReplayCapture()
        
        super.init()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(didBecomeActive),
                                               name: UIApplication.didBecomeActiveNotification,
                                               object: nil)
    }
    
    public func start() {
        if isRunning() {
            NRLOG_WARNING("Session replay timer attempting to start while already running.")
            return
        }
        
        sessionReplayFrameProcessor.lastFullFrame = nil // We want to start a new session with no last Frame tracked
        
        self.frameTimer = Timer(timeInterval: 1.0, target: self, selector: #selector(takeFrame), userInfo: nil, repeats: true)
        RunLoop.current.add(self.frameTimer, forMode: .common)
    }
    
   public func stop() {
        if (!isRunning()) {
            NRLOG_WARNING("Session replay timer attempting to stop when not running.")
            return;
        }
        
       self.frameTimer.invalidate()
       self.frameTimer = nil
    }

    func isRunning() -> Bool {
        return self.frameTimer != nil && self.frameTimer!.isValid
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
        NRLOG_DEBUG("[SESSION REPLAY] - App did become active")
        guard let window = getWindow() else {
            NRLOG_ERROR("No key window found on didBecomeActive")
            return
        }
        self.sessionReplayTouchCapture = SessionReplayTouchCapture(window: window)
        windowDimensions.width = window.frame.width
        windowDimensions.height = window.frame.height
        swizzleSendEvent()
        start()
    }
    
    func takeFrame() {
        Task{
            guard let window = await getWindow() else {
                return
            }
            
            let frame = await sessionReplayCapture.recordFrom(rootView: window)
            addFrame(frame)
        }
    }

    func addFrame(_ frame: SessionReplayFrame) {
        rawFramesQueue.async(flags: .barrier) {
            self.rawFrames.append(frame)
        }
    }
    func getAndClearFrames() -> [SessionReplayFrame] {
        var frames = [SessionReplayFrame]()
        rawFramesQueue.sync {
            frames = self.rawFrames
        }
        rawFramesQueue.async(flags: .barrier) {
            self.rawFrames.removeAll()
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
    
    func getSessionReplayFrames() -> [RRWebEventCommon] {
        var processedFrames: [RRWebEventCommon] = []
        
        let frames = getAndClearFrames()
        processedFrames.append(contentsOf: (frames).map {
            self.sessionReplayFrameProcessor.processFrame($0)
        })

        return processedFrames
    }

    func getSessionReplayTouches() -> [IncrementalEvent] {
        let touches = sessionReplayTouchProcessor.processTouches(sessionReplayTouchCapture.touchEvents)
        sessionReplayTouchCapture.resetEvents()
        return touches
    }
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
