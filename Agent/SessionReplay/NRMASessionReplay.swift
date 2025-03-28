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

@available(iOS 13.0, *)
@objcMembers
public class NRMASessionReplay: NSObject {
    
    private let sessionReplayCapture: SessionReplayCapture
    private var frameTimer: Timer!
    private var rawFrames = [SessionReplayFrame]()
    
    public override init() {
        self.sessionReplayCapture = SessionReplayCapture()
        
        super.init()
        
        self.frameTimer = Timer(timeInterval: 1.0, repeats: true, block: { [weak self] timer in
            guard let self else {return}
            takeFrame()
        })
        
        let supportability = SupportabilityMetrics()
        supportability.createExceptionMetric()
        NRMATaskQueue.queue(NRMAMetric(name: "A name", value: 1, scope: ""))


        NotificationCenter.default.addObserver(self,
                                               selector: #selector(didBecomeActive),
                                               name: UIApplication.didBecomeActiveNotification,
                                               object: nil)
    }
    
    func didBecomeActive() {
//        NRLOG_AUDIT("[SESSION REPLAY] - App did become active")
        
        RunLoop.current.add(self.frameTimer, forMode: .common)
        
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
}
