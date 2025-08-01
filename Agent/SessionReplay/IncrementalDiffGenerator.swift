//
//  IncrementalDiffGenerator.swift
//  Agent_iOS
//
//  Created by Steve Malsam on 4/14/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation

// This generates a diff of the thingy tree based on Heckel's Algorithm

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

protocol Diffable {
    var id: Int { get }
    func hasChanged(from other: Self) -> Bool
}

enum Operation {
    case Add(AddChange)
    case Remove(RemoveChange)
    case Update(UpdateChange)
    
    struct RemoveChange {
        let parentId: Int
        let id: Int
    }

    struct UpdateChange {
        let oldElement: any SessionReplayViewThingy
        let newElement: any SessionReplayViewThingy
    }

    struct AddChange {
        let parentId: Int
        let id: Int?
        let node: any SessionReplayViewThingy
    }
}

func generateDiff(old:[any SessionReplayViewThingy], new:[any SessionReplayViewThingy]) -> [Operation] {
    var table: [Int: Symbol] = [:]
    
    // Go through the arrays according to Heckel's Algorithm.
    var newArrayEntries = [Entry]()
    var oldArrayEntries = [Entry]()
    
    // Pass One: Each element of the New array is gone through, and an entry in the table made for each
    for item in new {
        let entry = Symbol(inNew: true)
        table[item.viewDetails.viewId] = entry
        newArrayEntries.append(.symbol(entry))
    }
    
    // Pass Two: Each element of the Old array is gone through, and an entry in the table made for each
    for (index, item) in old.enumerated() {
        var entry: Symbol?
        if table[item.viewDetails.viewId] == nil {
            entry = Symbol(inNew: false, indexInOld: index)
            table[item.viewDetails.viewId] = entry
        } else {
            table[item.viewDetails.viewId]?.indexInOld = index
            entry = table[item.viewDetails.viewId]
        }
        
        if let entry = entry {
            oldArrayEntries.append(.symbol(entry))
        }
    }
    
    // Pass Three: Use the first observation of the algorithm's paper. If any entry occurs only onece
    // in the list, then it must be the same entry, although it could have been moved. Cross reference
    // the two
    for (index, item) in newArrayEntries.enumerated() {
        if case let .symbol(entry) = item {
            if entry.inNew, let indexInOld = entry.indexInOld {
                newArrayEntries[index] = .index(indexInOld)
                oldArrayEntries[indexInOld] = .index(index)
            }
        }
    }
    
    // Pass Four: Use the second observation of the algorithm's paper. If NewArray[i] points to OldArray[j],
    // and NewArray[i+1] and OldArray[j+1] contain identical symbol table entries, then OldArray[j+1] is
    // set to line i+1 and NewArray[i+1] is set to line j+1
    
    if newArrayEntries.count > 1 {
        for i in (0 ..< (newArrayEntries.count - 1)) {
            if case let .index(j) = newArrayEntries[i],
               j + 1 < oldArrayEntries.count,
               case let .symbol(newEntry) = newArrayEntries[i + 1],
               case let .symbol(oldEntry) = oldArrayEntries[j + 1],
               newEntry === oldEntry {
                newArrayEntries[i + 1] = .index(j + 1)
                oldArrayEntries[j + 1] = .index(i + 1)
            }
        }
    }
    
    // Pass Five: Same as pass 4, but in reverse!
    if newArrayEntries.count > 1 {
        for i in (1 ..< newArrayEntries.count).reversed() {
            if case let .index(j) = newArrayEntries[i],
               j - 1 >= 0,
               case let .symbol(newEntry) = newArrayEntries[i - 1],
               case let .symbol(oldEntry) = oldArrayEntries[j - 1],
               newEntry === oldEntry {
                newArrayEntries[i - 1] = .index(j - 1)
                oldArrayEntries[j - 1] = .index(i - 1)
            }
        }
    }
    
    // Lets get those changes
    var changes = [Operation]()
    
    // Removals
    var deleteOffsets = Array(repeating: 0, count: oldArrayEntries.count)
    var runningOffset = 0
    for(index, entry) in oldArrayEntries.enumerated() {
        deleteOffsets[index] = runningOffset
        if case .symbol = entry {
            changes.append(.Remove(Operation.RemoveChange(parentId: old[index].viewDetails.parentId ?? 0, id: old[index].viewDetails.viewId)))
            runningOffset += 1
        }
    }
    
    runningOffset = 0
    
    // Additions and Alterations
    for(index, entry) in newArrayEntries.enumerated() {
        switch entry {
        case .symbol:
            changes.append(.Add(Operation.AddChange(parentId: new[index].viewDetails.parentId ?? 0, id: new[index].viewDetails.viewId, node: new[index])))
            runningOffset += 1
            
        case .index(let indexInOld):
            let deleteOffset = deleteOffsets[indexInOld]
            let newElement = new[index]
            let oldElement = old[indexInOld]
            
            if (indexInOld - deleteOffset + runningOffset) != index {
                // If this doesn't get us back to where we currently are, then
                // the thing was moved
//                if oldElement.viewDetails.viewId == newElement.viewDetails.viewId { 
//                    changes.append(.Update(Operation.UpdateChange(oldElement: oldElement, newElement: newElement)))
//                } else {
                    changes.append(.Remove(Operation.RemoveChange(parentId: oldElement.viewDetails.parentId ?? 0, id: newElement.viewDetails.viewId)))
                    changes.append(.Add(Operation.AddChange(parentId: newElement.viewDetails.parentId ?? 0, id: newElement.viewDetails.viewId, node: newElement)))
//                }
            } else if type(of: newElement) == type(of: oldElement) {
                if newElement.hashValue != oldElement.hashValue {
                    changes.append(.Update(Operation.UpdateChange(oldElement: oldElement, newElement: newElement)))
                }
            }
        }
    }
    
    return changes
}
    
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
