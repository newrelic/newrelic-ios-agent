//
//  SessionReplayFrameProcessor.swift
//  Agent_iOS
//
//  Created by Steve Malsam on 3/25/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation

struct SessionReplayFrameProcessor {
    
    func processFrame(_ frame: SessionReplayFrame) -> RRWebEventCommon {
        
        struct NodePair {
            let viewThingy: any SessionReplayViewThingy
            let rrwebNode: ElementNodeData
        }
        
        var thingyStack = ContiguousArray<NodePair>()
        var cssString = ""
        
        let rootThingy = frame.views
        let rootRRWebNode = rootThingy.generateRRWebNode()

        thingyStack.append(NodePair(viewThingy: rootThingy, rrwebNode: rootRRWebNode))
        
        while let pair = thingyStack.popLast() {
            let viewThingy = pair.viewThingy
            let node = pair.rrwebNode
            
            var childNodes = [SerializedNode]()
            
            for childThingy in viewThingy.subviews {
                let childNode = childThingy.generateRRWebNode()
                childNodes.append(.element(childNode))
                thingyStack.append(NodePair(viewThingy: childThingy, rrwebNode: childNode))
            }
            
            node.childNodes.append(contentsOf: childNodes)
            cssString.append(contentsOf: viewThingy.cssDescription())
        }
        
        let cssTextNode = TextNodeData(id: IDGenerator.shared.getId(),
                                       isStyle: true,
                                       textContent: cssString,
                                       childNodes: [])
        
        let cssElementNode = ElementNodeData(id: IDGenerator.shared.getId(),
                                             tagName: .style,
                                             attributes: [:],
                                             childNodes: [.text(cssTextNode)])
        
        let headElementNode = ElementNodeData(id: IDGenerator.shared.getId(),
                                              tagName: .head,
                                              attributes: [:],
                                              childNodes: [.element(cssElementNode)])
        
        let bodyElementNode = ElementNodeData(id: IDGenerator.shared.getId(),
                                              tagName: .body,
                                              attributes: [:],
                                              childNodes: [.element(rootRRWebNode)])
        
        let htmlElementNode = ElementNodeData(id: IDGenerator.shared.getId(),
                                              tagName: .html,
                                              attributes: [:],
                                              childNodes: [.element(headElementNode), .element(bodyElementNode)])
        
        let documentNode = DocumentNodeData(id: IDGenerator.shared.getId(),
                                            childNodes: [.element(htmlElementNode)])
        
        let snapshotData = RRWebFullSnapshotData(node: .document(documentNode),
                                                 initialOffset: RRWebFullSnapshotData.InitialOffset(top: 0, left: 0))
        
        return RRWebEvent(timestamp: frame.date.timeIntervalSince1970 * 1000, data: snapshotData)
    }
}
