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
    private var frameTimer: Timer!
    private let rawFrames = [SessionReplayFrame]()
    
    private var touchCapture: SessionReplayTouchCapture!
    private let sessionReplayFrameProcessor = SessionReplayFrameProcessor()
    private var processedFrames = NSMutableArray()
    private let processQueue = DispatchQueue(label: "com.newrelicagent.sessionreplayqueue")
    
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
            print("Session replay timer attempting to start while already running.")
            return
        }

        self.frameTimer = Timer(timeInterval: 1.0, target: self, selector: #selector(takeFrame), userInfo: nil, repeats: true)
        RunLoop.current.add(self.frameTimer, forMode: .common)

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
    
    func didBecomeActive() {
//        NRLOG_AUDIT("[SESSION REPLAY] - App did become active")
        self.touchCapture = SessionReplayTouchCapture(window: getWindow()!)

        start()
    }
    
    func takeFrame() {
        guard let window = getWindow() else {
            return
        }
        
        let frame = sessionReplayCapture.recordFrom(rootView: window)
/*<<<<<<< NR-378712
        if processedFrames.count == 0 {
            objc_sync_enter(processedFrames)
            processedFrames.add(sessionReplayFrameProcessor.process(frame: frame));
            objc_sync_exit(processedFrames)
            return
        }
        checkCompressedDataSize(frame: frame)
    }
    
    func checkCompressedDataSize(frame: SessionReplayFrame) {
        processQueue.async { [weak self] in
            guard let self = self else { return }

            // Check the size of compressed data
            guard let jsonData = self.currentFramesData().gzipped() else {
                return
            }

            guard let newFrameJSONData = try? JSONSerialization.data(withJSONObject: self.sessionReplayFrameProcessor.process(frame: frame), options: []) else {
                return
            }

            let sizeInBytes = jsonData.count + newFrameJSONData.count
            let sizeInMB = Double(sizeInBytes) / (1024.0 * 1024.0)
            print(sizeInMB)

            if sizeInMB >= 1.0 {
                self.delegate?.didReachDataSizeLimit()
            }

            objc_sync_enter(self.processedFrames)
            self.processedFrames.add(self.sessionReplayFrameProcessor.process(frame: frame))
            objc_sync_exit(self.processedFrames)
=======*/
        rawFrames.append(frame)
        
        if(rawFrames.count > 10) {
            let metaEventData = RRWebMetaData(href: "http://newrelic.com", width: Int(getWindow()?.frame.width ?? 0), height: Int(getWindow()?.frame.height ?? 0))
            let metaEvent = MetaEvent(timestamp: Date().timeIntervalSince1970 * 1000, data: metaEventData)
            var container: [AnyRRWebEvent] = [AnyRRWebEvent(metaEvent)]
            
            container.append(contentsOf: rawFrames.map { AnyRRWebEvent(sessionReplayFrameProcessor.processFrame($0))})
            
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
    
    func getSessionReplayJSONData() throws -> Data? {
        var data: Data?
        
        data = currentFramesData()
        objc_sync_enter(processedFrames)

        processedFrames.removeAllObjects()
        
        objc_sync_exit(processedFrames)
        
        return data
    }

    func consolidateFrames() -> String {
        let viewFramesJSONData = currentFramesData()
        let frameJSON = String(data: viewFramesJSONData, encoding: .utf8) ?? ""
        return frameJSON
    }

    func currentFramesData() -> Data {
        objc_sync_enter(processedFrames)
        defer { objc_sync_exit(processedFrames) }
        
        let jsonData = try? JSONSerialization.data(withJSONObject: processedFrames, options: [])
        return jsonData ?? Data()
    }
    
    /*func processTouches() {
        for touchTracker in trackedTouches {
            let touch = touchTracker.jsonDescription();
            processedFrames.append(touch)
        }
    }*/
}

extension Date {
    var millisecondsSince1970:Int64 {
        Int64((self.timeIntervalSince1970 * 1000.0).rounded())
    }
    
    init(milliseconds:Int64) {
        self = Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
    }
}

