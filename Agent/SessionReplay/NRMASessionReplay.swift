//
//  NRMASessionReplay.swift
//  Agent_iOS
//
//  Created by Steve Malsam on 1/30/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation
import UIKit
import NewRelicPrivate

import OSLog

protocol NRMASessionReplayDelegate: AnyObject {
    func didReachDataSizeLimit()
}

@available(iOS 13.0, *)
@objcMembers
public class NRMASessionReplay: NSObject {
    weak var delegate: NRMASessionReplayDelegate?

    private let sessionReplayCapture: SessionReplayCapture
    private let sessionReplayFrameProcessor = SessionReplayFrameProcessor()
    private var sessionReplayTouchCapture: SessionReplayTouchCapture!
    private let sessionReplayTouchProcessor = TouchEventProcessor()
    private var frameTimer: Timer!
    private var rawFrames = [SessionReplayFrame]()
    
    private var NRMAOriginal__sendEvent: UnsafeMutableRawPointer?
        
    public override init() {
        self.sessionReplayCapture = SessionReplayCapture()
        
        super.init()
     
        self.frameTimer = Timer(timeInterval: 0.5, repeats: true, block: { [weak self] timer in
            guard let self else {return}
            takeFrame()
        })

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(didBecomeActive),
                                               name: UIApplication.didBecomeActiveNotification,
                                               object: nil)
    }
    
    public func start() {
        if isRunning() {
            print("Session replay timer attempting to start while already running.")
            return
        }

        self.frameTimer = Timer(timeInterval: 1.0, target: self, selector: #selector(takeFrame), userInfo: nil, repeats: true)
        RunLoop.current.add(self.frameTimer, forMode: .common)
        RunLoop.current.run()
    }
    
   public func stop() {
        if (!isRunning()) {
            print("Session replay timer attempting to stop when not running.")
            return;
        }
        
       self.frameTimer.invalidate()
       self.frameTimer = nil
    }

    func isRunning() -> Bool {
        return self.frameTimer != nil && self.frameTimer!.isValid
    }
  
      func swizzleSendEvent() {
        guard let clazz = objc_getClass("UIApplication") else {
            os_log("ERROR: Unable to swizzle send event. Not able to track touches")
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
    
    func didBecomeActive() {
//        NRLOG_AUDIT("[SESSION REPLAY] - App did become active")
        self.sessionReplayTouchCapture = SessionReplayTouchCapture(window: getWindow()!)
        swizzleSendEvent()
        RunLoop.current.add(self.frameTimer, forMode: .common)
    }
    
    func takeFrame() {
        guard let window = getWindow() else {
            return
        }
        
        let frame = sessionReplayCapture.recordFrom(rootView: window)
        rawFrames.append(frame)

        if(rawFrames.count > 10) {
            let metaEventData = RRWebMetaData(href: "http://newrelic.com", width: Int(getWindow()?.frame.width ?? 0), height: Int(getWindow()?.frame.height ?? 0))
            let metaEvent = MetaEvent(timestamp: Date().timeIntervalSince1970 * 1000, data: metaEventData)
            var container: [AnyRRWebEvent] = [AnyRRWebEvent(metaEvent)]
            
            container.append(contentsOf: rawFrames.map { AnyRRWebEvent(sessionReplayFrameProcessor.processFrame($0))})
            
            let processedTouches = sessionReplayTouchProcessor.processTouches(sessionReplayTouchCapture.touchEvents)
            container.append(contentsOf: processedTouches.map { AnyRRWebEvent($0)})
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = []
            let jsonData = try? encoder.encode(container)
            
            if let data = jsonData,
               let jsonString = String(data: data, encoding: .utf8){
                NSLog(jsonString)
            }
        }
    }
    
    // maybe move this into something else?
    private func getWindow() -> UIWindow? {
        UIApplication
            .shared
            .connectedScenes
            .compactMap {$0 as? UIWindowScene}
            .flatMap { $0.windows }
            .last { $0.isKeyWindow }
    }
    
    func getSessionReplayFrames() -> [SessionReplayFrame] {
        let data = rawFrames
        rawFrames.removeAll()
        
        return data
    }
}

extension Date {
    var millisecondsSince1970:Int64 {
        Int64((self.timeIntervalSince1970 * 1000.0).rounded())
    }
    
    init(milliseconds:Int64) {
        self = Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
    }
}

