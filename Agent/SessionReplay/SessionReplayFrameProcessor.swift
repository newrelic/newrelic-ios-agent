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
            frame.views.viewDetails.viewId != lastFullFrame?.views.viewDetails.viewId {
            rrwebCommon = processFullSnapshot(frame)
//        } else if let lastFullFrame = lastFullFrame{
//            rrwebCommon = processIncrementalSnapshot(newFrame: frame, oldFrame: lastFullFrame)
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
        
        let documentNode = DocumentNodeData(id: IDGenerator.shared.getId(),
                                            childNodes: [.element(htmlElementNode)])
        
        let snapshotData = RRWebFullSnapshotData(node: .document(documentNode),
                                                 initialOffset: RRWebFullSnapshotData.InitialOffset(top: 0, left: 0))
        
        return RRWebEvent(timestamp: frame.date.timeIntervalSince1970 * 1000, data: snapshotData)
    }
    
    
    private func processIncrementalSnapshot(newFrame: SessionReplayFrame, oldFrame: SessionReplayFrame) -> any RRWebEventCommon {
        
        let oldFlattenedThingies = flattenTree(rootThingy: oldFrame.views)
        let newFlattenedThingies = flattenTree(rootThingy: newFrame.views)
        
        var table: [Int: Symbol] = [:]
        
        // Go through the arrays according to Heckel's Algorithm. Since each thingy is only going to appear once,
        // we don't have to worry about things being "many".
        class Symbol {
            var inNew: Bool
            var indexInOld: Int?
            
            init(inNew: Bool, indexInOld: Int? = nil) {
                self.inNew = inNew
                self.indexInOld = indexInOld
            }
        }
        
        enum Entry {
            case symbol(Symbol)
            case index(Int)
        }
        
        var newArrayEntries = [Entry]()
        var oldArrayEntries = [Entry]()
        
        // Pass One: Each element of the New array is gone through, and an entry in the table made for each thing
        for thingy in newFlattenedThingies {
            let entry = Symbol(inNew: true, indexInOld: nil)
            table[thingy.viewDetails.viewId] = entry
            newArrayEntries.append(.symbol(entry))
        }
        
        //Pass Two: Each element of the Old array is gone through, and an entry in the table made for each thing
        for (index, thingy) in oldFlattenedThingies.enumerated() {
            var entry: Symbol?
            if table[thingy.viewDetails.viewId] == nil {
                entry = Symbol(inNew: false, indexInOld: index)
                table[thingy.viewDetails.viewId] = entry
            } else {
                table[thingy.viewDetails.viewId]?.indexInOld = index
                entry = table[thingy.viewDetails.viewId]
            }
            
            if let entry = entry {
                oldArrayEntries.append(.symbol(entry))
            }
        }
        
        //Pass Three: Use the first observation. If an entry occurs only once in each list, it must be the same
        // entry, although it could have been moved. Cross reference the two
        for (index, item) in newArrayEntries.enumerated() {
            if case let .symbol(entry) = item {
                if entry.inNew, let indexInOld = entry.indexInOld {
                    newArrayEntries[index] = .index(indexInOld)
                    oldArrayEntries[indexInOld] = .index(index)
                }
            }
        }
        
        // Pass Four: Use the next observation. If NewArray[i] points to OldArray[j] and NewArray[i+1] and OldArray[j+1]
        // contain identical symbol table entries, then OldArray[j+1] is set to line i+1 and NewArray[i+1] is set to
        // line j+1
        if newArrayEntries.count > 1 {
            for i in (0 ..< (newArrayEntries.count - 1)) {
                if case let .index(j) = newArrayEntries[i], j + 1 < oldArrayEntries.count,
                   case let .symbol(newEntry) = newArrayEntries[i + 1],
                   case let .symbol(oldEntry) = oldArrayEntries[j + 1],
                   newEntry === oldEntry {
                    newArrayEntries[i + 1] = .index(j + 1)
                    oldArrayEntries[j + 1] = .index(i + 1)
                }
            }
        }
        
        // Pass Five: Same as Pass 4, but in reverse!
        if newArrayEntries.count > 1 {
            for i in (1 ..< newArrayEntries.count).reversed() {
                if case let .index(j) = newArrayEntries[i], j - 1 >= 0,
                   case let .symbol(newEntry) = newArrayEntries[i - 1],
                   case let .symbol(oldEntry) = oldArrayEntries[j - 1],
                   newEntry === oldEntry {
                    newArrayEntries[i - 1] = .index(j - 1)
                    oldArrayEntries[j - 1] = .index(i - 1)
                }
            }
        }
        
        enum Operation {
            case Add(AddChange)
            case Remove(RemoveChange)
            case Text(TextChange)
            case Attribute(AttributeChange)
        }
        
        struct RemoveChange {
            let parentId: Int
            let id: Int
        }
        
        struct TextChange {
            let id: Int
            let value: String
        }
        
        struct AttributeChange {
            let id: Int
            let attributes: [String: String]
        }
        
        struct AddChange {
            let parentId: Int
            let id: Int?
            let node: SessionReplayViewThingy
        }
        
        var changes = [Operation]()
        
        // get removals
        var deleteOffsets = Array(repeating: 0, count: oldArrayEntries.count)
        var runningOffset = 0
        for(index, entry) in oldArrayEntries.enumerated() {
            deleteOffsets[index] = runningOffset
            if case .symbol = entry {
                changes.append(.Remove(RemoveChange(parentId: 0, id: oldFlattenedThingies[index].viewDetails.viewId)))
                runningOffset += 1
            }
        }
        
        runningOffset = 0
        
        // Get Additions and Alterations
        for (index, entry) in newArrayEntries.enumerated() {
            switch entry {
            case .symbol:
                changes.append(.Add(AddChange(parentId: 0, id: newFlattenedThingies[index].viewDetails.viewId, node: newFlattenedThingies[index])))
                runningOffset += 1
                
            case .index(let indexInOld):
                let deleteOffset = deleteOffsets[index]
                let newElement = newFlattenedThingies[index]
                let oldElement = oldFlattenedThingies[index]
                
                
                if (indexInOld - deleteOffset + runningOffset) != index {
                    // If this doesn't get us to where we currently are, then the thing was moved
                    changes.append(.Remove(RemoveChange(parentId: 0, id: newFlattenedThingies[index].viewDetails.viewId)))
                    changes.append(.Add(AddChange(parentId: 0, id: newFlattenedThingies[index].viewDetails.viewId, node: newFlattenedThingies[index])))
                } else {
                    // There was some other change
                    
                }
            }
        }
        
        let incrementalUpdate: RRWebIncrementalData = .mutation(RRWebMutationData(adds: [], removes: [], texts: [], attributes: []))
        
        let incrementalEvent = IncrementalEvent(timestamp: newFrame.date.timeIntervalSince1970, data: incrementalUpdate)
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
    
    private func flattenTree(rootThingy: SessionReplayViewThingy) -> [SessionReplayViewThingy] {
        var thingies: [SessionReplayViewThingy] = []
        var queue: [SessionReplayViewThingy] = [rootThingy]
        
        while let thingy = queue.popLast() {
            thingies.append(thingy)
            queue.append(contentsOf: thingy.subviews)
        }
        
        return thingies
    }
}
