//
//  SessionReplayFrameProcessor.swift
//  Agent_iOS
//
//  Created by Steve Malsam on 3/25/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation

struct SessionReplayFrameProcessor {
    
    func processFrame(_ frame: SessionReplayFrame) -> RRWebEvent {
        
        struct NodePair {
            let viewThingy: any SessionReplayViewThingy
            let rrwebNode: RRWebElementNode
        }
        
        var thingyStack = ContiguousArray<NodePair>()
        var cssString = ""
        
        let rootThingy = frame.views
        let rootRRWebNode = rootThingy.generateRRWebNode()

        thingyStack.append(NodePair(viewThingy: rootThingy, rrwebNode: rootRRWebNode))
        
        while let pair = thingyStack.popLast() {
            let viewThingy = pair.viewThingy
            let node = pair.rrwebNode
            
            var childNodes = [RRWebElementNode]()
            
            for childThingy in viewThingy.subviews {
                let childNode = childThingy.generateRRWebNode()
                childNodes.append(childNode)
                thingyStack.append(NodePair(viewThingy: childThingy, rrwebNode: childNode))
            }
            
            node.childNodes.append(contentsOf: childNodes)
            cssString.append(contentsOf: viewThingy.cssDescription())
        }
        
        let cssTextNode = RRWebTextNode(id: IDGenerator.shared.getId(),
                                    textContent: cssString,
                                    isStyle: true)
        
        let cssElementNode = RRWebElementNode(id: IDGenerator.shared.getId(),
                                              tagName: .style,
                                              attributes: [:],
                                              childNodes: [cssTextNode])
        
        let headElementNode = RRWebElementNode(id: IDGenerator.shared.getId(),
                                               tagName: .head,
                                               attributes: [:],
                                               childNodes: [cssElementNode])
        
        let bodyElementNode = RRWebElementNode(id: IDGenerator.shared.getId(),
                                               tagName: .body,
                                               attributes: [:],
                                               childNodes: [rootRRWebNode])
        
        let htmlElementNode = RRWebElementNode(id: IDGenerator.shared.getId(),
                                               tagName: .html,
                                               attributes: [:],
                                               childNodes: [headElementNode, bodyElementNode])
        
        let documentNode = RRWebDocumentNode(id: IDGenerator.shared.getId(),
                                             childNodes: [htmlElementNode])
        
        let snapshotData = FullSnapshotEvent.FullSnapshotData(initialOffset: FullSnapshotEvent.InitialOffset(top: 0, left: 0), node: documentNode)
        
        return FullSnapshotEvent(timestamp: frame.date.timeIntervalSince1970 * 1000,
                                             data: snapshotData)
        
    }
}
