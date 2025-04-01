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
    private var frameTimer: Timer!
    private var rawFrames = [SessionReplayFrame]()
    
//    private let sessionReplayLogger = Log
    
    public override init() {
        self.sessionReplayCapture = SessionReplayCapture()
        
        super.init()
        
        self.frameTimer = Timer(timeInterval: 0.5, repeats: true, block: { [weak self] timer in
            guard let self else {return}
            takeFrame()
        })
        
//        let supportability = SupportabilityMetrics()
//        supportability.createExceptionMetric()
//        NRMATaskQueue.queue(NRMAMetric(name: "A name", value: 1, scope: ""))


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
        
        if(rawFrames.count > 10) {
            let metaEvent = MetaEvent(timestamp: Date().timeIntervalSince1970 * 1000, data: MetaEvent.MetaEventData(href: "http://newrelic.com", width: Int(getWindow()?.frame.width ?? 0), height: Int(getWindow()?.frame.height ?? 0)))
            
            var processedFrames: [RRWebEvent] = [metaEvent]
            processedFrames.append(contentsOf: rawFrames.map {sessionReplayFrameProcessor.processFrame($0)})
            
            let container = EncodableFramesContainer(items: processedFrames)
            
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

struct EncodableFramesContainer: Encodable {
    let items: [any RRWebEvent]
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        for item in items {
            try container.encode(item)
        }
    }
}
