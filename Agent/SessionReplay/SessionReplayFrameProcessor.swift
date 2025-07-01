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
    
    
    func processFrame(_ frame: SessionReplayFrame) -> RRWebEventCommon {
        // If we have a full snapshot, compare the rootViewControllerIDs. If they match, just do a partial one
        // If they don't, or there is no last snapshot, then do a full snapshot.
        
        var rrwebCommon: any RRWebEventCommon
        if frame.rootViewControllerId != lastFullFrame?.rootViewControllerId ||
            frame.views.viewDetails.viewId != lastFullFrame?.views.viewDetails.viewId ||
            frame.size != lastFullFrame?.size {
            rrwebCommon = processFullSnapshot(frame)
        } else if let lastFullFrame = lastFullFrame {
            rrwebCommon = processIncrementalSnapshot(newFrame: frame, oldFrame: lastFullFrame)
        } else {
            // We don't have anything, so just do a full snapshot
            rrwebCommon = processFullSnapshot(frame)
        }
        
        lastFullFrame = frame
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
        
        return RRWebEvent(timestamp: frame.date.timeIntervalSince1970 * 1000, data: snapshotData)
    }
    
    
    private func processIncrementalSnapshot(newFrame: SessionReplayFrame, oldFrame: SessionReplayFrame) -> any RRWebEventCommon {
        
        let oldFlattenedThingies = flattenTree(rootThingy: oldFrame.views)
        let newFlattenedThingies = flattenTree(rootThingy: newFrame.views)
        
        let operations = generateDiff(old: oldFlattenedThingies, new: newFlattenedThingies)

        
        var adds = [RRWebMutationData.AddRecord]()
        var removes = [RRWebMutationData.RemoveRecord]()
        var texts = [RRWebMutationData.TextRecord]()
        var attributes = [RRWebMutationData.AttributeRecord]()
        
        for operation in operations {
            switch operation {
            case .Remove(let change):
                removes.append(RRWebMutationData.RemoveRecord(parentId: change.parentId, id: change.id))
                
            case .Add(let change):
                let nodes = change.node.generateRRWebAdditionNode(parentNodeId: change.parentId)
                adds.append(contentsOf: nodes)
            case .Update(let change):
                let mutations = change.oldElement.generateDifference(from: change.newElement)
                for mutation in mutations {
                    switch mutation {
                    case let mutation as RRWebMutationData.AttributeRecord:
                        attributes.append(mutation)
                    case let mutation as RRWebMutationData.TextRecord:
                        texts.append(mutation)
                    default:
                        // ignore it.
                        continue
                    }
                }
            }
        }
        
        let incrementalUpdate: RRWebIncrementalData = .mutation(RRWebMutationData(adds: adds, removes: removes, texts: texts, attributes: attributes))
        let incrementalEvent = IncrementalEvent(timestamp: newFrame.date.timeIntervalSince1970*1000, data: incrementalUpdate)
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
    
    private func flattenTree(rootThingy: any SessionReplayViewThingy) -> [any SessionReplayViewThingy] {
        var thingies: [any SessionReplayViewThingy] = []
        var queue: [any SessionReplayViewThingy] = [rootThingy]
        
        while let thingy = queue.popLast() {
            thingies.append(thingy)
            queue.append(contentsOf: thingy.subviews)
        }
        
        return thingies
    }
}
