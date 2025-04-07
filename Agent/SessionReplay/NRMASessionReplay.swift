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
    private var rawFrames = [SessionReplayFrame]()
    
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
    
    func didBecomeActive() {
//        NRLOG_AUDIT("[SESSION REPLAY] - App did become active")

        start()
    }
    
    func takeFrame() {
        guard let window = getWindow() else {
            return
        }
        
        let frame = sessionReplayCapture.recordFrom(rootView: window)
        rawFrames.append(frame)
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

