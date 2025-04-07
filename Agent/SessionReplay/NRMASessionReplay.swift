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

@available(iOS 13.0, *)
@objcMembers
public class NRMASessionReplay: NSObject {
    
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
}
