//
//  Untitled.swift
//  Agent
//
//  Created by Mike Bruin on 4/1/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation

class SessionReplayFrameProcessor {
    private var rootNode: [String: Any] = [:]
    private var styleNode: [String: Any] = [:]
    private var bodyNode: [String: Any] = ["childNodes": [Any]()]

    func process(frame: SessionReplayFrame) -> [String: Any] {
        generateInitialBoilerplate(withTimestamp: frame.date.millisecondsSince1970)
        
        var css = ""
        
        for view in frame.views {
           /* css += view.cssDescription()
            if var childNodes = bodyNode["childNodes"] as? [Any] {
                childNodes.append(view.jsonDescription)
                bodyNode["childNodes"] = childNodes
            }*/
        }
        
        return rootNode
    }
    
    private func generateInitialBoilerplate(withTimestamp timestamp: Int64) {
        rootNode = [
            "timestamp": timestamp,
            "styleNode": styleNode,
            "bodyNode": bodyNode
        ]
    }
}
