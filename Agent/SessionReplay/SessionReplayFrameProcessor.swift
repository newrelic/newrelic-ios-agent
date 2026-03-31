//
//  SessionReplayFrameProcessor.swift
//  Agent_iOS
//
//  Created by Steve Malsam on 3/25/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation

class SessionReplayFrameProcessor {
    var lastFullFrame: SessionReplayFrame? = nil
    var useIncrementalDiffs = true

    var takeFullSnapshotNext = true

    // Private queue for thread-safe tree operations
    private let treeProcessingQueue = DispatchQueue(label: "com.newrelic.sessionreplay.tree.processing", qos: .userInitiated)
    
    
    func processFrame(_ frame: SessionReplayFrame, readOnly: Bool = false) -> RRWebEventCommon? {
        guard useIncrementalDiffs else { // If useIncrementalDiffs is false, we only take full snapshots
            if !readOnly {
                self.lastFullFrame = frame
            }
            return processFullSnapshot(frame)
        }
        
        // If there is no last frame, always take a full snapshot
        guard let lastFullFrame = lastFullFrame else {
            if !readOnly {
                takeFullSnapshotNext = false
                self.lastFullFrame = frame
            }
            return processFullSnapshot(frame)
        }
        
        var rrwebCommon: (any RRWebEventCommon)?
        // If a full snapshot is needed, frame size changed, UILayoutContainerView count increased,
        // or the NavigationStack depth changed.
        if takeFullSnapshotNext || frame.size != lastFullFrame.size ||
            (frame.layoutContainerViewCount > 1 && frame.layoutContainerViewCount > lastFullFrame.layoutContainerViewCount) ||
            frame.navigationStackDepth != lastFullFrame.navigationStackDepth {
            rrwebCommon = processFullSnapshot(frame)
            if !readOnly {
                
                takeFullSnapshotNext = false
            }
        } else {
            rrwebCommon = processIncrementalSnapshot(newFrame: frame, oldFrame: lastFullFrame)
            if !readOnly {
                
                takeFullSnapshotNext = false
            }
        }
        // If we have a full snapshot, compare the rootViewControllerIDs. If they match, continue with partial snapshots
        // If they don't, then do a full snapshot next time.
        if frame.rootViewControllerId != lastFullFrame.rootViewControllerId ||
            frame.views.viewDetails.viewId != lastFullFrame.views.viewDetails.viewId ||
            frame.rootSwiftUIViewId != lastFullFrame.rootSwiftUIViewId {
            if !readOnly {
                
                takeFullSnapshotNext = true // When the viewController transitions there is a frame where they are combined so take the full snapshot after things have settled.
            }
        }
        
        if !readOnly {
            
            self.lastFullFrame = frame
        }
        return rrwebCommon
    }
    
    private func processFullSnapshot(_ frame: SessionReplayFrame) -> any RRWebEventCommon {
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
        
        let documentTypeNode = DocumentTypeNodeData(id: IDGenerator.shared.getId(), name: .html, publicId: "", systemId: "")
        
        let documentNode = DocumentNodeData(id: IDGenerator.shared.getId(),
                                            childNodes: [.documentType(documentTypeNode), .element(htmlElementNode)])
        
        let snapshotData = RRWebFullSnapshotData(node: .document(documentNode),
                                                 initialOffset: RRWebFullSnapshotData.InitialOffset(top: 0, left: 0))
        
        return RRWebEvent(timestamp: (frame.date.timeIntervalSince1970 * 1000).rounded(), data: snapshotData)
    }
    
    
    private func processIncrementalSnapshot(newFrame: SessionReplayFrame, oldFrame: SessionReplayFrame) -> (any RRWebEventCommon)? {
        // Validate input parameters
        guard newFrame.date >= oldFrame.date else {
            // If frames are out of order, fall back to full snapshot
            return processFullSnapshot(newFrame)
        }
        
        // Safely flatten trees with thread safety and error handling
        var oldFlattenedThingies: [any SessionReplayViewThingy] = []
        var newFlattenedThingies: [any SessionReplayViewThingy] = []

        treeProcessingQueue.sync {
            oldFlattenedThingies = flattenTree(rootThingy: oldFrame.views)
            newFlattenedThingies = flattenTree(rootThingy: newFrame.views)
        }

        // If flattening failed or returned empty results, fall back to full snapshot
        guard !oldFlattenedThingies.isEmpty && !newFlattenedThingies.isEmpty else {
            print("Warning: flattenTree returned empty results, falling back to full snapshot")
            return processFullSnapshot(newFrame)
        }
        
        let operations = generateDiff(old: oldFlattenedThingies, new: newFlattenedThingies)
        
        // Pre-allocate arrays with estimated capacity for better performance
        let operationCount = operations.count
        var adds = [RRWebMutationData.AddRecord]()
        var removes = [RRWebMutationData.RemoveRecord]()
        var texts = [RRWebMutationData.TextRecord]()
        var attributes = [RRWebMutationData.AttributeRecord]()
        
        adds.reserveCapacity(operationCount)
        removes.reserveCapacity(operationCount)
        
        // Process operations in a single pass with improved type safety
        for operation in operations {
            switch operation {
            case .Remove(let change):
                removes.append(RRWebMutationData.RemoveRecord(parentId: change.parentId, id: change.id))
                
            case .Add(let change):
                let nodes = change.node.generateRRWebAdditionNode(parentNodeId: change.parentId)
                adds.append(contentsOf: nodes)
            case .Update(let change):
                processMutationUpdates(oldElement: change.oldElement,
                                     newElement: change.newElement,
                                     texts: &texts,
                                     attributes: &attributes)
            }
        }
        
        let incrementalUpdate: RRWebIncrementalData = .mutation(RRWebMutationData(adds: adds, removes: removes, texts: texts, attributes: attributes))
        
        if adds.isEmpty && removes.isEmpty && texts.isEmpty && attributes.isEmpty {
            return nil
        }
        
        let incrementalEvent = IncrementalEvent(timestamp: (newFrame.date.timeIntervalSince1970 * 1000).rounded(), data: incrementalUpdate)
        return incrementalEvent
        
//         For nodes that have not been added/removed, we should get the difference they've got as a dictionary (that can be turned into JSON
//           {
//        "type": 3,
//        "data": {
//          "source": 0,
//          "texts": [],
//          "attributes": [
//            {
//              "id": 16,
//              "attributes": {
//                "style": {
//                  "background-color": "blue",
//                  "left": "0.00px",
//                  "top": "200px"
//                }
//              }
//            }
//          ],
//          "removes": [],
//          "adds": []
//        },
//        "timestamp": 1744394410366.966
//      },
        
        // We can record changes in the Thingies, that are not complete replacements, as attribute changes. There is also a TextUpdate, which can be used just for text changes.
        // We could have each Thingy return an array of changes. If it's just a visual change, it would be a one thing array. If it's thing like a UILabel, and it could have both visual
        // and text changes, it could return two: an attribute change, and a text change.
        
//        {
//            "parentId": 66,
//            "nextId": 70,
//            "node": {
//                "type": 2,
//                "tagName": "div",
//                "attributes": {
//                    "role": "separator",
//                    "aria-orientation": "horizontal",
//                    "class": "-mx-1 my-1 h-px bg-muted"
//                },
//                "childNodes": [],
//                "id": 71
//            }
//        },
        
        // Adds are a list of nodes to insert. It doesn't appear as if any of the inserted nodes have any child nodes, however, nodes listed after can say they are a parent node of
        // one listed here. It is a regular node like is presented in the full snapshot. However, it should have the id of it's parent. This is something that should be added
        // to the Thingy, or the ViewDetails.
        
//        "removes": [
//            {
//                "parentId": 100,
//                "id": 173
//            },
//            {
//                "parentId": 100,
//                "id": 171
//            },
//            {
//                "parentId": 100,
//                "id": 172
//            },
//            {
//                "parentId": 79,
//                "id": 169
//            }
//        ]
        
        // Removes are a very simple list of the node to be removed, and it's parent.
        
//        "texts": [
//            {
//                "id": 146,
//                "value": "🛑 Stop recording"
//            }
//        ]
        
        // Texts are the id of the text node, and the content to change it to.
        

    }
    
    /// Helper function to process mutation updates with improved type safety
    private func processMutationUpdates(oldElement: any SessionReplayViewThingy,
                                      newElement: any SessionReplayViewThingy,
                                      texts: inout [RRWebMutationData.TextRecord],
                                      attributes: inout [RRWebMutationData.AttributeRecord]) {
        let mutations = oldElement.generateDifference(from: newElement)
        
        for mutation in mutations {
            if let attributeRecord = mutation as? RRWebMutationData.AttributeRecord {
                attributes.append(attributeRecord)
            } else if let textRecord = mutation as? RRWebMutationData.TextRecord {
                texts.append(textRecord)
            }
        }
    }
    
    private func flattenTree(rootThingy: any SessionReplayViewThingy) -> [any SessionReplayViewThingy] {
        var thingies: [any SessionReplayViewThingy] = []
        var queue: [any SessionReplayViewThingy] = [rootThingy]
        var visited = Set<AnyHashable>() // Track visited nodes to prevent infinite loops

        // Reserve capacity for better performance
        thingies.reserveCapacity(100) // Conservative initial estimate
        visited.reserveCapacity(100)

        while let thingy = queue.popLast() {
            // Prevent infinite loops from circular references
            guard !visited.contains(AnyHashable(thingy)) else {
                continue
            }

            visited.insert(AnyHashable(thingy))
            thingies.append(thingy)

            queue.append(contentsOf: thingy.subviews)
        }

        return thingies
    }
}
